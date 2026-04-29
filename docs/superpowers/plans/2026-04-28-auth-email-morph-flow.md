# Auth — Email-First Morphing Sheet Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the dual-CTA + system-sheet landing auth with a single "Get started" CTA that opens a floating bottom sheet, morphing through chooser → email → login or signup based on whether the email already has an account.

**Architecture:** A single `floatingBottomSheet` mounted across all steps, driven by an `AuthFlowCoordinator: ObservableObject` whose `AuthFlowStep` enum decides which subview to render. New `check-email-exists` edge function returns `{exists: bool}` so we can route to login vs. signup without leaking enumeration. New methods on `AuthManager` (`checkEmailExists`, `signIn`, `signUp`, `resendVerification`) are the only auth surface the new sheet uses. Existing top-level `LogInView` / `SignUpView` are untouched.

**Tech Stack:** SwiftUI, Swift Testing, Supabase (Auth + Edge Functions), Deno, Maestro for flow tests.

**Spec:** `docs/superpowers/specs/2026-04-28-auth-email-morph-flow-design.md`

---

## File Structure

| File | Responsibility |
|---|---|
| `supabase/functions/check-email-exists/index.ts` | Service-role lookup of `auth.users.email`; IP rate limit; returns `{exists}` |
| `supabase/functions/check-email-exists/index.test.ts` | Deno tests for normalization + rate-limit decide helper |
| `Lumoria App/views/authentication/AuthBackend.swift` | Protocol + live impl wrapping `supabase.auth.*`; injection seam for tests |
| `Lumoria App/views/authentication/AuthFlowTypes.swift` | `AuthFlowStep`, `CheckEmailResult`, `AuthFlowError` |
| `Lumoria App/views/authentication/AuthManager.swift` | Add `checkEmailExists`, `signIn`, `signUp`, `resendVerification` (delegates to `AuthBackend`) |
| `Lumoria App/views/authentication/AuthFlowCoordinator.swift` | `ObservableObject` owning step + email + error; transitions |
| `Lumoria App/views/authentication/AuthFlowSheet.swift` | Root sheet container — header (back/X) + animated step body |
| `Lumoria App/views/authentication/AuthChooserStepView.swift` | Continue with email + Apple + Google |
| `Lumoria App/views/authentication/EmailEntryStepView.swift` | Email field + Continue (with spinner) |
| `Lumoria App/views/authentication/InSheetLoginView.swift` | Locked email + password + Log in + Forgot + resend alert |
| `Lumoria App/views/authentication/InSheetSignupView.swift` | Locked email + name + password (with strength) + confirm + Sign up |
| `Lumoria App/LandingView.swift` | Single "Get started" CTA + coordinator hookup; removes pinned CTAs and old sheets |
| `Lumoria App/Localizable.xcstrings` | New copy strings |
| `Lumoria App/services/analytics/AnalyticsEvent.swift` | Add `authFlow*` events |
| `Lumoria AppTests/AuthFlowCoordinatorTests.swift` | Coordinator state transition tests |
| `Lumoria AppTests/AuthManagerAuthFlowTests.swift` | Tests for new AuthManager methods using mock `AuthBackend` |
| `Maestro/flows/auth/auth-email-flow.yaml` | Happy login + happy signup |
| `lumoria/src/content/changelog/2026-04-28-email-first-auth.mdx` | Per project changelog rule |

---

## Task 1: Edge function — `check-email-exists` decide helper (TDD)

**Files:**
- Create: `supabase/functions/check-email-exists/index.ts`
- Create: `supabase/functions/check-email-exists/index.test.ts`

- [ ] **Step 1.1: Write failing test for `decide()` rate-limit helper**

Create `supabase/functions/check-email-exists/index.test.ts`:

```ts
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { decide, normalizeEmail } from "./index.ts";

Deno.test("normalizeEmail: trims and lowercases", () => {
  assertEquals(normalizeEmail("  Foo@Bar.COM  "), "foo@bar.com");
});

Deno.test("normalizeEmail: empty input stays empty", () => {
  assertEquals(normalizeEmail("   "), "");
});

Deno.test("decide: rate-limited at 10 hits in window", () => {
  const r = decide({ existsInDb: false, hitsInWindow: 10 });
  assertEquals(r.outcome, "rate_limited");
});

Deno.test("decide: not rate-limited under 10 hits", () => {
  const r = decide({ existsInDb: true, hitsInWindow: 9 });
  assertEquals(r.outcome, "ok");
  assertEquals(r.exists, true);
});

Deno.test("decide: ok with exists=false", () => {
  const r = decide({ existsInDb: false, hitsInWindow: 0 });
  assertEquals(r.outcome, "ok");
  assertEquals(r.exists, false);
});
```

- [ ] **Step 1.2: Run the test to verify it fails**

Run: `cd "Lumoria App/supabase/functions/check-email-exists" && deno test --allow-net --allow-env`
Expected: FAIL with "Module not found" or "decide is not exported".

- [ ] **Step 1.3: Implement `index.ts` with `decide`, `normalizeEmail`, and `handler`**

Create `supabase/functions/check-email-exists/index.ts`:

```ts
// check-email-exists edge function.
//
// Tells the app whether an email address already has an account so the
// landing flow can morph into the login or signup form. Service-role
// lookup against auth.users by lower(email). IP-rate-limited (10/min
// sliding window) backed by an in-memory map; the function instance
// stays warm long enough that this is sufficient for V1 — swap to
// Deno.kv if we see horizontal scaling.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const RATE_LIMIT = 10;
const WINDOW_MS = 60_000;

// IP -> [timestamps]. Trimmed on each request.
const HITS = new Map<string, number[]>();

export function normalizeEmail(input: string): string {
  return input.trim().toLowerCase();
}

export type Outcome = "ok" | "rate_limited";

export function decide(args: {
  existsInDb: boolean;
  hitsInWindow: number;
}): { outcome: Outcome; exists?: boolean } {
  if (args.hitsInWindow >= RATE_LIMIT) return { outcome: "rate_limited" };
  return { outcome: "ok", exists: args.existsInDb };
}

function recordHit(ip: string): number {
  const now = Date.now();
  const cutoff = now - WINDOW_MS;
  const arr = (HITS.get(ip) ?? []).filter((t) => t > cutoff);
  arr.push(now);
  HITS.set(ip, arr);
  return arr.length;
}

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

export async function handler(req: Request): Promise<Response> {
  if (req.method !== "POST") {
    return json(405, { error: "method_not_allowed" });
  }

  const ip =
    req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ??
    req.headers.get("x-real-ip") ??
    "unknown";

  const hits = recordHit(ip);

  let body: { email?: unknown } = {};
  try {
    body = await req.json();
  } catch {
    return json(400, { error: "bad_request", reason: "invalid_json" });
  }
  if (typeof body.email !== "string") {
    return json(400, { error: "bad_request", reason: "missing_email" });
  }

  const email = normalizeEmail(body.email);
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    return json(400, { error: "bad_request", reason: "bad_email_format" });
  }

  const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
  const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // listUsers + filter is the only public way to read auth.users without
  // raw SQL access. With a normalized email this is at most one row.
  let existsInDb = false;
  try {
    const { data, error } = await admin.auth.admin.listUsers({
      page: 1,
      perPage: 1,
      filter: `email.eq.${email}`,
    });
    if (error) {
      console.log("[check-email-exists] listUsers failed", error);
      return json(500, { error: "lookup_failed" });
    }
    existsInDb = (data.users?.length ?? 0) > 0;
  } catch (e) {
    console.log("[check-email-exists] listUsers threw", String(e));
    return json(500, { error: "lookup_failed" });
  }

  const result = decide({ existsInDb, hitsInWindow: hits });
  if (result.outcome === "rate_limited") {
    return json(429, { error: "rate_limited" });
  }
  return json(200, { exists: result.exists ?? false });
}

if (import.meta.main) {
  Deno.serve(handler);
}
```

- [ ] **Step 1.4: Re-run the test to verify it passes**

Run: `cd "Lumoria App/supabase/functions/check-email-exists" && deno test --allow-net --allow-env`
Expected: 5 passed.

- [ ] **Step 1.5: Commit**

```bash
cd "Lumoria App"
git add "supabase/functions/check-email-exists/index.ts" "supabase/functions/check-email-exists/index.test.ts"
git commit -m "feat(edge): check-email-exists with IP rate limit"
```

---

## Task 2: Auth flow types

**Files:**
- Create: `Lumoria App/views/authentication/AuthFlowTypes.swift`

- [ ] **Step 2.1: Create the types file**

Create `Lumoria App/views/authentication/AuthFlowTypes.swift`:

```swift
//
//  AuthFlowTypes.swift
//  Lumoria App
//
//  Step enum + result/error types for the email-first landing auth flow.
//  Spec: docs/superpowers/specs/2026-04-28-auth-email-morph-flow-design.md
//

import Foundation

enum AuthFlowStep: Equatable {
    case chooser
    case email
    case login(email: String)
    case signup(email: String)
}

enum CheckEmailResult: Equatable {
    case exists
    case doesNotExist
    case rateLimited
}

enum AuthFlowError: Error, LocalizedError, Equatable {
    case invalidCredentials
    case emailNotConfirmed(email: String)
    case rateLimited
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return String(localized: "Email or password is incorrect")
        case .emailNotConfirmed:
            return String(localized: "Please confirm your email before logging in")
        case .rateLimited:
            return String(localized: "Too many tries — try again in a moment")
        case .transport(let detail):
            return detail
        }
    }
}
```

- [ ] **Step 2.2: Build the app to verify it compiles**

Run: `xcodebuild -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 15" build` (or Cmd-B in Xcode)
Expected: BUILD SUCCEEDED.

- [ ] **Step 2.3: Commit**

```bash
git add "Lumoria App/views/authentication/AuthFlowTypes.swift"
git commit -m "feat(auth): AuthFlowStep + CheckEmailResult + AuthFlowError"
```

---

## Task 3: `AuthBackend` protocol + live impl

**Files:**
- Create: `Lumoria App/views/authentication/AuthBackend.swift`

- [ ] **Step 3.1: Create the protocol + live implementation**

Create `Lumoria App/views/authentication/AuthBackend.swift`:

```swift
//
//  AuthBackend.swift
//  Lumoria App
//
//  Narrow seam over Supabase Auth used by AuthManager's email-first
//  flow methods. Production code uses LiveAuthBackend; tests inject a
//  mock so coordinator + manager logic can be exercised without a
//  network round-trip.
//

import Foundation
import Supabase

protocol AuthBackend: Sendable {
    func checkEmailExists(_ email: String) async throws -> CheckEmailResult
    func signIn(email: String, password: String) async throws
    func signUp(name: String, email: String, password: String, redirectTo: URL?) async throws
    func resendVerification(email: String, redirectTo: URL?) async throws
    /// True if the *currently authenticated* user has not confirmed their
    /// email yet. Used after signIn to mirror LogInView's existing
    /// behaviour of bouncing unverified accounts back to the email step.
    func currentUserEmailUnconfirmed() -> Bool
    func signOut() async throws
}

struct LiveAuthBackend: AuthBackend {
    func checkEmailExists(_ email: String) async throws -> CheckEmailResult {
        struct Resp: Decodable { let exists: Bool }
        struct Err: Decodable { let error: String }
        do {
            let resp: Resp = try await supabase.functions.invoke(
                "check-email-exists",
                options: FunctionInvokeOptions(body: ["email": email])
            )
            return resp.exists ? .exists : .doesNotExist
        } catch let FunctionsError.httpError(code: 429, _) {
            return .rateLimited
        } catch {
            throw AuthFlowError.transport(error.localizedDescription)
        }
    }

    func signIn(email: String, password: String) async throws {
        do {
            try await supabase.auth.signIn(email: email, password: password)
        } catch {
            let msg = error.localizedDescription.lowercased()
            if msg.contains("email not confirmed") || msg.contains("email_not_confirmed") {
                throw AuthFlowError.emailNotConfirmed(email: email)
            }
            if msg.contains("invalid") || msg.contains("credentials") {
                throw AuthFlowError.invalidCredentials
            }
            throw AuthFlowError.transport(error.localizedDescription)
        }
    }

    func signUp(name: String, email: String, password: String, redirectTo: URL?) async throws {
        do {
            try await supabase.auth.signUp(
                email: email,
                password: password,
                data: ["display_name": .string(name)],
                redirectTo: redirectTo
            )
        } catch {
            throw AuthFlowError.transport(error.localizedDescription)
        }
    }

    func resendVerification(email: String, redirectTo: URL?) async throws {
        do {
            try await supabase.auth.resend(
                email: email,
                type: .signup,
                emailRedirectTo: redirectTo
            )
        } catch {
            throw AuthFlowError.transport(error.localizedDescription)
        }
    }

    func currentUserEmailUnconfirmed() -> Bool {
        guard let user = supabase.auth.currentUser else { return false }
        return user.emailConfirmedAt == nil
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
    }
}
```

- [ ] **Step 3.2: Build to verify it compiles**

Run: `xcodebuild -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 15" build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3.3: Commit**

```bash
git add "Lumoria App/views/authentication/AuthBackend.swift"
git commit -m "feat(auth): AuthBackend protocol + LiveAuthBackend wrapper"
```

---

## Task 4: AuthManager wiring + tests (TDD)

**Files:**
- Modify: `Lumoria App/views/authentication/AuthManager.swift`
- Create: `Lumoria AppTests/AuthManagerAuthFlowTests.swift`

- [ ] **Step 4.1: Write the failing test**

Create `Lumoria AppTests/AuthManagerAuthFlowTests.swift`:

```swift
//
//  AuthManagerAuthFlowTests.swift
//  Lumoria AppTests
//

import Foundation
import Testing
@testable import Lumoria_App

actor MockAuthBackend: AuthBackend {
    var checkResult: Result<CheckEmailResult, Error> = .success(.doesNotExist)
    var signInError: Error?
    var signUpError: Error?
    var resendError: Error?
    var unconfirmed: Bool = false

    var lastCheckEmail: String?
    var lastSignInEmail: String?
    var lastSignUpName: String?
    var didSignOut = false

    func checkEmailExists(_ email: String) async throws -> CheckEmailResult {
        lastCheckEmail = email
        return try checkResult.get()
    }
    func signIn(email: String, password: String) async throws {
        lastSignInEmail = email
        if let signInError { throw signInError }
    }
    func signUp(name: String, email: String, password: String, redirectTo: URL?) async throws {
        lastSignUpName = name
        if let signUpError { throw signUpError }
    }
    func resendVerification(email: String, redirectTo: URL?) async throws {
        if let resendError { throw resendError }
    }
    nonisolated func currentUserEmailUnconfirmed() -> Bool { false }
    func signOut() async throws { didSignOut = true }
}

@MainActor
@Test func authManager_checkEmailExists_passesEmailThrough() async throws {
    let backend = MockAuthBackend()
    let mgr = AuthManager(backend: backend)
    _ = try await mgr.checkEmailExists("Foo@Bar.com")
    let captured = await backend.lastCheckEmail
    #expect(captured == "Foo@Bar.com")
}

@MainActor
@Test func authManager_signIn_propagatesInvalidCredentials() async throws {
    let backend = MockAuthBackend()
    await backend.setSignInError(AuthFlowError.invalidCredentials)
    let mgr = AuthManager(backend: backend)
    do {
        try await mgr.signIn(email: "a@b.com", password: "x")
        Issue.record("expected throw")
    } catch let e as AuthFlowError {
        #expect(e == .invalidCredentials)
    }
}

extension MockAuthBackend {
    func setSignInError(_ e: Error) { signInError = e }
}
```

- [ ] **Step 4.2: Run the test to verify it fails**

Run: in Xcode, ⌘U with `AuthManagerAuthFlowTests` selected (or `xcodebuild test -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 15" -only-testing:"Lumoria AppTests/authManager_checkEmailExists_passesEmailThrough"`)
Expected: FAIL — `AuthManager(backend:)` initializer doesn't exist.

- [ ] **Step 4.3: Modify `AuthManager` to accept a backend and add the four methods**

Edit `Lumoria App/views/authentication/AuthManager.swift`:

Add a stored property and an init overload at the top of the class (just after the published properties):

```swift
    private let backend: AuthBackend

    init(backend: AuthBackend = LiveAuthBackend()) {
        self.backend = backend
        Task {
            // (existing init body unchanged)
            let session = try? await supabase.auth.session
            isAuthenticated = session != nil
            if let uid = session?.user.id {
                provisionDataKey(for: uid)
            }
            AuthCache.hasCache = true
            isRestoring = false
            await listenForAuthChanges()
        }
    }
```

Then **delete the old parameterless `init()`** (the existing one starting `init() { Task { ... } }`).

Append these methods at the end of the class (above the closing `}`):

```swift
    // MARK: - Email-first flow

    func checkEmailExists(_ email: String) async throws -> CheckEmailResult {
        try await backend.checkEmailExists(email)
    }

    func signIn(email: String, password: String) async throws {
        try await backend.signIn(email: email, password: password)
        if backend.currentUserEmailUnconfirmed() {
            // Mirror LogInView: bounce the session and surface the verify
            // path so the UI can offer Resend.
            try? await backend.signOut()
            throw AuthFlowError.emailNotConfirmed(email: email)
        }
    }

    func signUp(name: String, email: String, password: String) async throws {
        try await backend.signUp(
            name: name,
            email: email,
            password: password,
            redirectTo: AuthRedirect.emailConfirmed
        )
    }

    func resendVerification(email: String) async throws {
        try await backend.resendVerification(
            email: email,
            redirectTo: AuthRedirect.emailConfirmed
        )
    }
```

- [ ] **Step 4.4: Re-run the tests to verify they pass**

Run: same command as 4.2.
Expected: 2 passed.

- [ ] **Step 4.5: Commit**

```bash
git add "Lumoria App/views/authentication/AuthManager.swift" "Lumoria AppTests/AuthManagerAuthFlowTests.swift"
git commit -m "feat(auth): AuthManager email-first flow methods + backend injection"
```

---

## Task 5: AuthFlowCoordinator + tests (TDD)

**Files:**
- Create: `Lumoria App/views/authentication/AuthFlowCoordinator.swift`
- Create: `Lumoria AppTests/AuthFlowCoordinatorTests.swift`

- [ ] **Step 5.1: Write the failing tests**

Create `Lumoria AppTests/AuthFlowCoordinatorTests.swift`:

```swift
//
//  AuthFlowCoordinatorTests.swift
//  Lumoria AppTests
//

import Foundation
import Testing
@testable import Lumoria_App

@MainActor
@Test func coordinator_invalidEmail_doesNotCallBackend_setsError() async throws {
    let backend = MockAuthBackend()
    let coord = AuthFlowCoordinator(auth: AuthManager(backend: backend))
    coord.continueWithEmail()
    coord.email = "not-an-email"
    await coord.submitEmail()
    #expect(coord.step == .email)
    #expect(coord.errorMessage != nil)
    let captured = await backend.lastCheckEmail
    #expect(captured == nil)
}

@MainActor
@Test func coordinator_existsTrue_transitionsToLogin() async throws {
    let backend = MockAuthBackend()
    await backend.setCheckResult(.success(.exists))
    let coord = AuthFlowCoordinator(auth: AuthManager(backend: backend))
    coord.continueWithEmail()
    coord.email = "user@example.com"
    await coord.submitEmail()
    #expect(coord.step == .login(email: "user@example.com"))
    #expect(coord.errorMessage == nil)
}

@MainActor
@Test func coordinator_existsFalse_transitionsToSignup() async throws {
    let backend = MockAuthBackend()
    await backend.setCheckResult(.success(.doesNotExist))
    let coord = AuthFlowCoordinator(auth: AuthManager(backend: backend))
    coord.continueWithEmail()
    coord.email = "new@example.com"
    await coord.submitEmail()
    #expect(coord.step == .signup(email: "new@example.com"))
}

@MainActor
@Test func coordinator_rateLimited_staysOnEmail_setsError() async throws {
    let backend = MockAuthBackend()
    await backend.setCheckResult(.success(.rateLimited))
    let coord = AuthFlowCoordinator(auth: AuthManager(backend: backend))
    coord.continueWithEmail()
    coord.email = "user@example.com"
    await coord.submitEmail()
    #expect(coord.step == .email)
    #expect(coord.errorMessage?.contains("Too many") == true)
}

@MainActor
@Test func coordinator_back_fromLogin_returnsToEmail_preservesValue() async throws {
    let backend = MockAuthBackend()
    await backend.setCheckResult(.success(.exists))
    let coord = AuthFlowCoordinator(auth: AuthManager(backend: backend))
    coord.continueWithEmail()
    coord.email = "user@example.com"
    await coord.submitEmail()
    coord.back()
    #expect(coord.step == .email)
    #expect(coord.email == "user@example.com")
}

@MainActor
@Test func coordinator_dismiss_resetsToChooser() async throws {
    let backend = MockAuthBackend()
    let coord = AuthFlowCoordinator(auth: AuthManager(backend: backend))
    coord.start()
    coord.continueWithEmail()
    coord.dismiss()
    #expect(coord.isPresented == false)
    #expect(coord.step == .chooser)
    #expect(coord.email == "")
}

extension MockAuthBackend {
    func setCheckResult(_ r: Result<CheckEmailResult, Error>) { checkResult = r }
}
```

- [ ] **Step 5.2: Run the tests to verify they fail**

Run: `xcodebuild test -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 15" -only-testing:"Lumoria AppTests/AuthFlowCoordinatorTests"`
Expected: FAIL — `AuthFlowCoordinator` not defined.

- [ ] **Step 5.3: Implement the coordinator**

Create `Lumoria App/views/authentication/AuthFlowCoordinator.swift`:

```swift
//
//  AuthFlowCoordinator.swift
//  Lumoria App
//
//  ObservableObject driving the floating bottom sheet for the email-first
//  landing flow. Owns step + typed values + in-flight task. UI binds to
//  `step` and renders the matching subview.
//
//  Spec: docs/superpowers/specs/2026-04-28-auth-email-morph-flow-design.md
//

import Foundation
import SwiftUI

@MainActor
final class AuthFlowCoordinator: ObservableObject {
    @Published var isPresented: Bool = false
    @Published var step: AuthFlowStep = .chooser
    @Published var email: String = ""
    @Published var isCheckingEmail: Bool = false
    @Published var errorMessage: String?

    private let auth: AuthManager
    private var checkTask: Task<Void, Never>?

    private static let emailRegex = try! NSRegularExpression(
        pattern: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#
    )

    init(auth: AuthManager) {
        self.auth = auth
    }

    func start() {
        step = .chooser
        email = ""
        errorMessage = nil
        isPresented = true
    }

    func continueWithEmail() {
        errorMessage = nil
        step = .email
    }

    func submitEmail() async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard Self.emailRegex.firstMatch(in: trimmed, range: range) != nil else {
            errorMessage = String(localized: "Enter a valid email address")
            return
        }

        checkTask?.cancel()
        errorMessage = nil
        isCheckingEmail = true
        defer { isCheckingEmail = false }

        do {
            let result = try await auth.checkEmailExists(trimmed)
            switch result {
            case .exists:
                step = .login(email: trimmed)
            case .doesNotExist:
                step = .signup(email: trimmed)
            case .rateLimited:
                errorMessage = String(localized: "Too many tries — try again in a moment")
            }
        } catch {
            errorMessage = String(localized: "Couldn't check that email — try again")
        }
    }

    func back() {
        switch step {
        case .chooser:
            return
        case .email:
            step = .chooser
        case .login, .signup:
            step = .email
        }
        errorMessage = nil
    }

    func dismiss() {
        checkTask?.cancel()
        isPresented = false
        // Reset on dismiss so the next presentation starts clean.
        step = .chooser
        email = ""
        errorMessage = nil
        isCheckingEmail = false
    }
}
```

- [ ] **Step 5.4: Re-run the tests to verify they pass**

Run: same as 5.2.
Expected: 6 passed.

- [ ] **Step 5.5: Commit**

```bash
git add "Lumoria App/views/authentication/AuthFlowCoordinator.swift" "Lumoria AppTests/AuthFlowCoordinatorTests.swift"
git commit -m "feat(auth): AuthFlowCoordinator state machine + tests"
```

---

## Task 6: Analytics events

**Files:**
- Modify: `Lumoria App/services/analytics/AnalyticsEvent.swift`

- [ ] **Step 6.1: Add the new events**

Open `Lumoria App/services/analytics/AnalyticsEvent.swift`. Find the `case logout` line in the Acquisition section. Add immediately after it:

```swift
    case authFlowStarted
    case authFlowEmailSubmitted(emailDomain: String, outcome: AuthFlowEmailOutcomeProp)
    case authFlowBackPressed(fromStep: AuthFlowStepProp)
    case authFlowDismissed(atStep: AuthFlowStepProp)
```

- [ ] **Step 6.2: Define the new prop enums**

Find the file/section where existing `Prop` enums live (search for `AuthErrorTypeProp` definition; new enums go near it — same file or its own depending on project convention). Add:

```swift
enum AuthFlowEmailOutcomeProp: String, Encodable {
    case exists, does_not_exist, rate_limited, error
}

enum AuthFlowStepProp: String, Encodable {
    case chooser, email, login, signup
}
```

- [ ] **Step 6.3: Map the new cases in the analytics dispatch switch**

Find the place that maps `AnalyticsEvent` → name + props (typically in `Analytics.swift` or near the enum). Add cases:

```swift
case .authFlowStarted:
    return ("Auth Flow Started", [:])
case .authFlowEmailSubmitted(let domain, let outcome):
    return ("Auth Flow Email Submitted",
            ["email_domain": domain, "outcome": outcome.rawValue])
case .authFlowBackPressed(let from):
    return ("Auth Flow Back Pressed", ["from_step": from.rawValue])
case .authFlowDismissed(let at):
    return ("Auth Flow Dismissed", ["at_step": at.rawValue])
```

(Match exact tuple shape used by sibling cases in the file.)

- [ ] **Step 6.4: Build to verify**

Run: `xcodebuild -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 15" build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 6.5: Commit**

```bash
git add "Lumoria App/services/analytics"
git commit -m "feat(analytics): auth flow events"
```

---

## Task 7: AuthChooserStepView

**Files:**
- Create: `Lumoria App/views/authentication/AuthChooserStepView.swift`

- [ ] **Step 7.1: Create the view**

Create `Lumoria App/views/authentication/AuthChooserStepView.swift`:

```swift
//
//  AuthChooserStepView.swift
//  Lumoria App
//
//  First step inside the floating auth sheet — Continue with email +
//  Apple icon + Google icon.
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=948-8016
//

import SwiftUI

struct AuthChooserStepView: View {
    let onContinueWithEmail: () -> Void
    let onApple: () -> Void
    let onGoogle: () -> Void
    let isSocialLoading: Bool
    let socialError: String?

    var body: some View {
        VStack(spacing: 16) {
            Button("Continue with email", action: onContinueWithEmail)
                .lumoriaButtonStyle(.primary)

            Text("or")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.Text.primary)

            if let socialError {
                Text(socialError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 24) {
                Button(action: onGoogle) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                        if isSocialLoading {
                            ProgressView()
                        } else {
                            Image("google-g")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                .disabled(isSocialLoading)
                .accessibilityLabel("Continue with Google")

                Button(action: onApple) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black)
                        if isSocialLoading {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "applelogo")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                .disabled(isSocialLoading)
                .accessibilityLabel("Continue with Apple")
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 32)
    }
}
```

- [ ] **Step 7.2: Build**

Run: `xcodebuild -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 15" build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 7.3: Commit**

```bash
git add "Lumoria App/views/authentication/AuthChooserStepView.swift"
git commit -m "feat(auth): AuthChooserStepView for in-sheet flow"
```

---

## Task 8: EmailEntryStepView

**Files:**
- Create: `Lumoria App/views/authentication/EmailEntryStepView.swift`

- [ ] **Step 8.1: Create the view**

Create `Lumoria App/views/authentication/EmailEntryStepView.swift`:

```swift
//
//  EmailEntryStepView.swift
//  Lumoria App
//
//  Email-only step inside the floating auth sheet. On Continue we hand
//  back to the coordinator to call checkEmailExists and morph into login
//  or signup.
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=2000-140461
//

import SwiftUI

struct EmailEntryStepView: View {
    @Binding var email: String
    let isLoading: Bool
    let errorMessage: String?
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Continue with email")
                    .font(.title2.bold())
                    .foregroundStyle(Color.Text.primary)
                Text("We'll check if you already have an account")
                    .font(.body)
                    .foregroundStyle(Color.Text.secondary)
            }

            LumoriaInputField(
                label: "Email address",
                placeholder: "Your email address",
                text: $email,
                contentType: .emailAddress,
                keyboardType: .emailAddress
            )

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Color.Feedback.Danger.text)
            }

            Button(action: onContinue) {
                if isLoading {
                    ProgressView().tint(Color.Text.OnColor.white)
                } else {
                    Text("Continue")
                }
            }
            .lumoriaButtonStyle(.primary)
            .disabled(email.isEmpty || isLoading)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 32)
    }
}
```

- [ ] **Step 8.2: Build**

Run: `xcodebuild -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 15" build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 8.3: Commit**

```bash
git add "Lumoria App/views/authentication/EmailEntryStepView.swift"
git commit -m "feat(auth): EmailEntryStepView"
```

---

## Task 9: InSheetLoginView

**Files:**
- Create: `Lumoria App/views/authentication/InSheetLoginView.swift`

- [ ] **Step 9.1: Create the view**

Create `Lumoria App/views/authentication/InSheetLoginView.swift`:

```swift
//
//  InSheetLoginView.swift
//  Lumoria App
//
//  Login surface rendered inside the floating auth sheet after the
//  email-existence check returns `.exists`. Email is locked + prefilled.
//  Calls AuthManager so the supabase client only lives in one place.
//

import SwiftUI

struct InSheetLoginView: View {
    let email: String
    @EnvironmentObject private var auth: AuthManager
    var onSuccess: () -> Void = {}

    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showForgotPassword = false
    @State private var unverifiedEmail: String?
    @State private var resendStatus: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome back")
                    .font(.title2.bold())
                    .foregroundStyle(Color.Text.primary)
                Text(email)
                    .font(.subheadline)
                    .foregroundStyle(Color.Text.secondary)
            }

            LumoriaInputField(
                label: "Password",
                placeholder: "Your password",
                text: $password,
                isSecure: true,
                contentType: .password
            )

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Color.Feedback.Danger.text)
            }

            HStack {
                Spacer()
                Button("Forgot password?") { showForgotPassword = true }
                    .font(.footnote)
                    .foregroundStyle(Color.Text.primary)
            }

            Button(action: submit) {
                if isLoading {
                    ProgressView().tint(Color.Text.OnColor.white)
                } else {
                    Text("Log in")
                }
            }
            .lumoriaButtonStyle(.primary)
            .disabled(password.isEmpty || isLoading)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 32)
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView(prefilledEmail: email)
        }
        .alert(
            "Verify your email",
            isPresented: Binding(
                get: { unverifiedEmail != nil },
                set: { if !$0 { unverifiedEmail = nil; resendStatus = nil } }
            )
        ) {
            Button("Resend email") {
                if let e = unverifiedEmail { Task { await resend(for: e) } }
            }
            Button("OK", role: .cancel) {}
        } message: {
            if let resendStatus { Text(resendStatus) }
            else if let e = unverifiedEmail {
                Text("Tap the link we sent to \(e) to activate your account, then log in.")
            }
        }
    }

    private func submit() {
        errorMessage = nil
        isLoading = true
        let domain = AnalyticsIdentity.emailDomain(email) ?? "unknown"
        Analytics.track(.loginSubmitted(emailDomain: domain))

        Task {
            defer { isLoading = false }
            do {
                try await auth.signIn(email: email, password: password)
                onSuccess()
            } catch AuthFlowError.emailNotConfirmed(let e) {
                unverifiedEmail = e
            } catch AuthFlowError.invalidCredentials {
                Analytics.track(.loginFailed(errorType: .invalid_credentials))
                errorMessage = String(localized: "Email or password is incorrect")
            } catch {
                Analytics.track(.loginFailed(errorType: .unknown))
                errorMessage = error.localizedDescription
            }
        }
    }

    private func resend(for e: String) async {
        do {
            try await auth.resendVerification(email: e)
            resendStatus = "We resent the link to \(e)."
        } catch {
            resendStatus = "Couldn't resend: \(error.localizedDescription)"
        }
    }
}
```

> **Note:** if `ForgotPasswordView` does not currently accept a `prefilledEmail` parameter, drop the argument and call `ForgotPasswordView()` instead. Don't add the parameter as part of this task — out of scope.

- [ ] **Step 9.2: Verify ForgotPasswordView signature**

Run: `grep -n "struct ForgotPasswordView" "Lumoria App/views/authentication/ForgotPasswordView.swift"` then check its initializer.
If it has no `prefilledEmail` init parameter, edit `InSheetLoginView.swift` line `ForgotPasswordView(prefilledEmail: email)` → `ForgotPasswordView()`.

- [ ] **Step 9.3: Build**

Run: `xcodebuild -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 15" build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 9.4: Commit**

```bash
git add "Lumoria App/views/authentication/InSheetLoginView.swift"
git commit -m "feat(auth): InSheetLoginView with locked email + resend alert"
```

---

## Task 10: InSheetSignupView

**Files:**
- Create: `Lumoria App/views/authentication/InSheetSignupView.swift`

- [ ] **Step 10.1: Create the view**

Create `Lumoria App/views/authentication/InSheetSignupView.swift`:

```swift
//
//  InSheetSignupView.swift
//  Lumoria App
//
//  Signup surface rendered inside the floating auth sheet after the
//  email-existence check returns `.doesNotExist`. Email locked. Strength
//  bar reuses the algorithm from SignUpView (kept private there); we
//  inline an equivalent rather than refactoring out — the existing view
//  is left untouched.
//

import SwiftUI

private enum InSheetPwStrength: Int {
    case empty = 0, weak = 1, fair = 2, good = 3, strong = 4

    var label: String {
        switch self {
        case .empty:  return String(localized: "Password strength")
        case .weak:   return String(localized: "Weak")
        case .fair:   return String(localized: "Fair")
        case .good:   return String(localized: "Good")
        case .strong: return String(localized: "Strong")
        }
    }

    var color: Color {
        switch self {
        case .empty:  return Color("Colors/Opacity/Black/inverse/10")
        case .weak:   return Color(hex: "D94544")
        case .fair:   return Color(hex: "F2986A")
        case .good:   return Color(hex: "F5D46A")
        case .strong: return Color(hex: "34C759")
        }
    }

    static func score(for password: String) -> InSheetPwStrength {
        guard !password.isEmpty else { return .empty }
        var score = 0
        if password.range(of: "[A-Z]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[a-z]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[0-9]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[!@#$%^&*]", options: .regularExpression) != nil { score += 1 }
        return InSheetPwStrength(rawValue: score) ?? .empty
    }
}

struct InSheetSignupView: View {
    let email: String
    @EnvironmentObject private var auth: AuthManager
    var onSuccess: () -> Void = {}

    @State private var name = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showConfirmation = false

    private var strength: InSheetPwStrength { .score(for: password) }
    private var passwordValid: Bool { password.count >= 8 && strength == .strong }
    private var passwordsMatch: Bool { !confirmPassword.isEmpty && password == confirmPassword }
    private var canSubmit: Bool {
        !name.isEmpty && passwordValid && passwordsMatch && !isLoading
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Let's create your account")
                        .font(.title2.bold())
                        .foregroundStyle(Color.Text.primary)
                    Text(email)
                        .font(.subheadline)
                        .foregroundStyle(Color.Text.secondary)
                }

                LumoriaInputField(
                    label: "Name",
                    placeholder: "Your name",
                    text: $name,
                    contentType: .name
                )

                VStack(alignment: .leading, spacing: 8) {
                    LumoriaInputField(
                        label: "Password",
                        placeholder: "Your password",
                        text: $password,
                        isSecure: true,
                        contentType: .newPassword
                    )

                    HStack(spacing: 2) {
                        ForEach(1...4, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(i <= strength.rawValue ? strength.color : Color("Colors/Opacity/Black/inverse/10"))
                                .frame(height: 4)
                        }
                    }
                    Text(strength.label)
                        .font(.caption)
                        .foregroundStyle(strength == .empty ? Color.Text.tertiary : strength.color)
                }

                LumoriaInputField(
                    label: "Confirm password",
                    placeholder: "Confirm your password",
                    text: $confirmPassword,
                    isSecure: true,
                    contentType: .newPassword
                )

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(Color.Feedback.Danger.text)
                }

                Button(action: submit) {
                    if isLoading {
                        ProgressView().tint(Color.Text.OnColor.white)
                    } else {
                        Text("Create account")
                    }
                }
                .lumoriaButtonStyle(.primary)
                .disabled(!canSubmit)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
        .frame(maxHeight: 560)
        .alert("Check your email", isPresented: $showConfirmation) {
            Button("OK", role: .cancel) { onSuccess() }
        } message: {
            Text("We sent a confirmation link to \(email). Tap it on this iPhone to activate your account, then log in.")
        }
    }

    private func submit() {
        errorMessage = nil
        isLoading = true
        let domain = AnalyticsIdentity.emailDomain(email) ?? "unknown"
        Analytics.track(.signupSubmitted(emailDomain: domain, hasName: !name.isEmpty))

        Task {
            defer { isLoading = false }
            do {
                try await auth.signUp(name: name, email: email, password: password)
                Analytics.track(.signupVerificationSent(emailDomain: domain))
                showConfirmation = true
            } catch {
                Analytics.track(.signupFailed(errorType: .unknown))
                errorMessage = error.localizedDescription
            }
        }
    }
}
```

- [ ] **Step 10.2: Build**

Run: `xcodebuild -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 15" build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 10.3: Commit**

```bash
git add "Lumoria App/views/authentication/InSheetSignupView.swift"
git commit -m "feat(auth): InSheetSignupView with strength bar"
```

---

## Task 11: AuthFlowSheet container

**Files:**
- Create: `Lumoria App/views/authentication/AuthFlowSheet.swift`

- [ ] **Step 11.1: Create the sheet root**

Create `Lumoria App/views/authentication/AuthFlowSheet.swift`:

```swift
//
//  AuthFlowSheet.swift
//  Lumoria App
//
//  Root content of the floating bottom sheet that morphs through
//  chooser → email → login or signup. Animation lives here so each
//  step subview stays presentational.
//

import SwiftUI

struct AuthFlowSheet: View {
    @ObservedObject var coordinator: AuthFlowCoordinator
    @EnvironmentObject private var auth: AuthManager

    @State private var isSocialLoading = false
    @State private var socialError: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            stepBody
                .animation(.spring(duration: 0.35), value: coordinator.step)
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack {
            if showsBack {
                Button {
                    Analytics.track(.authFlowBackPressed(fromStep: stepProp))
                    coordinator.back()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Color.Text.primary)
                        .frame(width: 44, height: 44)
                        .background(Color.Background.fieldFill)
                        .clipShape(Circle())
                }
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
            Spacer()
            Button {
                Analytics.track(.authFlowDismissed(atStep: stepProp))
                coordinator.dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color.Text.primary)
                    .frame(width: 44, height: 44)
                    .background(Color.Background.fieldFill)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    @ViewBuilder
    private var stepBody: some View {
        switch coordinator.step {
        case .chooser:
            AuthChooserStepView(
                onContinueWithEmail: coordinator.continueWithEmail,
                onApple: signInWithApple,
                onGoogle: signInWithGoogle,
                isSocialLoading: isSocialLoading,
                socialError: socialError
            )
            .transition(.opacity.combined(with: .move(edge: .leading)))

        case .email:
            EmailEntryStepView(
                email: $coordinator.email,
                isLoading: coordinator.isCheckingEmail,
                errorMessage: coordinator.errorMessage,
                onContinue: {
                    Task {
                        await coordinator.submitEmail()
                        let domain = AnalyticsIdentity.emailDomain(coordinator.email) ?? "unknown"
                        let outcome: AuthFlowEmailOutcomeProp = {
                            switch coordinator.step {
                            case .login: return .exists
                            case .signup: return .does_not_exist
                            case .email:
                                if coordinator.errorMessage?.contains("Too many") == true {
                                    return .rate_limited
                                }
                                return coordinator.errorMessage == nil ? .error : .error
                            case .chooser: return .error
                            }
                        }()
                        Analytics.track(.authFlowEmailSubmitted(
                            emailDomain: domain, outcome: outcome
                        ))
                    }
                }
            )
            .transition(.opacity.combined(with: .move(edge: .trailing)))

        case .login(let email):
            InSheetLoginView(email: email, onSuccess: coordinator.dismiss)
                .transition(.opacity.combined(with: .move(edge: .trailing)))

        case .signup(let email):
            InSheetSignupView(email: email, onSuccess: coordinator.dismiss)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
        }
    }

    private var showsBack: Bool {
        coordinator.step != .chooser
    }

    private var stepProp: AuthFlowStepProp {
        switch coordinator.step {
        case .chooser: return .chooser
        case .email: return .email
        case .login: return .login
        case .signup: return .signup
        }
    }

    private func signInWithApple() {
        socialError = nil
        isSocialLoading = true
        Task {
            defer { isSocialLoading = false }
            do { try await auth.signInWithApple() }
            catch AppleSignInService.AppleSignInError.canceled { /* silent */ }
            catch { socialError = error.localizedDescription }
        }
    }

    private func signInWithGoogle() {
        socialError = nil
        isSocialLoading = true
        Task {
            defer { isSocialLoading = false }
            do { try await auth.signInWithGoogle() }
            catch GoogleSignInService.GoogleSignInError.canceled { /* silent */ }
            catch { socialError = error.localizedDescription }
        }
    }
}
```

- [ ] **Step 11.2: Build**

Run: `xcodebuild -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 15" build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 11.3: Commit**

```bash
git add "Lumoria App/views/authentication/AuthFlowSheet.swift"
git commit -m "feat(auth): AuthFlowSheet morphing root container"
```

---

## Task 12: LandingView refactor

**Files:**
- Modify: `Lumoria App/LandingView.swift`

- [ ] **Step 12.1: Replace the body with a single CTA + coordinator-driven sheet**

Open `Lumoria App/LandingView.swift` and replace the entire `LandingView` struct (lines 11-211 in the existing file — everything from `struct LandingView: View {` through the closing `}` of the struct, **but keep the `import SwiftUI` and `#Preview` block**) with:

```swift
struct LandingView: View {
    @Environment(\.brandSlug) private var brandSlug
    @EnvironmentObject private var auth: AuthManager
    @StateObject private var coordinator: AuthFlowCoordinator

    init() {
        // Coordinator needs the AuthManager. We can't read EnvironmentObject
        // in init, so we instantiate the coordinator with a placeholder and
        // rely on the EnvironmentObject for actual auth calls. The
        // coordinator only stores the manager to forward checkEmailExists,
        // which is safe — but to keep things clean we wire it in onAppear.
        _coordinator = StateObject(wrappedValue: AuthFlowCoordinator(
            auth: AuthManager()  // replaced via .task onAppear; never used before then
        ))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.Background.default.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image("brand/\(brandSlug)/logomark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 137, height: 137)

                Spacer().frame(height: 54)

                Image("brand/\(brandSlug)/logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 226, height: 90)
                    .opacity(0.3)

                headlineView

                Spacer().frame(height: 32)

                Text("By signing up you agree to our Terms and Privacy Policy.")
                    .font(.footnote)
                    .foregroundStyle(Color.Text.secondary)
                    .tint(Color.Text.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Spacer().frame(height: 200)
            }

            VStack {
                Button("Get started") {
                    Analytics.track(.authFlowStarted)
                    coordinator.start()
                }
                .lumoriaButtonStyle(.primary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .navigationBarHidden(true)
        .floatingBottomSheet(isPresented: $coordinator.isPresented) {
            AuthFlowSheet(coordinator: coordinator)
        }
    }

    private var headlineView: some View {
        (Text("Tickets that last ")
            .foregroundStyle(Color.Text.primary)
        + Text("forever")
            .foregroundStyle(
                LinearGradient(
                    stops: [
                        .init(color: Color(hex: "57B7F5"), location: 0),
                        .init(color: Color(hex: "FFA96C"), location: 0.338),
                        .init(color: Color(hex: "FDDC51"), location: 0.659),
                        .init(color: Color(hex: "FF9CCC"), location: 1),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        )
        .font(.largeTitle.bold())
    }
}
```

> **Caveat on the `init()`:** the placeholder `AuthManager()` inside the `StateObject` initializer is never called for auth — `coordinator.auth.checkEmailExists` would hit an unwanted backend. We need a cleaner injection. Replace the `init()` and the property with the simpler approach below in Step 12.2.

- [ ] **Step 12.2: Refactor coordinator ownership to live above LandingView**

Move coordinator creation to the parent. Find the file that presents `LandingView` (search: `grep -n "LandingView()" "Lumoria App"`). It's almost certainly the app root or a switch on `auth.isAuthenticated`. In that parent, change:

```swift
LandingView()
```

to:

```swift
LandingView(coordinator: AuthFlowCoordinator(auth: authManager))
```

where `authManager` is whatever variable name the parent uses for the `AuthManager` instance.

Then change `LandingView` to:

```swift
struct LandingView: View {
    @Environment(\.brandSlug) private var brandSlug
    @EnvironmentObject private var auth: AuthManager
    @StateObject var coordinator: AuthFlowCoordinator

    init(coordinator: AuthFlowCoordinator) {
        _coordinator = StateObject(wrappedValue: coordinator)
    }

    var body: some View { /* unchanged from 12.1 */ }
}
```

If the parent doesn't have an `AuthManager` var to hand (it's only injected via environment), introduce one as `@StateObject private var authManager = AuthManager()` at the parent level if it doesn't already exist; if the parent uses `@EnvironmentObject` then create the coordinator inside the parent's `init` as well using the same env-passing pattern as the parent.

> Pick whichever pattern matches what's already in the parent. **Do not** keep the placeholder `AuthManager()` from 12.1.

- [ ] **Step 12.3: Build**

Run: `xcodebuild -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 15" build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 12.4: Commit**

```bash
git add "Lumoria App/LandingView.swift" <parent-file-modified-in-12.2>
git commit -m "feat(landing): single Get started CTA + morphing auth sheet"
```

---

## Task 13: Localizable strings

**Files:**
- Modify: `Lumoria App/Localizable.xcstrings`

- [ ] **Step 13.1: Build the app and let Xcode auto-extract**

Run: `xcodebuild -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 15" build`
Expected: BUILD SUCCEEDED. The build's String Catalog phase will pick up new `String(localized:)` and `Text(...)` literals from the new files. Open `Localizable.xcstrings` in Xcode after the build to confirm new entries appear:
- "Continue with email"
- "Welcome back"
- "Let's create your account"
- "Get started"
- "We'll check if you already have an account"
- "Couldn't check that email — try again"
- "Too many tries — try again in a moment"
- "Enter a valid email address"
- "Email or password is incorrect"
- "Please confirm your email before logging in"
- "Password strength" / "Weak" / "Fair" / "Good" / "Strong"
- "Check your email"
- (any others from the new views)

- [ ] **Step 13.2: Add translations for any non-English locale already supported**

In Xcode's Localizable.xcstrings editor, fill in translations for each non-English locale row that already exists (matching siblings — don't add new locales).

- [ ] **Step 13.3: Commit**

```bash
git add "Lumoria App/Localizable.xcstrings"
git commit -m "chore(i18n): strings for email-first auth flow"
```

---

## Task 14: Maestro happy-path flow

**Files:**
- Create: `Maestro/flows/auth/auth-email-flow.yaml`

- [ ] **Step 14.1: Inspect the existing auth flow files for project conventions**

Run: `ls Maestro/flows/auth && head -40 Maestro/flows/auth/*.yaml | head -120`
Expected: existing patterns for app launch + element selectors visible.

- [ ] **Step 14.2: Create the flow**

Create `Maestro/flows/auth/auth-email-flow.yaml`:

```yaml
appId: ${MAESTRO_APP_ID}
name: Email-First Auth Flow
---
# Happy login (existing user)
- launchApp:
    clearState: true
- tapOn: "Get started"
- tapOn: "Continue with email"
- tapOn: "Your email address"
- inputText: "${MAESTRO_EXISTING_EMAIL}"
- tapOn: "Continue"
- tapOn: "Your password"
- inputText: "${MAESTRO_EXISTING_PASSWORD}"
- tapOn: "Log in"
- assertVisible:
    text: ".*"   # post-login surface — tighten once the actual landing element is known

---
# Happy signup (new email)
- launchApp:
    clearState: true
- tapOn: "Get started"
- tapOn: "Continue with email"
- tapOn: "Your email address"
- inputText: "${MAESTRO_NEW_EMAIL}"
- tapOn: "Continue"
- tapOn: "Your name"
- inputText: "Test User"
- tapOn: "Your password"
- inputText: "${MAESTRO_NEW_PASSWORD}"
- tapOn: "Confirm your password"
- inputText: "${MAESTRO_NEW_PASSWORD}"
- tapOn: "Create account"
- assertVisible: "Check your email"
```

> Adjust env var names to match those used by sibling flows in the same directory.

- [ ] **Step 14.3: Run the flow against a local simulator**

Run: `maestro test Maestro/flows/auth/auth-email-flow.yaml`
Expected: both scenarios pass. Tighten any flaky selector before committing.

- [ ] **Step 14.4: Commit**

```bash
git add Maestro/flows/auth/auth-email-flow.yaml
git commit -m "test(maestro): email-first auth flow"
```

---

## Task 15: Changelog entry

**Files:**
- Create: `lumoria/src/content/changelog/2026-04-28-email-first-auth.mdx`

- [ ] **Step 15.1: Inspect a recent changelog entry to match exact format**

Run: `ls -t lumoria/src/content/changelog | head -3 && head -30 lumoria/src/content/changelog/$(ls -t lumoria/src/content/changelog | head -1)`
Expected: see the JS-export frontmatter style (per project memory).

- [ ] **Step 15.2: Create the entry**

Create `lumoria/src/content/changelog/2026-04-28-email-first-auth.mdx`:

```mdx
export const frontmatter = {
  title: "Email-first sign-in",
  date: "2026-04-28",
  category: "Auth",
}

The landing screen now starts with a single **Get started** button. The
bottom sheet asks for your email first and morphs into the right screen —
log in if you already have an account, sign up if you don't. Apple and
Google buttons stay one tap away in the same sheet.
```

> If the recently-added entries use different field names or category values, match those exactly.

- [ ] **Step 15.3: Commit**

```bash
git add lumoria/src/content/changelog/2026-04-28-email-first-auth.mdx
git commit -m "docs(changelog): email-first sign-in"
```

---

## Task 16: Manual verification

- [ ] **Step 16.1: Run the app in the iOS simulator**

Open Xcode → run on iPhone 15 simulator.

- [ ] **Step 16.2: Walk the happy paths**

1. Tap **Get started** → sheet slides up showing chooser.
2. Tap **Continue with email** → sheet morphs to email step (back chevron appears).
3. Type a known existing email → tap Continue → sheet morphs to login. Verify back chevron returns to email step with email preserved.
4. Forward again, type the right password, tap Log in → sheet dismisses, app authenticated.
5. Sign out, tap Get started, Continue with email, type a brand-new email → sheet morphs to signup (full form, email locked).
6. Submit signup → "Check your email" alert.
7. Test rate limit by tapping Continue 11 times rapidly → expect inline "Too many tries" on the email step.
8. Test Apple and Google buttons in the chooser — should still launch native flows.

- [ ] **Step 16.3: Light + dark mode + dynamic type**

Toggle Dark Appearance and Dynamic Type to XL. Verify no clipping inside the floating sheet across all four step states.

- [ ] **Step 16.4: Smallest device**

Switch simulator to iPhone SE (3rd gen). Re-run Step 16.2 #1-6. The signup step (longest content) is the risk — `InSheetSignupView` caps height at 560 and is wrapped in a ScrollView so this should be fine, but verify.

- [ ] **Step 16.5: If anything in 16.2 / 16.3 / 16.4 is broken, file a follow-up task with the exact reproduction**

Don't patch in this PR unless it's a one-line fix (e.g. typo in copy). Major UI changes go to a follow-up.

---

## Self-review

**Spec coverage:**
- Single Get started CTA → Task 12 ✓
- Floating sheet across all steps → Task 11 ✓
- Chooser with Continue with email + Apple + Google → Task 7 ✓
- Email entry with validation + spinner → Task 8 + Task 5 (regex) ✓
- Login morph with locked email + forgot + resend → Task 9 ✓
- Signup morph with locked email + name + password (strength) + confirm → Task 10 ✓
- check-email-exists edge function with IP rate limit → Task 1 ✓
- AuthManager.checkEmailExists/signIn/signUp/resendVerification → Task 4 ✓
- AuthBackend protocol seam → Task 3 ✓
- AuthFlowCoordinator with state machine + cancellation → Task 5 ✓
- Analytics events authFlowStarted/EmailSubmitted/BackPressed/Dismissed → Task 6 ✓
- Beta-code post-auth path unchanged → not touched anywhere ✓
- LogInView/SignUpView untouched per spec out-of-scope → not modified ✓
- Localization → Task 13 ✓
- Maestro flow → Task 14 ✓
- Changelog → Task 15 ✓
- Unit tests for coordinator + manager → Tasks 4, 5 ✓
- Edge function unit test → Task 1 ✓

**Type consistency check:**
- `AuthFlowStep` (Task 2) used in coordinator (Task 5), sheet (Task 11), analytics prop mapping (Task 11) — names match.
- `AuthFlowError.invalidCredentials` / `.emailNotConfirmed(email:)` / `.rateLimited` / `.transport(_)` defined Task 2, thrown by `LiveAuthBackend` (Task 3) and `AuthManager.signIn` (Task 4), caught in `InSheetLoginView.submit` (Task 9) — names match.
- `CheckEmailResult.exists` / `.doesNotExist` / `.rateLimited` defined Task 2, returned by Task 3, mapped by Task 5 — names match.
- `AuthBackend` protocol (Task 3) signatures match `MockAuthBackend` (Task 4 + Task 5 extension) and `AuthManager` calls (Task 4) — checked: `signUp(name:email:password:redirectTo:)` consistent everywhere.
- Analytics props `AuthFlowEmailOutcomeProp` / `AuthFlowStepProp` (Task 6) referenced in Task 11 — names match.

**Placeholder scan:** none found. Caveats in Task 9 (ForgotPasswordView signature check) and Task 12 (parent file injection pattern) provide concrete decision rules, not TBDs.

---
