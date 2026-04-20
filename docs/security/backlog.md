# Security backlog — deferred items (2026-04-20)

Items below were found during the 2026-04-20 pre-TestFlight audit and classified as `med` or `low`. They are not TestFlight blockers. Pick up before App Store submission.

## Medium priority

- **Pass 1 · 1.8** — `SignUpView.swift:271` — sign-up error surface leaks Supabase's raw "User already registered" message, enabling email enumeration. Replace with generic "We couldn't create your account. If you already have one, try logging in." copy for the `.email_in_use` error branch. Analytics already categorizes the error; only UI copy needs to change.
- **Pass 3 · 3.4b** — Xcode project links `AmplitudeUnified`, which transitively embeds `AmplitudeSessionReplay.framework` even though the feature is never instantiated. Switching the SPM dependency to `amplitude-swift` directly would drop the dead framework, shrink the bundle, and simplify App Store privacy-label review.

## Low priority

- **Pass 1 · 1.4b** — `InvitesStore.swift:165` — release `print` logs the raw invite token on claim failure. The token is public (Crockford base32 invite code), but release log noise around user-entered strings is avoidable. Wrap in `#if DEBUG` or drop the token interpolation.
- **Pass 2 · 2.3b** — `LumoriaPKPassImport/ShareViewController.swift:145` — `data.write(to: target, options: .atomic)` inherits the app-group directory's default protection class. Adding `.completeFileProtectionUntilFirstUserAuthentication` explicitly is defense-in-depth.
- **Pass 2 · 2.8b** — `Lumoria_AppApp.swift` scene-phase handler — no backgrounding snapshot obscuration; task-switcher previews show ticket lists. Add an `.onChange(of: scenePhase)` branch that sets a blurred-or-branded overlay on `.inactive` / `.background`.
- **Pass 3 · 3.12** — Product policy: never include user-entered ticket names / venues / seats in `notifications.title` or `notifications.message` rows, since those pass through the `send-push` edge function straight into APNs `alert.*`. Today the only writers are `announcements` broadcasts + onboarding seeds, which is fine — keep it that way.
