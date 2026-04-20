# Pre-TestFlight Security & Data Audit — Design

Date: 2026-04-20
Status: Design approved, pending user spec review

## Goal

Security / data audit of Lumoria iOS app before first TestFlight submission. Out of scope: performance audit, App Store review items unrelated to security/privacy.

## Threat model

Equal weight across:

- **A. Account + auth** — Supabase session tokens, password reset, OAuth.
- **B. Ticket data at rest** — SwiftData entries, PKPass files, imported photos. Contain names, seat, dates, location.
- **C. Leaks to 3rd parties** — Amplitude events + session replay, logs, crash reports, push payloads, sharing exports.

## Approach

Area-by-area with inline fixes (not parallel, not read-only).

Three sequential passes, one per area. Per pass:

1. **Inventory** — list attack surface (files / entry points).
2. **Run checks** — area-specific checklist (§ Pass 1–3).
3. **Triage** — Crit / High / Med / Low.
4. **Fix inline** — Crit + High only, same pass, block pass-commit until fixed.
5. **Defer** — Med + Low to `docs/security/backlog.md`.
6. **Commit** — one commit per pass: `chore(security): <area> audit + fixes`.

Order: **Auth → Data-at-rest → 3rd-party**. Auth issues can invalidate data protections; fix session layer before trusting what sits behind it.

## Severity rubric

| Severity | Definition | Handling |
|---|---|---|
| **Crit** | Remote unauth access, secret leak in bundle, PII to 3rd party, data loss. | Fix inline. Block pass commit. |
| **High** | Local attacker w/ device access, missing encryption on sensitive field, review-blocking gap (no PrivacyInfo.xcprivacy, no account delete). | Fix inline. |
| **Med** | Defense-in-depth (screenshot cover, pasteboard expiry, backup exclusion). | Defer to backlog. |
| **Low** | Hardening nice-to-have. | Defer. |

## Pass 1 — Auth

**Surface**

`Lumoria App/views/authentication/` (`AuthManager.swift`, `AuthView.swift`, `LogInView.swift`, `SignUpView.swift`, `ForgotPasswordView.swift`, `AuthRedirect.swift`), `SupabaseManager.swift`, `Crypto/KeychainStore.swift`.

**Checks**

- Session storage — Supabase tokens in Keychain (not UserDefaults); `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`; no iCloud sync flag.
- Password reset redirect — deep link verified against allowlist; no open redirect.
- OAuth flow — PKCE enabled; `state` param checked; callback URL scheme not hijackable.
- Sign-out — clears Keychain + SwiftData user-scoped rows + Amplitude user id + push token.
- Biometric gate (if present) — `LAContext` with `biometryCurrentSet` (invalidate on enrollment change).
- Account deletion — App Store 5.1.1(v) requires in-app deletion path.
- Credential logging — grep `token` / `password` / `session` in `print` / `os_log` at any level.
- Rate limit / lockout — confirm Supabase project auth rate limits enabled (server-side, via advisor).
- Supabase keys — public `anon` key OK in bundle; confirm `service_role` NOT shipped.
- RLS — enabled on every user-scoped table (Supabase MCP `get_advisors`).
- Email enumeration — signup error does not reveal "email exists".

**Fix-inline triggers**

Plaintext token in UserDefaults; service_role key in bundle; missing in-app account delete; RLS off on a user-scoped table; open redirect in reset flow.

## Pass 2 — Data at rest

**Surface**

`Lumoria App/Crypto/EncryptionService.swift`, `Crypto/KeychainStore.swift`, SwiftData models (`Item.swift`, tickets + collections stores), `services/import/PKPassImporter.swift`, app group container (app ↔ `LumoriaStickers` ↔ `LumoriaPKPassImport`), Photos / file importers.

**Checks**

- SwiftData store file protection — `.complete` or `.completeUnlessOpen` (not `.none`).
- App group container — same file protection; entitlement scoped to minimum needed.
- `EncryptionService` — HKDF / PBKDF2 key derivation (not raw passphrase); AES-GCM not CBC; unique nonces; key in Keychain with `ThisDeviceOnly`; no hardcoded IV.
- Keychain access group — scoped for app + extensions sharing; no wildcard.
- PKPass parsing — reject zip-slip paths; bound image size; no JS exec from `webServiceURL`; sanitize `passTypeIdentifier` before display; validate `manifest.json` signature or at least structure.
- Photo / file import — security-scoped URLs with `startAccessing…` + matching `stop…`; cap file size; validate UTType.
- iCloud / CloudKit (if any) — container scope + encryption expectations documented.
- Backup exclusion — sensitive caches marked `isExcludedFromBackup` where appropriate.
- Pasteboard — `UIPasteboard` items for sensitive fields set expiry + `localOnly: true`.
- Screenshots / task switcher — ticket list blurred / covered when backgrounded (flag if absent).
- Logs — no ticket content, seat, barcode payload, email in `print` / `os_log`, especially release.
- NSFileProtection on imported PKPass + user photos.

**Fix-inline triggers**

`.none` data protection; hardcoded key / IV; AES-CBC without MAC; PKPass parser accepts path traversal; secrets in release logs.

## Pass 3 — 3rd-party / leak

**Surface**

`services/analytics/AmplitudeAnalyticsService.swift`, `AnalyticsEvent.swift`, `AnalyticsProperty.swift`, `AnalyticsIdentity.swift`, `services/PushNotificationService.swift`, `views/tickets/new/social/renders/StoryRenderView.swift`, `LumoriaLinks.swift`, `LumoriaStickers/MessagesViewController.swift`, `Info.plist` (app + stickers + PKPassImport), entitlements, `Amplitude.xcconfig` / `Amplitude.sample.xcconfig`.

**Checks**

- Amplitude PII — enumerate every event: no email, user-entered ticket names, seat, barcode, venue address, photo URLs. Identity = stable hashed id, not email.
- Amplitude session replay — masks text + images (default is NOT enough); opt-in for minors; disable in DEBUG or behind consent toggle.
- Consent / ATT — if any SDK tracks, `NSUserTrackingUsageDescription` present and ATT prompted. Session replay likely triggers this.
- Info.plist usage strings — every permission used has purpose string: camera, photos, contacts, notifications, location, Face ID, tracking.
- PrivacyInfo.xcprivacy (app-level) — currently missing (only vendored Amplitude one exists). Required by Apple. Declare tracked data + required-reason APIs (`UserDefaults`, `fileTimestamp`, `systemBootTime`, `diskSpace`, `activeKeyboards`).
- Export compliance — `ITSAppUsesNonExemptEncryption` declared in Info.plist. CryptoKit use still requires the flag (usually exempt = YES but must be set).
- ATS — `NSAllowsArbitraryLoads` not true; any `NSExceptionDomains` scoped and justified.
- `Amplitude.xcconfig` hygiene — confirm real keys not checked in (vs `.sample` template); grep history for leaked secrets.
- URL scheme / universal link hijack — custom schemes validated; universal links use Associated Domains with `applinks:`.
- Deep link handlers — reject unexpected hosts / paths; no auto-exec of actions without user confirm.
- Messages extension boundary — what data does the appex read from app group; same protection class enforced.
- Push payload — no PII in alert body (use `loc-key` / opaque ids); silent `content-available` pushes don't leak.
- Crash reporting — TestFlight sends reports to Apple; confirm no PII in `NSError.userInfo`, assertion messages, or symbol names.
- Sharing renders — `StoryRenderView` exports strip metadata (user id, session) from image EXIF.
- 3rd-party dep audit — `Package.resolved` versions current; no known advisories on Amplitude or Supabase Swift SDK pinned versions.

**Fix-inline triggers**

PII in analytics events; missing PrivacyInfo.xcprivacy; missing export compliance flag; missing ATT string with session replay on; service_role key in bundle; universal link open redirect; real analytics keys committed to git.

## Output artifacts

Per pass:

- `docs/security/2026-04-20-pass-<N>-<area>.md` — findings table: `id | severity | file:line | description | fix-or-defer | commit-sha`.
- Commit: `chore(security): pass <N> <area> audit — K fixes, M deferred`.

Aggregate at end:

- `docs/security/backlog.md` — all Med + Low deferred, one-liner each.
- `docs/security/audit-summary.md` — counts per severity per pass, remaining risks, TestFlight readiness call.

## Tooling

- Grep patterns: `print(`, `os_log`, `NSLog`, `UserDefaults.*(token|session|password)`, `http://`, `service_role`, hardcoded high-entropy strings.
- Supabase MCP `get_advisors` — RLS + security lints.
- Xcode build log — entitlement warnings, missing-purpose-string warnings.
- Privacy manifest validator (Xcode Organizer) — pre-archive sanity check.

## Per-pass test plan

- **Auth** — sign out → relaunch → no residual session; delete account → re-signup same email works; wrong-password attempts don't reveal email existence.
- **Data** — force-quit mid-PKPass import → no corrupt state; restore device from iCloud backup → encrypted fields unreadable without device; lock device → app group files inaccessible.
- **3rd-party** — proxy through Proxyman → capture every outbound request; confirm no PII egress in bodies or query strings; run with ATT denied → Amplitude respects; uninstall / reinstall → no sticky tracking id.

## Out of scope

- Performance audit (user deferred; separate spec).
- App Store review blockers outside security / privacy (icons, screenshots, copy).
- Supabase backend beyond RLS + key hygiene (server-side audit separate).

## Acceptance

Audit complete when:

- All three passes committed with findings docs.
- `audit-summary.md` lists zero outstanding Crit or High.
- `backlog.md` exists with all Med / Low.
- Build archives without privacy manifest validator errors.
- Summary issues explicit TestFlight-readiness call (go / no-go).
