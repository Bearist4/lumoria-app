# Auth — Email-First Morphing Sheet Flow

**Date:** 2026-04-28
**Status:** Design — pending implementation
**Related Figma:**
- Auth chooser bottom sheet: https://www.figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=948-8016
- "Continue with email" sub-state: https://www.figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=2000-140379
- Email-only entry modal: https://www.figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=2000-140461
- Sign-up surface (in-sheet target): https://www.figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=948-8013

## Problem

`LandingView` currently pins two CTAs (Log in / Sign up) plus an Apple/Google icon row at the bottom and presents `LogInView` / `SignUpView` via system `.sheet`. Updated design replaces that with a single "Get started" CTA that opens a floating bottom sheet, which morphs through:

1. **Chooser** — Continue with email + Apple icon + Google icon.
2. **Email entry** — single email field; on submit we look up whether an account exists.
3. **Login or Signup** — same sheet morphs into the matching auth form (email locked + prefilled).

Goal: one continuous, native-feeling auth flow with no flash between steps.

## Approach

Single `floatingBottomSheet` mounted across all steps. A small `ObservableObject` coordinator drives an `AuthFlowStep` enum; the sheet renders a focused subview per state. A new Edge Function checks email existence so we can route to login vs. signup without leaking enumeration via `signInWithOtp` or sending a spurious magic link.

## Architecture

### Step state

```swift
enum AuthFlowStep: Equatable {
    case chooser
    case email
    case login(email: String)
    case signup(email: String)
}
```

### Coordinator

`AuthFlowCoordinator: ObservableObject`, owned by `LandingView` as `@StateObject`.

```swift
@MainActor
final class AuthFlowCoordinator: ObservableObject {
    @Published var isPresented: Bool = false
    @Published var step: AuthFlowStep = .chooser
    @Published var email: String = ""
    @Published var isCheckingEmail: Bool = false
    @Published var errorMessage: String?

    private var checkTask: Task<Void, Never>?
    private let auth: AuthManager

    init(auth: AuthManager)
    func start()                    // isPresented = true; step = .chooser
    func continueWithEmail()        // step = .email; clears error
    func submitEmail()              // validates; calls auth.checkEmailExists; transitions
    func back()                     // pop step; preserves typed values
    func dismiss()                  // isPresented = false; resets state
}
```

`submitEmail` cancels any prior `checkTask` before launching a new one. On dismiss, the coordinator resets to `.chooser` so the next presentation starts clean.

### Sheet root + subviews

- `AuthFlowSheet` — root container. Header row (back chevron + X). Body switches on `coordinator.step` with a `.spring(duration: 0.35)` animation and `.transition(.opacity.combined(with: .move(edge: .trailing)))`.
- `AuthChooserStepView` — Continue with email (primary) + Apple icon + Google icon (existing assets).
- `EmailEntryStepView` — single `LumoriaInputField` (email) + Continue button (shows spinner while `isCheckingEmail`). Inline error under field.
- `InSheetLoginView` — locked email pill + password field + Log in button + Forgot password link. Reuses existing `signIn` logic now living on `AuthManager`.
- `InSheetSignupView` — locked email pill + name + password (with existing strength bar) + confirm password + Sign up button.

Existing top-level `LogInView` / `SignUpView` files are left in place untouched — they remain reachable as deep-link / fallback surfaces, but the landing flow no longer presents them.

### `AuthManager` additions

```swift
enum CheckEmailResult { case exists, doesNotExist, rateLimited }

enum AuthFlowError: Error, LocalizedError {
    case invalidCredentials
    case emailNotConfirmed(email: String)
    case rateLimited
    case transport(String)
}

func checkEmailExists(_ email: String) async throws -> CheckEmailResult
func signIn(email: String, password: String) async throws
func signUp(name: String, email: String, password: String) async throws
func resendVerification(email: String) async throws
```

`signIn` / `signUp` wrap `supabase.auth.signIn` / `signUp` and translate Supabase errors into `AuthFlowError` cases the UI can render. `signUp` passes `data: ["full_name": name]`. `resendVerification` wraps `supabase.auth.resend(type: .signup, email:)` so `InSheetLoginView` doesn't duplicate the inline implementation that currently lives in `LogInView`.

### Edge Function — `check-email-exists`

`supabase/functions/check-email-exists/index.ts`

- POST `{ email: string }` → `{ exists: boolean }`.
- Service-role lookup against `auth.users` by `lower(email)`.
- IP rate limit: 10 requests / minute (sliding window) backed by `Deno.kv`. On exceed → `429`.
- CORS locked to the app's published origin(s).
- Logs hashed email + IP for accounting; never logs plaintext email.
- Response time target: < 300ms p95.

## State transitions

| From | Trigger | To | Notes |
|---|---|---|---|
| `chooser` | Continue with email | `email` | clears error |
| `chooser` | Apple / Google tap | (auth runs; sheet stays until success) | existing flow |
| `email` | submit, valid format, `exists=true` | `login(email)` | spinner on Continue while checking |
| `email` | submit, valid format, `exists=false` | `signup(email)` | same spinner |
| `email` | submit, invalid format | stays `email` | inline format error, no network call |
| `email` | submit, 429 | stays `email` | "Too many tries — try again in a moment" |
| `email` | submit, transport error | stays `email` | "Couldn't check that email — try again" |
| `email` / `login` / `signup` | back chevron | previous step | preserves typed values |
| any | X tap | sheet dismissed | coordinator resets to `.chooser` |
| `login` | Log in success | sheet dismissed | `AuthRedirect` takes over |
| `signup` | Sign up success | sheet dismissed | confirm-email + beta-code flows unchanged |

## Validation + concurrency

- Client-side email regex: `^[^@\s]+@[^@\s]+\.[^@\s]+$`. Whitespace trimmed and lowercased before submit.
- `submitEmail` stores its `Task` in `checkTask`. A new submit, edit, or back action cancels the prior task.
- Coordinator deinit cancels in-flight work.

## Error UX

| Where | Failure | UI |
|---|---|---|
| Email step | empty / invalid format | inline red text under field, no network call |
| Email step | 429 rate-limited | inline "Too many tries — try again in a moment" |
| Email step | network / 500 | inline "Couldn't check that email — try again" |
| Login step | wrong password | inline under password "Email or password is incorrect" |
| Login step | email_not_confirmed | inline + "Resend confirmation" button (existing logic) |
| Signup step | weak password | strength bar (existing component) |
| Signup step | password mismatch | inline under confirm field |
| Signup step | email already in use | shouldn't happen (we just checked) — fall back to inline error + back affordance |
| Apple / Google | canceled | silent (existing) |
| Apple / Google | failure | inline error in chooser |

## Edge cases

- **Account exists by email but is Apple-linked only:** password sign-in fails → "Email or password is incorrect". Acceptable for V1; we deliberately do not surface a provider hint to avoid leaking which provider the account uses.
- **User edits email after morph and back-chevrons:** coordinator preserves the email value so `EmailEntryStepView` prefills.
- **User backgrounds the app mid-check:** the request is allowed to complete; the `Task` only cancels on explicit dismiss, back, or new submit. If the response arrives while backgrounded the result is applied on the next foreground; if the user has already navigated away the dismiss-side cancellation handles cleanup.
- **Race — user submits email twice:** new submit cancels prior `checkTask`.
- **Beta-only build:** new signups still hit `BetaCodeRedemptionView` post-auth (`AuthRedirect` unchanged).

## Out of scope

- Refactoring existing top-level `LogInView` / `SignUpView` to call `AuthManager.signIn` / `signUp`. Those files keep their inline `supabase.auth.*` calls; the new sheet subviews are the only consumers of the new `AuthManager` methods.
- Magic-link / passwordless sign-in.
- Provider-aware error messaging on the login step.
- Full-screen or alternative presentation styles for the auth flow.

## Files touched

| File | Change |
|---|---|
| `Lumoria App/LandingView.swift` | rip pinned CTAs + sheets; single "Get started" CTA + coordinator wiring |
| `Lumoria App/views/authentication/AuthFlowCoordinator.swift` | NEW |
| `Lumoria App/views/authentication/AuthFlowSheet.swift` | NEW (root container + transitions) |
| `Lumoria App/views/authentication/AuthChooserStepView.swift` | NEW |
| `Lumoria App/views/authentication/EmailEntryStepView.swift` | NEW |
| `Lumoria App/views/authentication/InSheetLoginView.swift` | NEW |
| `Lumoria App/views/authentication/InSheetSignupView.swift` | NEW |
| `Lumoria App/views/authentication/AuthManager.swift` | add `checkEmailExists`, `signIn`, `signUp`, `AuthFlowError`, `CheckEmailResult` |
| `supabase/functions/check-email-exists/index.ts` | NEW |
| `Lumoria App/Localizable.xcstrings` | new strings (button labels, errors) |
| `lumoria/src/content/changelog/<slug>.mdx` | new entry per project convention |

## Testing

- **Unit (Swift Testing) — `AuthFlowCoordinator`:**
  - `submitEmail` with invalid format sets error and does not call backend.
  - `submitEmail` with `.exists` transitions step to `.login(email)`.
  - `submitEmail` with `.doesNotExist` transitions step to `.signup(email)`.
  - `back()` from `.login` returns to `.email` and preserves email.
  - `submitEmail` with `.rateLimited` keeps step `.email` and sets error.
- **Unit — `AuthManager`:** mock backend via a small `AuthBackend` protocol so tests don't touch a live Supabase client.
- **Edge function:** Deno test for rate-limit sliding window + email normalization (case + whitespace).
- **Maestro:** new `Maestro/flows/auth/auth-email-flow.yaml` covering happy login and happy signup paths.
- **Manual:** verify sheet morph animation in iOS simulator across light/dark, dynamic type L+XL, and the smallest supported device.

## Telemetry

Reuse existing `Analytics` events (`loginSucceeded`, `sessionRestored`). Add:

- `auth_flow_started` (entrypoint = `landing_get_started`)
- `auth_flow_email_submitted` (outcome = `exists` | `does_not_exist` | `rate_limited` | `error`)
- `auth_flow_back_pressed` (from = `email` | `login` | `signup`)
- `auth_flow_dismissed` (at_step = ...)

These are additive; no PII (email is hashed via `AnalyticsIdentity.emailDomain`).

## Rollout

Single PR. No feature flag — replaces the landing flow wholesale. Risk is contained to unauthenticated sessions; no impact on signed-in users (they never see the landing surface). Beta-code post-auth path is untouched.
