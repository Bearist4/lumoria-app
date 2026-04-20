# Pre-TestFlight Security Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Audit Lumoria iOS app for security/data issues across auth, data-at-rest, and 3rd-party leaks before first TestFlight build. Fix Crit + High inline, defer Med + Low to backlog.

**Architecture:** Three sequential passes (Auth → Data → 3rd-party). Each pass: inventory → run checks → triage → fix Crit/High → record findings → commit. Findings docs are tables in `docs/security/`. One commit per pass for the audit work + fixes.

**Tech Stack:** Swift / SwiftUI, SwiftData, Supabase Swift SDK, Amplitude iOS SDK (+ Session Replay), CryptoKit, Keychain Services, PassKit (PKPass), iOS app groups, Messages extension.

**Spec:** `docs/superpowers/specs/2026-04-20-security-audit-design.md`

**Early findings (from design phase — verify and incorporate):**

- `SupabaseManager.swift:11-18` hardcodes Supabase URL + anon key. Anon key = public by design (RLS-protected), acceptable. Confirm no `service_role` key anywhere in bundle.
- `KeychainStore.swift:36` uses `kSecAttrAccessibleAfterFirstUnlock` (not `ThisDeviceOnly`). Combined with `kSecAttrSynchronizable: true` (line 29), the per-user data key rides iCloud Keychain. That is a deliberate design choice (key continuity across devices for encrypted ciphertext readability). Accept, but confirm no session tokens share this store.
- `Info.plist` is missing `ITSAppUsesNonExemptEncryption` (export compliance). App uses CryptoKit.
- `Info.plist` has only `NSPhotoLibraryAddUsageDescription`. If photo *read* or camera is used anywhere, purpose strings are missing.
- No app-level `PrivacyInfo.xcprivacy` — only the vendored Amplitude one exists. Required by Apple.
- `CFBundleURLSchemes = lumoria` custom scheme is declared. Deep-link handler must validate host/path before routing.
- Associated domains declared for `getlumoria.app` — universal link handler must reject other hosts.

---

## File Structure

**New files (definitely created):**

- `docs/security/2026-04-20-pass-1-auth.md` — findings table for auth pass
- `docs/security/2026-04-20-pass-2-data.md` — findings table for data pass
- `docs/security/2026-04-20-pass-3-third-party.md` — findings table for 3rd-party pass
- `docs/security/backlog.md` — all deferred Med + Low items
- `docs/security/audit-summary.md` — go / no-go + counts
- `Lumoria App/PrivacyInfo.xcprivacy` — app-level privacy manifest

**Files likely modified (conditional on findings):**

- `Lumoria App/Info.plist` — add `ITSAppUsesNonExemptEncryption`, any missing purpose strings, `NSUserTrackingUsageDescription` if session replay on
- `Lumoria App/SupabaseManager.swift` — comment / doc only if no issue; move key to xcconfig if not already
- `Lumoria App/views/authentication/AuthManager.swift` — sign-out cleanup, account delete
- `Lumoria App/services/analytics/AnalyticsEvent.swift`, `AmplitudeAnalyticsService.swift`, `AnalyticsIdentity.swift` — strip PII
- `Lumoria App/LumoriaLinks.swift` — deep-link validation
- `Lumoria App/services/import/PKPassImporter.swift` — zip-slip / bounds

**Out of scope:** Performance, UI copy, App Store metadata.

---

## Conventions for every task

- **Record finding:** Append a row to the pass's findings doc with `| id | severity | file:line | description | fix-or-defer | commit-sha |`. Use `-` for unknown sha until the pass commit lands; then backfill in the consolidation task.
- **Defer threshold:** Only Crit + High get fixed in this plan. Med + Low get a one-liner appended to `docs/security/backlog.md` and skipped.
- **No fix needed:** If a check passes cleanly, still record a row with severity `ok` so the audit trail is complete.
- **Use Grep tool, not bash grep.**
- **Commit discipline:** One commit per pass at the end, not per task. Tasks build up findings and inline fixes; pass-end commits them together with the findings doc.

---

## Pass 1 — Auth

### Task 1.1: Scaffold pass 1 findings doc

**Files:**
- Create: `docs/security/2026-04-20-pass-1-auth.md`

- [ ] **Step 1: Write the findings doc scaffold**

```markdown
# Pass 1 — Auth findings (2026-04-20)

Spec: `docs/superpowers/specs/2026-04-20-security-audit-design.md`

| id | severity | location | description | action | commit |
|----|----------|----------|-------------|--------|--------|
```

- [ ] **Step 2: Verify file created**

Run: `ls "docs/security/2026-04-20-pass-1-auth.md"`
Expected: path exists.

### Task 1.2: Supabase session storage

**Surface:** `SupabaseManager.swift`, Supabase Swift SDK default `AuthLocalStorage`.

- [ ] **Step 1: Check SDK storage config**

Read `Lumoria App/SupabaseManager.swift`. Confirm `SupabaseClientOptions.AuthOptions` does not pass a custom `localStorage` (meaning SDK default is used). Then verify the SDK's default on iOS is Keychain-backed by checking `Package.resolved` version and the SDK source for `KeychainLocalStorage` default.

Run: `Grep` pattern `KeychainLocalStorage|AuthLocalStorage|UserDefaults` across `Lumoria App/**/*.swift` to confirm no UserDefaults-backed session override.

Pass: SDK default Keychain, no override to UserDefaults.

- [ ] **Step 2: Record finding**

If pass: append row `| 1.2 | ok | SupabaseManager.swift:11 | Supabase session uses SDK default Keychain storage | none | - |`.

If fail (custom UserDefaults storage): severity `crit`, fix inline by removing override. Show fix:

```swift
// remove any custom .localStorage(...) entry so SDK uses Keychain default
```

### Task 1.3: Service_role key not shipped

- [ ] **Step 1: Grep for service_role key marker**

Use `Grep` pattern `service_role|sb_secret|SUPABASE_SERVICE` across repo root (exclude `build/`, `.claude/worktrees/`, `node_modules`).

Expected: zero matches in app source. Only allowed location: `supabase/` functions (server-side).

- [ ] **Step 2: Grep for high-entropy JWTs in Swift**

Use `Grep` pattern `eyJhbGciOi[A-Za-z0-9_-]{40,}` in `Lumoria App/**/*.swift`.

Expected: exactly one match (the anon key in `SupabaseManager.swift:13`). More than one → investigate each.

- [ ] **Step 3: Record**

Pass: `| 1.3 | ok | repo-wide | No service_role key in bundle; exactly one JWT (anon) in SupabaseManager | none | - |`.

Fail: `crit`, remove immediately and rotate the leaked key in Supabase dashboard.

### Task 1.4: Credential / token logging

- [ ] **Step 1: Grep for logging of sensitive fields**

Use `Grep` multiline, pattern `(print|os_log|NSLog|logger\.\w+)\s*\([^)]*(token|password|session|accessToken|refreshToken|otp|secret)` across `Lumoria App/**/*.swift` and `LumoriaStickers/**/*.swift` and `LumoriaPKPassImport/**/*.swift`.

- [ ] **Step 2: Triage each match**

For each match: if the log only prints a boolean/status (`"session refreshed"`), severity `ok`. If it prints the value itself or a user-identifiable substring, severity `high`.

- [ ] **Step 3: Fix inline for any `high`**

Replace with redacted log. Example fix pattern:

```swift
// before:
print("session=\(session.accessToken)")

// after:
#if DEBUG
print("session refreshed (len=\(session.accessToken.count))")
#else
// production: no-op
#endif
```

- [ ] **Step 4: Record each**

Append one row per finding.

### Task 1.5: Sign-out completeness

**Surface:** `Lumoria App/views/authentication/AuthManager.swift`.

- [ ] **Step 1: Read the sign-out path**

Read `AuthManager.swift` start to end. Find the sign-out function.

- [ ] **Step 2: Confirm it clears everything**

Required side effects on sign-out:

1. `supabase.auth.signOut()`
2. Any SwiftData rows scoped to the previous user (encrypted ticket payloads the next user shouldn't see) → purged OR re-gated behind user id check
3. Amplitude: `Amplitude.instance.reset()` (clears user id + device id linkage)
4. Push token: unregister by calling `UIApplication.shared.unregisterForRemoteNotifications()` OR delete the token from Supabase `device_tokens` table (whichever your backend uses)
5. Keychain: per-user data encryption key is retained intentionally (iCloud Keychain-backed, re-login restores access). Do NOT delete unless the user also deletes their account.

- [ ] **Step 3: Record + fix**

Each missing side effect = `high` finding. Add the missing call. Example pattern for Amplitude reset:

```swift
// in AuthManager sign-out:
AmplitudeAnalyticsService.shared.reset()
```

Commit the code change as part of the pass-end commit; record the row with `action = fix inline`.

### Task 1.6: Account deletion path

**Surface:** `Lumoria App/views/settings/`.

- [ ] **Step 1: Grep for in-app delete**

Use `Grep` pattern `delete.*account|deleteAccount|deleteUser` in `Lumoria App/views/settings/**/*.swift`.

- [ ] **Step 2: Confirm flow exists + works**

Required: a Settings row that calls a delete endpoint (Supabase edge function or direct auth admin call), signs out, and clears local data.

If present with server-side delete: `ok`.
If present but only signs out locally: `high` — does NOT satisfy Apple 5.1.1(v).
If absent: `high` — blocks App Store review.

- [ ] **Step 3: Fix if missing**

If missing: create Settings row wired to an edge function that deletes the user row and auth user. Minimal version:

```swift
// Settings list item
Button("Delete account", role: .destructive) {
    Task {
        try await supabase.functions.invoke("delete-account", options: .init())
        try? await supabase.auth.signOut()
    }
}
```

And add a stub note to the finding that a Supabase edge function `delete-account` is required server-side. If the function doesn't exist in `supabase/functions/`, record a parallel `high` finding: "Backend delete-account function missing."

### Task 1.7: Password reset redirect + OAuth PKCE

**Surface:** `ForgotPasswordView.swift`, `AuthRedirect.swift`, `LumoriaLinks.swift`.

- [ ] **Step 1: Read redirect handling**

Read `AuthRedirect.swift`. Confirm the reset deep link is parsed and only accepts hosts in the associated-domain allowlist (`getlumoria.app`, `www.getlumoria.app`) or the custom scheme `lumoria://`.

- [ ] **Step 2: Confirm PKCE**

Grep for `flowType` / `PKCE` in `SupabaseManager.swift` + `AuthManager.swift`. Supabase Swift SDK defaults to PKCE for auth flows in recent versions. Confirm `Package.resolved` has a recent Supabase Swift SDK.

- [ ] **Step 3: Record**

Open-redirect found → `crit`. Fix by adding host allowlist before dispatching:

```swift
private let allowedHosts: Set<String> = ["getlumoria.app", "www.getlumoria.app"]

func handle(url: URL) -> Bool {
    if url.scheme == "lumoria" { return route(url) }
    guard let host = url.host, allowedHosts.contains(host) else { return false }
    return route(url)
}
```

### Task 1.8: Email enumeration on signup

**Surface:** `SignUpView.swift`.

- [ ] **Step 1: Read error-message rendering**

Find where signup errors are shown. Look for any branch that displays "email already exists" or equivalent.

- [ ] **Step 2: Triage**

Supabase by default returns a generic error for duplicate email on sign-up (`AuthError.userAlreadyExists` mapping). If the app unwraps the error and surfaces it verbatim, user enumeration is possible → `med` (defer to backlog; not a release blocker but log it).

- [ ] **Step 3: Record**

If present: `med`, defer. Add to backlog: `- Sign-up flow leaks email-exists via error copy — use generic "check your email to confirm" copy regardless of existence.`

### Task 1.9: RLS + auth-related advisors

- [ ] **Step 1: Call Supabase MCP advisors**

Use `mcp__supabase__get_advisors` with `type: "security"` against the Lumoria project.

(If tool schema isn't loaded, run `ToolSearch` with `query: "select:mcp__supabase__get_advisors,mcp__supabase__list_projects"` first, then call.)

- [ ] **Step 2: Triage each advisor warning**

For each advisor finding related to RLS (missing / unrestricted) on user-scoped tables: `crit`. Enable RLS + add user-scoped policy.

- [ ] **Step 3: Record each**

One row per advisor finding. Fix RLS inline via `mcp__supabase__apply_migration` only if user explicitly approves touching the database; otherwise record as `crit – pending user approval for migration`.

### Task 1.10: Commit pass 1

- [ ] **Step 1: Backfill commit sha column**

Once the commit lands, re-run sha into `docs/security/2026-04-20-pass-1-auth.md` rows that say `-`.

Do this in two steps: (a) create commit with `-` placeholders, (b) amend the findings doc with real sha and commit separately as `docs(security): backfill pass 1 shas`. Use amend-free path — just a second commit.

- [ ] **Step 2: Commit**

```bash
git add "docs/security/2026-04-20-pass-1-auth.md" \
        "Lumoria App/views/authentication" \
        "Lumoria App/views/settings" \
        "Lumoria App/LumoriaLinks.swift"
# add any other modified files from this pass
git commit -m "$(cat <<'EOF'
chore(security): pass 1 auth audit + fixes

See docs/security/2026-04-20-pass-1-auth.md for findings + severities.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: commit succeeds, pre-commit hooks pass.

- [ ] **Step 3: Backfill shas**

Read the commit sha, find-and-replace `-` in the findings doc with the short sha for rows whose fix landed in that commit. Commit:

```bash
git add "docs/security/2026-04-20-pass-1-auth.md"
git commit -m "docs(security): backfill pass 1 commit shas"
```

---

## Pass 2 — Data at rest

### Task 2.1: Scaffold pass 2 findings doc

**Files:**
- Create: `docs/security/2026-04-20-pass-2-data.md`

- [ ] **Step 1: Write scaffold** (same format as Pass 1)

```markdown
# Pass 2 — Data-at-rest findings (2026-04-20)

Spec: `docs/superpowers/specs/2026-04-20-security-audit-design.md`

| id | severity | location | description | action | commit |
|----|----------|----------|-------------|--------|--------|
```

### Task 2.2: SwiftData store file protection

**Surface:** `Lumoria_AppApp.swift`, wherever `ModelContainer` is constructed.

- [ ] **Step 1: Find ModelContainer init**

Use `Grep` pattern `ModelContainer|modelContainer\(|ModelConfiguration` in `Lumoria App/**/*.swift`.

- [ ] **Step 2: Check configuration**

Read each match. Confirm: a `ModelConfiguration` is used that either (a) lives in the app group container, (b) uses explicit `url:` with a `.completeUntilFirstUserAuthentication` / `.complete` protection class, or (c) uses the default app-sandbox store (which on iOS is `.completeUntilFirstUserAuthentication` by default — acceptable).

SwiftData's default on iOS inherits the bundle's data protection class, which is `.completeUntilFirstUserAuthentication` unless the project overrides it. That's acceptable for a ticket-stub app; `.complete` would break background refresh if any exists.

- [ ] **Step 3: Record**

Default (acceptable): `ok`. If a custom URL is used without explicit protection class and lives in Documents/Library: `high`. Fix by setting file attributes after creation:

```swift
try FileManager.default.setAttributes(
    [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
    ofItemAtPath: storeURL.path
)
```

### Task 2.3: App group container file protection

**Surface:** Shared container under `group.bearista.Lumoria-App`.

- [ ] **Step 1: Grep for app group writes**

Use `Grep` pattern `containerURL.*group\.|securityApplicationGroupIdentifier` in `Lumoria App/**/*.swift`, `LumoriaStickers/**/*.swift`, `LumoriaPKPassImport/**/*.swift`.

- [ ] **Step 2: For each write, confirm protection**

If the code does `data.write(to: url)` without `.completeFileProtection` option: `high`. Fix:

```swift
try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
```

- [ ] **Step 3: Record each**

### Task 2.4: Keychain accessibility + sync flag audit

**Surface:** `KeychainStore.swift` already read — lines 29, 36.

- [ ] **Step 1: Confirm scope**

`KeychainStore` holds only the per-user AES-GCM data key. Confirm no other component writes session tokens / passwords using the same `service = "com.lumoria.datakey"` or uses this store for anything else.

Use `Grep` pattern `KeychainStore\.(save|read|delete)` across repo.

Every call site must be encryption-key-related. Anything else = `high`.

- [ ] **Step 2: Document the design choice**

The `kSecAttrSynchronizable: true` + `kSecAttrAccessibleAfterFirstUnlock` combo is required for the "same user sees same ciphertext across devices" model. This is correct *for encryption keys* because Supabase-auth'd user on a new device must be able to decrypt ciphertext written from old device.

Record as `ok` with description: "Per-user AES-GCM data key synced via iCloud Keychain; accessibility = afterFirstUnlock (required for sync). Confirm scope: encryption keys only."

- [ ] **Step 3: Encryption service review**

Review `EncryptionService.swift`: AES-GCM-256, random 256-bit key via `SymmetricKey(size: .bits256)`, no hardcoded IV (GCM generates its own nonce per seal), `combined` output carries nonce+tag.

Record: `ok`.

### Task 2.5: PKPass parsing — zip-slip + bounds

**Surface:** `Lumoria App/services/import/PKPassImporter.swift`.

- [ ] **Step 1: Read the importer**

Focus areas:
- Is ZIP extraction used? If yes, confirm extracted paths are resolved against the intended base and rejected if they escape it.
- Are `images/*.png` loaded through `UIImage(data:)` with size bounds? An adversarial image at 50k × 50k could OOM the app.
- Is `pass.json` parsed with `JSONDecoder` (safe) or `JSONSerialization` + force casts (fragile)?
- Are `webServiceURL` / `authenticationToken` from `pass.json` ever executed, opened, or sent as Bearer tokens? Presenting but never hitting = fine.

- [ ] **Step 2: For each risk, fix or record**

Zip-slip pattern fix:

```swift
let base = destinationDir.standardizedFileURL.path
let target = destinationDir.appendingPathComponent(entry.name).standardizedFileURL.path
guard target.hasPrefix(base + "/") else {
    throw PKPassImportError.invalidPath
}
```

Image bounds fix:

```swift
let maxBytes = 5 * 1024 * 1024
guard data.count <= maxBytes else { throw PKPassImportError.imageTooLarge }
```

Severity: zip-slip = `crit`. Unbounded image load = `high`. Server-side `webServiceURL` actioned without user intent = `crit`.

- [ ] **Step 3: Record**

### Task 2.6: Photo / file import lifecycle

**Surface:** Anywhere `startAccessingSecurityScopedResource` is called, plus `PhotosPicker` usage.

- [ ] **Step 1: Grep pairs**

Use `Grep` pattern `startAccessingSecurityScopedResource` and then `stopAccessingSecurityScopedResource`. Count matches — they must be equal, and every `start` must be in a `defer { stop… }` or balanced-path function.

- [ ] **Step 2: Record**

Unbalanced = `med` (file descriptor leak, not a security hole). Defer to backlog.

### Task 2.7: Logs — ticket/PII content in release builds

**Surface:** Whole app.

- [ ] **Step 1: Grep for print of ticket fields**

Use `Grep` pattern `print\([^)]*(ticket|pass|seat|venue|barcode|email|name)` in `Lumoria App/**/*.swift`.

Also `Grep` for `os_log` / `Logger` with `.info`/`.debug` that include user-entered content.

- [ ] **Step 2: Triage**

Any log of encrypted payload ciphertext = `ok` (ciphertext is not PII).
Any log of plaintext ticket content in release (not gated by `#if DEBUG`) = `high`.
Any log of email / user id in release = `high`.

- [ ] **Step 3: Fix inline**

Wrap in `#if DEBUG` or remove:

```swift
#if DEBUG
print("ticket parsed: \(ticket.displayName)")
#endif
```

Record each fix.

### Task 2.8: Pasteboard + screenshot exposure

- [ ] **Step 1: Grep for pasteboard**

Use `Grep` pattern `UIPasteboard`.

For each match: confirm `items` are set with `expirationDate` + `localOnly: true` if the payload is sensitive.

Severity: unset expiry on ticket barcode / seat / email copy → `med`. Defer.

- [ ] **Step 2: Screenshot cover**

Check `Lumoria_AppApp.swift` for `.onChange(of: scenePhase)` that blurs / covers ticket lists when backgrounded. If absent → `low`. Defer.

### Task 2.9: Commit pass 2

- [ ] **Step 1: Commit**

```bash
git add "docs/security/2026-04-20-pass-2-data.md" \
        "Lumoria App/services/import/PKPassImporter.swift"
# plus other modified files
git commit -m "$(cat <<'EOF'
chore(security): pass 2 data-at-rest audit + fixes

See docs/security/2026-04-20-pass-2-data.md for findings + severities.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 2: Backfill shas + commit docs**

Same pattern as Pass 1 Task 1.10 Step 3.

---

## Pass 3 — 3rd-party / leak

### Task 3.1: Scaffold pass 3 findings doc

**Files:**
- Create: `docs/security/2026-04-20-pass-3-third-party.md`

- [ ] **Step 1: Write scaffold** (same format).

### Task 3.2: Amplitude event PII audit

**Surface:** `services/analytics/AnalyticsEvent.swift`, `AnalyticsProperty.swift`, `AmplitudeAnalyticsService.swift`, all call sites.

- [ ] **Step 1: Enumerate events**

Read `AnalyticsEvent.swift` fully. List every event case + its properties.

- [ ] **Step 2: Grep call sites for injected user text**

For each event that accepts a property carrying user-entered text, check call sites. Use `Grep` for the event name across the app.

- [ ] **Step 3: Flag any event whose properties contain:**

- raw email
- ticket `displayName` / user-entered venue / seat / barcode payload
- photo asset identifiers
- full URL of user-shared image (can leak via path)

Each flagged property = `crit`.

- [ ] **Step 4: Fix inline**

Pattern: hash or redact:

```swift
// before
AnalyticsEvent.ticketImported(name: ticket.displayName, venue: ticket.venue)

// after
AnalyticsEvent.ticketImported(
    category: ticket.category.rawValue,   // enum, low-cardinality
    hasCustomName: !ticket.displayName.isEmpty
)
```

Never hash PII expecting it to be non-PII — hashed email is still PII under GDPR. Remove entirely.

- [ ] **Step 5: Record each**

### Task 3.3: Amplitude identity + reset hygiene

**Surface:** `AnalyticsIdentity.swift`.

- [ ] **Step 1: Read identity derivation**

Confirm Amplitude `userId` is either (a) the Supabase user id (UUID — acceptable, it's already a random opaque id) or (b) a stable salted hash of it. Email as userId = `crit`.

- [ ] **Step 2: Confirm reset on sign-out**

Cross-check with Pass 1 Task 1.5: sign-out must call `amplitude.reset()`.

- [ ] **Step 3: Record**

### Task 3.4: Amplitude session replay consent + masking

**Surface:** `AmplitudeAnalyticsService.swift`, Info.plist.

- [ ] **Step 1: Find session replay enablement**

Grep for `sessionReplay|SessionReplayPlugin|autoCapture`.

- [ ] **Step 2: Confirm masking**

If session replay is on: confirm `maskLevel = .conservative` or full text/image masking. Default is `.medium` which leaks input fields. `.conservative` = `ok`; default or weaker = `crit` (records user-entered ticket names, sign-up fields).

- [ ] **Step 3: Confirm consent plumbing + ATT string**

Session replay recording = tracking under ATT rules. Required:

a) `NSUserTrackingUsageDescription` in `Info.plist`.
b) `ATTrackingManager.requestTrackingAuthorization` prompted before any replay events emit.
c) If denied → session replay disabled.

Missing any of a/b/c = `crit`.

- [ ] **Step 4: Fix inline**

Info.plist addition:

```xml
<key>NSUserTrackingUsageDescription</key>
<string>Helps us improve Lumoria by understanding how tickets are created and shared. Your data is masked and never sold.</string>
```

ATT gate (at first launch after onboarding, not on cold start):

```swift
import AppTrackingTransparency

func requestTrackingIfNeeded() async {
    guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
    let status = await ATTrackingManager.requestTrackingAuthorization()
    if status != .authorized {
        AmplitudeAnalyticsService.shared.disableSessionReplay()
    }
}
```

- [ ] **Step 5: Record**

### Task 3.5: Info.plist purpose strings

**Surface:** `Info.plist`, all three (`Info.plist`, `LumoriaStickers/Info.plist`, `LumoriaPKPassImport/Info.plist`).

- [ ] **Step 1: Enumerate permissions used**

For each of: camera, photos (read), photos (write), contacts, location, microphone, notifications, Face ID, tracking — grep the codebase to see if it's used.

Example: `Grep` pattern `AVCaptureDevice|UIImagePickerController.*camera` → camera use.
`Grep` pattern `PHPickerViewController|PhotosPicker` → photo read use.
`Grep` pattern `CLLocationManager` → location.
`Grep` pattern `LAContext` → Face ID.
`Grep` pattern `ATTrackingManager` → tracking.

- [ ] **Step 2: Cross-check Info.plist**

Currently only `NSPhotoLibraryAddUsageDescription` is present. Every used permission must have its matching `NSXxxUsageDescription` string — missing = `high` (app crashes on permission prompt OR App Store reject).

- [ ] **Step 3: Fix inline**

Add missing keys. Keep copy user-facing and honest:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Lumoria reads photos you pick to attach to your ticket stubs.</string>

<key>NSCameraUsageDescription</key>
<string>Lumoria uses the camera to scan boarding passes you want to import.</string>

<key>NSFaceIDUsageDescription</key>
<string>Lumoria uses Face ID to protect private tickets.</string>
```

Only add strings for permissions actually used.

- [ ] **Step 4: Record**

### Task 3.6: PrivacyInfo.xcprivacy (app-level)

**Surface:** create `Lumoria App/PrivacyInfo.xcprivacy`.

- [ ] **Step 1: Enumerate required-reason APIs used**

Check:
- `UserDefaults` usage → reason `CA92.1` (app functionality)
- File timestamp APIs (`.modificationDate`, `creationDate` on file attrs) → reason `C617.1`
- System boot time (`kern.boottime`) → reason `35F9.1`
- Disk space (`NSFileSystemFreeSize`) → reason `E174.1`
- Active keyboards → reason `3EC4.1`

Grep each. Use `UserDefaults` alone is near-universal → include the reason declaration.

- [ ] **Step 2: Enumerate tracked data**

Tracking = Amplitude events tied to advertising identifier. If ATT is NOT authorized, no tracking. But the manifest must declare what the SDK *can* collect.

Typical Amplitude categories:
- `NSPrivacyCollectedDataTypeProductInteraction` — linked YES, used for analytics; tracking follows ATT.
- `NSPrivacyCollectedDataTypeDeviceID` — linked YES (via anonymous device id), used for analytics.
- Session replay adds: `NSPrivacyCollectedDataTypeOtherUsageData` or `NSPrivacyCollectedDataTypeCrashData` etc.

Check Amplitude's own bundled `PrivacyInfo.xcprivacy` in `build/Release-iphoneos/AmplitudeSessionReplay.framework/PrivacyInfo.xcprivacy` for the categories they declare at the SDK level; mirror at the app level for data *you* send through them.

- [ ] **Step 3: Write PrivacyInfo.xcprivacy**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypeEmailAddress</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <true/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypeProductInteraction</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <true/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAnalytics</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypeDeviceID</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <true/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAnalytics</string>
            </array>
        </dict>
    </array>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>C617.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

Flip `NSPrivacyTracking` to `true` and add `NSPrivacyTrackingDomains` (`api.amplitude.com`, `api2.amplitude.com`, `api.eu.amplitude.com` as applicable) if Amplitude session replay with ATT-authorized tracking is enabled. If session replay is off, keep `false`.

Adjust the tracked-data list based on actual grep findings from Task 3.5 and 3.2.

- [ ] **Step 4: Register in Xcode project**

Must be added to the app target's Copy Bundle Resources. Since we don't have Xcode available, the file creation alone is not enough; the engineer running this plan must add it via Xcode UI: `File → Add Files to "Lumoria App" → PrivacyInfo.xcprivacy → target = Lumoria App`.

Record the step as a `high` finding with `action = file created, requires Xcode membership add`.

- [ ] **Step 5: Record**

### Task 3.7: Export compliance flag

**Surface:** `Info.plist`.

- [ ] **Step 1: Add key**

Edit `Info.plist` to include:

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

Lumoria's use of CryptoKit for user content encryption qualifies under the "encryption limited to user authentication / data storage" exemption, so `false` is correct and avoids the annual self-classification. Confirm this legal reading matches Apple's current guidance before submission; if unsure, set `true` and file the annual self-classification report (more paperwork, more conservative).

- [ ] **Step 2: Record**

`high` finding, fixed inline.

### Task 3.8: ATS — no arbitrary loads

**Surface:** `Info.plist`.

- [ ] **Step 1: Grep Info.plist**

Use `Grep` pattern `NSAllowsArbitraryLoads|NSAppTransportSecurity` in `Info.plist` and all three.

- [ ] **Step 2: Record**

Default (absent) = ATS strict = `ok`. Present + `true` = `high`, must justify + scope.

### Task 3.9: Universal link + custom scheme handler

**Surface:** `LumoriaLinks.swift`, scene-delegate-equivalent URL handler.

- [ ] **Step 1: Read handler**

Confirm: (a) only the registered custom scheme `lumoria` and allowlisted hosts from the associated-domains entitlement are routed, (b) unexpected paths are ignored, (c) no action is auto-executed without user confirm (e.g., "add ticket from URL" should preview not auto-save).

- [ ] **Step 2: Record**

Open routes / auto-execution = `high`. Fix with allowlist (see Task 1.7 fix pattern).

### Task 3.10: xcconfig hygiene (analytics key)

**Surface:** `Amplitude.xcconfig`, `Amplitude.sample.xcconfig`, `.gitignore`.

- [ ] **Step 1: Check both files**

Read both xcconfigs. Expected: `Amplitude.sample.xcconfig` carries a placeholder (e.g. `AMPLITUDE_API_KEY = YOUR_KEY_HERE`). `Amplitude.xcconfig` carries the real key.

- [ ] **Step 2: Check gitignore**

Use `Grep` pattern `Amplitude\.xcconfig` in `.gitignore`. Expected: `Amplitude.xcconfig` listed, `Amplitude.sample.xcconfig` not.

- [ ] **Step 3: Check git history**

```bash
git log --all --source -- "Amplitude.xcconfig" | head -20
```

If any commit adds the real file with a real key: `crit` — rotate the key in Amplitude dashboard + purge from history with `git filter-repo`.

- [ ] **Step 4: Record**

### Task 3.11: Sharing export — EXIF / metadata

**Surface:** `Lumoria App/views/tickets/new/social/renders/StoryRenderView.swift`.

- [ ] **Step 1: Read render pipeline**

Confirm the exported `UIImage` data goes through `pngData()` or JPEG encoding without preserving original EXIF. `UIImage.pngData()` strips EXIF by default → `ok`. If the code uses `CGImageDestinationCopyImageSource` or similar to preserve metadata → `med` (possible fingerprinting, defer unless it also embeds user id / session).

- [ ] **Step 2: Record**

### Task 3.12: Push payload content

**Surface:** `Lumoria App/services/PushNotificationService.swift`, Supabase edge function sending pushes (if any).

- [ ] **Step 1: Read push-handling code**

Client-side: the app rendering `alert.title` / `alert.body` as-is is fine.

- [ ] **Step 2: Check server-side push composer**

In `supabase/functions/`, look for a function that composes APNs payloads. Pattern-match for any send that includes user-entered text (ticket name, email) in `alert.body`. If so → `med` defer (payload is delivered over TLS to APNs but appears on lock screen).

- [ ] **Step 3: Record**

### Task 3.13: Messages extension boundary

**Surface:** `LumoriaStickers/MessagesViewController.swift`, `LumoriaStickers/Info.plist`, shared `StickerManifest.swift`.

- [ ] **Step 1: Check what the appex reads**

Grep for app-group container reads from the appex target. If it reads user SwiftData ticket data → `high`. Stickers should only read the static sticker manifest (curated assets), not per-user ticket payloads.

- [ ] **Step 2: Record**

### Task 3.14: 3rd-party SDK versions

**Surface:** `Package.resolved` (Swift Package Manager).

- [ ] **Step 1: Read Package.resolved**

Find via `Glob` for `**/Package.resolved`.

- [ ] **Step 2: Check versions**

For Supabase Swift SDK + Amplitude iOS + Amplitude Session Replay: note pinned versions.

- [ ] **Step 3: Check advisories**

Use `WebSearch` for `"supabase-swift" CVE` and `"amplitude-ios" security advisory` (scope latest 12 months). Known advisory on pinned version → `high` and bump.

Skip this if no network access; record as `med` "manual SDK advisory check pending."

- [ ] **Step 4: Record**

### Task 3.15: Commit pass 3

- [ ] **Step 1: Commit**

```bash
git add "docs/security/2026-04-20-pass-3-third-party.md" \
        "Lumoria App/Info.plist" \
        "Lumoria App/PrivacyInfo.xcprivacy" \
        "Lumoria App/services/analytics"
# plus any other modified files
git commit -m "$(cat <<'EOF'
chore(security): pass 3 third-party audit + fixes

See docs/security/2026-04-20-pass-3-third-party.md for findings + severities.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 2: Backfill shas** (same pattern as Pass 1).

---

## Consolidation

### Task 4.1: Write backlog + summary

**Files:**
- Create: `docs/security/backlog.md`
- Create: `docs/security/audit-summary.md`

- [ ] **Step 1: Aggregate deferred items**

Collect every Med + Low finding from the three pass docs. Each becomes a one-line entry:

```markdown
# Security backlog — deferred items

Medium priority:
- [ ] Pass 2 §2.6 — Unbalanced security-scoped-resource accesses in <file>:<line>. Leak risk, not exploit.
- [ ] Pass 2 §2.8 — Pasteboard ticket-copy missing expiry / localOnly.
- [ ] ...

Low priority:
- [ ] Pass 2 §2.8 — No screenshot blur on backgrounding.
- [ ] ...
```

- [ ] **Step 2: Write audit summary**

```markdown
# Security audit summary — 2026-04-20

Spec: `docs/superpowers/specs/2026-04-20-security-audit-design.md`

## Counts

| Pass | Crit | High | Med | Low | OK |
|------|------|------|-----|-----|----|
| 1 Auth          | X | X | X | X | X |
| 2 Data at rest  | X | X | X | X | X |
| 3 Third-party   | X | X | X | X | X |

## Remaining risks

- <any unfixed Crit/High that required user approval or out-of-band action>

## TestFlight readiness

GO / NO-GO: <call>

Justification: <one paragraph>
```

- [ ] **Step 3: Commit**

```bash
git add "docs/security/backlog.md" "docs/security/audit-summary.md"
git commit -m "docs(security): audit summary + deferred backlog"
```

### Task 4.2: Run per-pass test plan

Verification (no new code):

- [ ] **Auth:** sign out → relaunch → no residual session visible. Delete account → re-sign-up with same email succeeds (if account-delete was in scope this pass).
- [ ] **Data:** force-quit mid-PKPass import → no corrupt state on relaunch. Lock device → confirm app cannot read ticket payloads from app-group container (manual test: start a fresh app instance while locked immediately after boot → read attempts fail until first unlock if `.completeUntilFirstUserAuthentication` is correctly set).
- [ ] **3rd-party:** proxy a device/simulator through Proxyman. Exercise sign-in, create ticket, import PKPass, share story. Capture every outbound request. Confirm no PII in bodies or query strings. Run again with ATT denied → confirm Amplitude session replay silent.
- [ ] **Privacy manifest:** Archive build in Xcode. Organizer should not warn about missing privacy manifest entries for required-reason APIs.

Record any test-plan failures as new Crit findings in the relevant pass's doc and loop back.

### Task 4.3: Final readiness call

- [ ] **Step 1: Confirm acceptance criteria**

- All three pass commits landed.
- `audit-summary.md` lists zero outstanding Crit or High.
- `backlog.md` covers all Med + Low.
- Archive build has no privacy manifest warnings.
- Go / no-go call written in summary.

- [ ] **Step 2: If GO**

Report to user: ready to submit to TestFlight. Include summary table.

- [ ] **Step 3: If NO-GO**

Report outstanding blockers. Do not submit.

---

## Notes for the engineer running this

- Each "find and fix" task is read-heavy. Use the `Grep` tool and `Read` tool, not bash `grep`/`cat`.
- Commit once per pass, not once per task, to keep history legible.
- If you hit a Crit finding that requires a database migration, **pause and surface to user** — do not run `mcp__supabase__apply_migration` without explicit approval on each migration.
- If a check result is ambiguous (e.g., "is this session replay default masking or custom?"), record with `severity = unknown` and request reviewer input rather than guessing.
- Do not broaden scope. Stick to security/data. Performance and UX polish live in separate plans.
