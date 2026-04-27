# Apple + Google Sign-In Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Sign in with Apple and Google as additional sign-in / sign-up options on top of the existing email + password flow, exchanging each provider's id_token for a Supabase session.

**Architecture:** Both providers use Supabase's `signInWithIdToken(credentials:)` so the rest of the app's auth pipeline (auth-state listener, beta auto-link, profile hydration, push registration) runs unchanged. Apple goes through `ASAuthorizationAppleIDProvider` with a sha256-hashed nonce; Google goes through the official `GoogleSignIn-iOS` SDK with its own iOS client ID. Native `SignInWithAppleButton` + a custom Google button live in a shared `SocialAuthButtons` view embedded in both `LogInView` and `SignUpView`.

**Tech Stack:** Swift / SwiftUI, AuthenticationServices, CryptoKit, GoogleSignIn-iOS (SPM), supabase-swift 2.43, Lumoria design system.

**Companion plan:** `2026-04-27-beta-code-reconciliation.md` — beta-status auto-link runs after every signed-in event regardless of provider, so the OAuth path inherits it without changes. Apple Private Relay users will not match by email and remain unhandled by code-only redemption (server lookup is JWT-email keyed) — see "Open follow-up" below.

**Status as of 2026-04-27:** Implemented + committed on `feat/beta-code-reconciliation`. User-driven config (next section) still required before this works on a real device.

---

## User-driven configuration

These steps cannot be automated and must be completed before the OAuth buttons work. Do them in this order.

- [ ] **Apple Developer portal** — open the App ID for `bearista.Lumoria-App`, enable "Sign in with Apple" capability, save (regenerates the provisioning profile).
- [ ] **Apple Developer portal — Service ID + key** for Supabase:
  - Identifiers → "+" → Services IDs → Description "Lumoria Web Service", Identifier `bearista.Lumoria-App.signin` (or similar) → enable Sign in with Apple → Configure → Primary App ID = `bearista.Lumoria-App`, Domains = `vhozwnykphqujsiuwesi.supabase.co`, Return URLs = `https://vhozwnykphqujsiuwesi.supabase.co/auth/v1/callback` → Save
  - Keys → "+" → Sign in with Apple → Configure → Primary App ID = `bearista.Lumoria-App` → Save → download the `.p8`, copy the Key ID
  - Note your Team ID (Membership tab)
- [ ] **Supabase Dashboard → Authentication → Providers → Apple**: enable, paste Service ID, Team ID, Key ID, contents of the `.p8`. Save.
- [ ] **Google Cloud Console — OAuth consent screen** (already done if you've used Google APIs before in this project): External, app name `Lumoria`, your support email, your dev contact email. Leave in Testing mode for now.
- [ ] **Google Cloud Console — Credentials**: Create iOS OAuth client. Bundle ID `bearista.Lumoria-App`. Team ID = your Apple Team ID. Save.
- [ ] **Supabase Dashboard → Authentication → Providers → Google**: enable, paste the iOS client ID into both "Client ID" and "Authorized Client IDs". No client secret.
- [ ] **Xcode**: confirm `GoogleSignIn-iOS` SPM package is in the `Lumoria App` target (already added in this branch).
- [ ] **Xcode → Lumoria App target → Signing & Capabilities**: confirm "Sign in with Apple" capability is present (entitlements file already declares it).

---

## File Structure

**New:**
- `Lumoria App/services/auth/AppleSignInService.swift` — async wrapper around `ASAuthorizationController` + Supabase token exchange.
- `Lumoria App/services/auth/GoogleSignInService.swift` — async wrapper around `GIDSignIn` + Supabase token exchange.
- `Lumoria App/views/authentication/SocialAuthButtons.swift` — shared view used by both LogInView and SignUpView.

**Modified:**
- `Info.plist` — added `CFBundleURLTypes` entry for the Google reversed iOS client ID (`com.googleusercontent.apps.597649446800-...`).
- `Lumoria App/views/authentication/AuthManager.swift` — added `signInWithApple()` and `signInWithGoogle()` async methods.
- `Lumoria App/views/authentication/LogInView.swift` — embeds `SocialAuthButtons(mode: .signIn)` after the password actions block.
- `Lumoria App/views/authentication/SignUpView.swift` — embeds `SocialAuthButtons(mode: .signUp)` after the primary CTA.
- `Lumoria App.xcodeproj/project.pbxproj` — auto-edited by Xcode when the `GoogleSignIn-iOS` SPM package was added.

---

## Implementation summary (already executed on this branch)

1. **Apple Sign-In service** generates a 32-char raw nonce, sha256s it for the `request.nonce`, presents the system sheet via an internal coordinator that bridges `ASAuthorizationControllerDelegate` to async/await, and forwards the resulting identity token + raw nonce to `supabase.auth.signInWithIdToken(credentials: .init(provider: .apple, idToken: ..., nonce: rawNonce))`.

2. **Google Sign-In service** assigns `GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: ...)` lazily, calls `GIDSignIn.sharedInstance.signIn(withPresenting:)`, then forwards `result.user.idToken!.tokenString` (and `accessToken.tokenString`) to `supabase.auth.signInWithIdToken(credentials: .init(provider: .google, idToken: ..., accessToken: ...))`.

3. **Cancellation**: both services throw `.canceled` on user abort. The `SocialAuthButtons` swallows that case silently so the form returns to its idle state without an error banner.

4. **Inherited beta-link**: existing `AuthManager.listenForAuthChanges` calls `autoLinkBetaByEmail()` and `checkBetaStatus()` on every `.signedIn` event. New OAuth sign-ins flow through that path with no extra wiring.

---

## Open follow-up

**Apple Private Relay handling** — when a user signs in with Apple and chooses "Hide my email", their `auth.users.email` will be `xyz@privaterelay.appleid.com` and will not match any waitlist row. Three options:

1. **Best**: extend `BetaCodeRedemptionView` with a "Use a different email" disclosure that reveals an email field; submit `(email, code)` to a refactored verify function that accepts a body-supplied email (the current code-only contract was a deliberate simplification per Figma 1983:129010).
2. **Cheap**: a Settings-side "Have a beta code?" entry point that always asks for email + code.
3. **Defer** until first user actually hits this — Apple sign-in will be off by default for now.

Choose when traffic on Apple sign-in is non-zero.

---

## Verification (user-driven)

- [ ] Sign-in with Apple from a fresh iPhone using a real iCloud account → returns to LogInView dismissed → ContentView appears → `AuthManager.isAuthenticated == true` in logs.
- [ ] Sign-in with Apple where the iCloud email matches a `waitlist_subscribers.email` → `link_beta_by_email()` flips `supabase_user_id` → `isBetaSubscriber == true` without surfacing the redemption sheet.
- [ ] Sign-in with Apple using "Hide my email" → user authenticated, but `isBetaSubscriber` stays false and the redemption sheet appears (until follow-up above ships, the user has no path to redeem).
- [ ] Sign-in with Google from a fresh device → returns to ContentView authed → same beta-link behaviour as Apple.
- [ ] Cancel mid-flow on either provider → no error banner, form remains usable.
- [ ] Existing email/password flows still work post-merge.
