# Security audit summary — 2026-04-20

Spec: `docs/superpowers/specs/2026-04-20-security-audit-design.md`
Plan: `docs/superpowers/plans/2026-04-20-security-audit.md`
Pass docs: `docs/security/2026-04-20-pass-{1-auth,2-data,3-third-party}.md`
Backlog: `docs/security/backlog.md`

Scope was pre-TestFlight security/data only — no performance audit, no App Store review items outside security/privacy. User approved the area-by-area plan with inline Crit/High fixes (option B) on a fresh `security-audit` branch off `main`.

## Counts

| Pass | Crit | High | Med | Low | OK |
|------|-----:|-----:|----:|----:|---:|
| 1 — Auth          | 0 | 4 | 1 | 1 | 6 |
| 2 — Data at rest  | 0 | 1 | 0 | 2 | 6 |
| 3 — Third-party   | 0 | 2 | 2 | 1 | 9 |
| **Total**         | **0** | **7** | **3** | **4** | **21** |

All Crit+High findings were addressed inline (7/7). Med+Low (7/7) are in `backlog.md`.

## High fixes landed

1. **Account deletion** (1.6) — `ProfileView.swift` wired to new `delete-account` Supabase edge function that deletes every user-scoped row in FK order + avatar ciphertext + `auth.admin.deleteUser`. Required by App Store 5.1.1(v). [commit `a9c4791`]
2. **Function search_path hardening** (1.9b, 1.9c) — DB migration `pin_trigger_function_search_paths` sets `search_path = public, pg_catalog` on `set_updated_at()` and `set_notification_prefs_updated_at()`. Advisor re-run confirms resolved.
3. **PKPass content log leak** (2.5d) — Four `NSLog` statements in `PKPassImporter.swift` were dumping full `pass.json`, every field value, and parsed flight/train details (seat, flight number, origin/dest, gate, terminal, car) into the system log in **every build**. Gated behind `#if DEBUG`. [commit `97e8d7b`]
4. **App-level PrivacyInfo.xcprivacy** (3.6) — Added at `Lumoria App/PrivacyInfo.xcprivacy`. Declares collected data (email/name/photos/user content → AppFunctionality; product interaction/device id → Analytics; crash data → AppFunctionality), `NSPrivacyAccessedAPICategoryUserDefaults` reason `CA92.1`, `NSPrivacyTracking = false`. [commit `8f33438`]
5. **Export compliance** (3.7) — Added `ITSAppUsesNonExemptEncryption = false` to `Info.plist` so TestFlight skips the annual export-compliance self-classification. Lumoria's CryptoKit use qualifies under the standard Category 5 Part 2 exemption. [commit `8f33438`]

## Remaining risks (TestFlight-relevant)

Two items require action outside the CLI:

- **Leaked-password protection** (1.9d, high) — Supabase dashboard toggle needed: **Auth → Policies → "Leaked password protection"**. HaveIBeenPwned integration is off. One-click fix, no migration. MCP can't flip it; user must.
- **PrivacyInfo.xcprivacy target membership** (3.6) — The file is on disk and committed, but `Write` cannot safely edit `project.pbxproj`. The file must be added to the **Lumoria App** target via Xcode: right-click `Lumoria App` group → "Add Files to Lumoria App…" → select `PrivacyInfo.xcprivacy` → ensure "Lumoria App" target is checked → Add. Without this step the bundle won't contain the manifest and archive validation will flag it.

Neither blocks building or running the app. Both should be resolved before uploading to App Store Connect.

## TestFlight readiness

**GO**, conditional on two manual items:

1. Flip leaked-password protection in Supabase dashboard (one click).
2. Add `PrivacyInfo.xcprivacy` to the app target in Xcode (one drag-and-drop or Add Files dialog).

After those two, the branch is ready to merge to `main` and archive for TestFlight. No outstanding Crit, no outstanding code-level High.

## Verification evidence

- `mcp__supabase__get_advisors(type:"security")` re-run post-migration confirms `function_search_path_mutable` lints are resolved. Remaining lints: `rls_enabled_no_policy` on `_push_debug` (benign — debug-only table, service-role-write) and `auth_leaked_password_protection` (dashboard toggle noted above).
- `git log security-audit` shows 6 commits: pass 1 + sha backfill, pass 2 + sha backfill, pass 3 + sha backfill, plus summary.
- Pass findings docs each have exhaustive rows per check id with location, severity, description, and commit column.

## Out of scope (flagged for later)

- **Performance audit** — user deferred. Worth spinning up a separate spec covering launch time, scroll jank on large ticket lists, and memory footprint under the PKPass/sticker render pipeline.
- **Full App Store review readiness** outside security/privacy — screenshots, marketing copy, age rating, category selection. Handle at App Store submission time.
- **Supabase backend audit** beyond RLS + key hygiene + function search_path. No server-side business-logic audit performed.
