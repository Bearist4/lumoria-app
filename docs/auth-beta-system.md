# Authentication & Beta Code System

_Last updated: 2026-04-28 — branch `feat/beta-code-reconciliation`_

This document describes how authentication works in Lumoria, how beta access is granted via redemption codes, why we need a code-reconciliation step, what happens to a user's data on account deletion, and which emails we send during the flow.

---

## 1. Auth provider stack

Lumoria runs on **Supabase Auth** with three sign-in surfaces:

| Method | Implementation | Notes |
|---|---|---|
| Email + password | Supabase native | Default flow |
| Magic link | Supabase native | Passwordless |
| Sign in with Apple | `ASAuthorizationController` → `signInWithIdToken` | Canonical handler-driven flow |
| Sign in with Google | `GoogleSignInService` → `signInWithIdToken` | Same pattern as Apple |

**Client init** — `Lumoria App/SupabaseManager.swift`
- Single global `SupabaseClient`
- Project URL: `https://vhozwnykphqujsiuwesi.supabase.co`
- `emitLocalSessionAsInitialSession: true` so cached sessions restore on cold start

**Session lifecycle** — `AuthManager.listenForAuthChanges()`
- Listens for `.initialSession`, `.signedIn`, `.tokenRefreshed`, `.userUpdated`, `.signedOut`
- After every (non-signedOut) event, runs the same chain:
  1. Check session validity
  2. Provision encryption key for the user's UUID
  3. **Auto-link beta** (see §3)
  4. Refresh `isBetaSubscriber` via `checkBetaStatus()`
  5. Claim any pending invite
- On `.signedOut`: clears auth state, beta status, analytics identity, and `AuthCache`

**`AuthCache`** persists `lastKnownAuthenticated` to `UserDefaults` so the app shows the right first frame (ContentView vs. LandingView) while the async session restore is in flight.

**JWT verification (edge functions)** — Both `verify-beta-code` and `delete-account` verify JWTs **manually using JWKS** via the `jose` library, instead of relying on the Supabase gateway's `verify_jwt`. The project uses ES256 asymmetric keys, which the gateway rejects. JWKS is cached in the function isolate.

---

## 2. Beta code redemption flow

### 2.1 Why codes (not email-only) anymore

Originally we linked waitlist subscribers to auth users by email match alone. That broke for:
- **Sign in with Apple private relay** — Apple emits `xyz@privaterelay.appleid.com`, which never matches the email used to join the waitlist.
- **Multiple addresses** — User signs up with personal email, signs in with work email.
- **Case sensitivity differences** between auth providers.

Adding a 6-digit code that the user receives by email gives a second identifier independent of the auth email.

### 2.2 UI

`Lumoria App/views/authentication/BetaCodeRedemptionView.swift`

Sheet is presented from `ContentView` when **all** of these are true:
- `authManager.isAuthenticated == true`
- `authManager.isBetaSubscriber == false`
- `authManager.betaStatusKnown == true` (status check has settled)
- `hasOfferedBetaRedemption == false` (not yet offered this session)

The input is `LumoriaCodeInput`, a 6-cell OTP field (50pt tall, SF Pro Rounded Semibold 20). It strips non-digits and clamps to 6 digits via `LumoriaCodeInput.sanitize()`. Tests in `Lumoria AppTests/LumoriaCodeInputTests.swift`.

### 2.3 Edge function — `verify-beta-code`

`supabase/functions/verify-beta-code/index.ts`

```
POST /functions/v1/verify-beta-code
Authorization: Bearer <JWT>
Body: { "code": "123456" }
```

**Steps:**
1. Manual JWKS verification → extract `payload.sub` (auth user id), 401 if missing.
2. Normalize code via `normalizeCode()` (strips whitespace and `[\s\-_.]`), then validate `/^[0-9]{6}$/`.
3. Compute `hashCode(normalized)` — SHA-256 hex digest, 64 chars.
4. Look up `public.waitlist_subscribers WHERE code_hash = <hash>` (limit 2 to detect collisions). **Lookup is by code only — never by email.**
5. Run rate-limit check: count rows in `beta_redemption_attempts` where `auth_user_id = userId AND success = false AND attempted_at > now() - 1h`.
6. `decide()` returns one of six outcomes (see §2.4).
7. Insert one row into `beta_redemption_attempts` for **every** attempt (success or failure).
8. On success: `UPDATE waitlist_subscribers SET supabase_user_id = userId, linked_at = now() WHERE id = row.id`. If the update fails, return 500 `link_failed` (don't return 200 with an unlinked row).

### 2.4 Outcomes

| Outcome | Trigger | UI message |
|---|---|---|
| `ok` | All checks pass | "Beta access unlocked." |
| `wrong_code` | No matching `code_hash`, or 2+ rows match | "That code doesn't match. Double-check and try again." |
| `expired` | `code_expires_at` is null or in the past | "That code expired. Tap 'Resend a code'." |
| `already_claimed` | Row's `supabase_user_id` already set | "Your waitlist entry is already linked to another account." |
| `not_found` | (from resend flow context) | "We don't see that email on the waitlist. Double-check it's the same one you signed up with on lumoria.com." |
| `rate_limited` | ≥5 failed attempts in trailing 1h | "Too many wrong attempts. Try again in an hour." |

### 2.5 Rate limiting

`WINDOW_HOURS = 1`, `FAILED_ATTEMPT_LIMIT = 5`. **Only failed attempts count.** Successful redemption doesn't burn the budget — typos don't lock out the user.

### 2.6 Code hashing

`supabase/functions/_shared/beta_code.ts`

```ts
export async function hashCode(code: string): Promise<string> {
  const data = new TextEncoder().encode(code);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}
```

- Plaintext code is never stored.
- Hash sits in `waitlist_subscribers.code_hash`.
- Plaintext only goes out through the email body (Resend API).

### 2.7 Resend code — `resend-beta-code`

Triggered when the user taps "Resend a code" in the redemption sheet, optionally with an alternate email.

- **Silent no-match**: if email isn't on the waitlist, returns 200 `{ ok: true }`. Anti-enumeration — never confirm or deny waitlist membership.
- **Per-email 1h cooldown** based on `code_generated_at`. Same silent response on cooldown.
- Generates a new 6-digit code, hashes it, retries up to 8 times to avoid hash collisions with other live codes.
- Stamps `code_hash`, `code_generated_at`, `code_expires_at = now() + 30 days` on the row.

---

## 3. Code reconciliation

**Definition:** "Reconciliation" is the auto-link step that connects an authenticated user to their waitlist entry by email match, so the user never sees the redemption sheet when their auth email already matches the waitlist email. Manual code redemption (§2) is the fallback when reconciliation can't find a match.

### 3.1 The RPC — `link_beta_by_email`

`supabase/migrations/20260510000001_beta_helpers.sql`

```sql
CREATE OR REPLACE FUNCTION public.link_beta_by_email()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_email   text;
  v_updated int;
BEGIN
  IF v_user_id IS NULL THEN RETURN false; END IF;
  SELECT email INTO v_email FROM auth.users WHERE id = v_user_id;
  IF v_email IS NULL THEN RETURN false; END IF;
  UPDATE public.waitlist_subscribers
    SET supabase_user_id = v_user_id, linked_at = now()
    WHERE lower(email) = lower(v_email)
      AND supabase_user_id IS NULL;
  GET DIAGNOSTICS v_updated = row_count;
  RETURN v_updated > 0;
END;
$$;
```

- **Case-insensitive** match (`lower(email)`).
- **Idempotent** — returns false when no match or row already linked, never throws.
- Only `EXECUTE` granted to `authenticated`.

### 3.2 When it runs

`AuthManager.autoLinkBetaByEmail()` is called after every auth event in `listenForAuthChanges()` — i.e., right after `.initialSession`, `.signedIn`, `.tokenRefreshed`, `.userUpdated`. Errors are swallowed (returns false). If the RPC silently fails, the user still falls into the manual redemption sheet — no dead-end.

### 3.3 Why we need both auto-link and manual redemption

| Scenario | Resolved by |
|---|---|
| Auth email == waitlist email | **Auto-link** — user never sees the sheet |
| Auth email differs (Apple private relay, multi-email) | **Manual code** entry |
| Email matches but waitlist row predates the code feature (`code_hash IS NULL`) | **Auto-link** still works |
| Waitlist row exists but already linked to another auth user | Manual redemption returns `already_claimed` |

### 3.4 Backward compatibility

Migration `20260510000000_beta_redemption_codes.sql` makes the new code columns nullable on purpose:

> Existing rows keep working with NULL code fields; auto-link by email handles them when the user's auth email matches.

So legacy waitlist rows that were never issued a code don't need a backfill — they just continue to work via reconciliation.

---

## 4. Account deletion

### 4.1 Trigger

Settings → Profile → ⋯ menu → "Delete my account"
File: `Lumoria App/views/settings/ProfileView.swift`

Confirmation alert text:
> "This permanently removes your profile, tickets, memories, and invites. This cannot be undone."

Client sends `{ "confirmation": "DELETE" }` to the edge function. The string `"DELETE"` must be exact — protects against replayed/malformed requests.

On success, the client calls `supabase.auth.signOut()`, which fires the `.signedOut` listener and tears down all in-memory state.

### 4.2 Edge function — `delete-account`

`supabase/functions/delete-account/index.ts`

Order of operations (everything before the auth delete must succeed; partial failure aborts before deleting the auth user, to avoid orphaned auth records):

1. Fetch user metadata (for `avatar_path` cleanup later). Stale avatar is acceptable.
2. Fetch all `memories.id` and `tickets.id` for the user.
3. Cascade junction table:
   - `DELETE FROM memory_tickets WHERE memory_id IN (...)`
   - `DELETE FROM memory_tickets WHERE ticket_id IN (...)`
4. Delete user-scoped rows in dependency order:
   - `notifications`
   - `tickets`
   - `memories`
   - `device_tokens`
   - `notification_prefs`
   - `announcement_reads`
   - `invites WHERE inviter_id = userId`
5. Unlink invites the user **claimed**:
   ```sql
   UPDATE invites SET claimed_by = null, claimed_at = null
   WHERE claimed_by = userId
   ```
   The inviter still owns the invite — only the claim is severed.
6. **Unlink waitlist row — do NOT delete it:**
   ```sql
   UPDATE waitlist_subscribers
   SET supabase_user_id = null, linked_at = null
   WHERE supabase_user_id = userId
   ```
   The row is keyed by email and stays. This lets the same email join again or redeem a fresh code later.
7. Best-effort delete of the avatar ciphertext from the `avatars` storage bucket. Errors ignored.
8. `admin.auth.admin.deleteUser(userId)` — wipes `auth.users`. Cascades delete `public.profiles` via FK. Fires `.signedOut` to the iOS listener.

**Hard delete, not soft delete.** No tombstones, no recoverable state.

---

## 5. Emails we send

| Email | Sent by | Subject | Trigger |
|---|---|---|---|
| Confirm signup | Supabase native | (Supabase template) | Email/password signup |
| Magic link | Supabase native | (Supabase template) | Passwordless sign-in |
| Beta code | `resend-beta-code` edge function via Resend API | **"Your Lumoria beta code"** | User taps "Resend a code" |

### Beta code email design

Mirrors the Supabase "Confirm signup" template visually so confirm / reset / beta-code emails feel consistent. From the function source comment:

> Mirrors the visual structure of the Supabase "Confirm signup" template (logo, EB Garamond heading, body copy, code/CTA block, security note, footer) so the user sees a consistent Lumoria look across confirm / reset / beta-code emails.

- Logo: Lumoria SVG from Supabase storage
- Heading: "Here's a fresh code." — EB Garamond, 34px, 600
- Body copy:
  > You asked for a new code. Open the Lumoria app, sign in, and enter the 6-digit code below to claim your beta access.
  >
  > This code expires in 30 days. Any earlier code we sent you is no longer valid.
- Code block: SF Mono 42px, letter-spacing 0.4em, gray box (#f5f5f5, radius 16px)
- Security footer: "Didn't request a new code? You can safely ignore this email. No action will be taken on your account."
- Footer: privacy policy, contact email, beta signup notice

Commit reference: `bb2a168 feat(email): match Supabase confirm-email template for beta code`

---

## 6. Database schema (auth/beta-relevant)

### `public.waitlist_subscribers`
| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `email` | text | indexed case-insensitive (`waitlist_subscribers_email_lower_idx`) |
| `supabase_user_id` | uuid nullable | FK → `auth.users.id`, ON DELETE SET NULL via the delete-account flow |
| `linked_at` | timestamptz nullable | |
| `code_hash` | text nullable | SHA-256 hex; **column-level SELECT revoked from anon + authenticated** |
| `code_expires_at` | timestamptz nullable | 30 days from generation |
| `code_generated_at` | timestamptz nullable | for resend cooldown |

```sql
REVOKE SELECT (code_hash, code_expires_at, code_generated_at)
  ON public.waitlist_subscribers FROM anon, authenticated;
```
Edge functions use the service role and bypass this.

### `public.beta_redemption_attempts`
| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `auth_user_id` | uuid | FK → `auth.users.id`, cascade delete |
| `email_attempted` | text | which email the user tried |
| `success` | boolean | |
| `attempted_at` | timestamptz default now() | |

Index `(auth_user_id, attempted_at DESC)`. **RLS enabled, no policies → deny by default to clients.** Edge functions only.

### `public.profiles`
- `user_id` (uuid PK, FK → `auth.users.id`, cascade)
- `show_onboarding`, `onboarding_step`
- `grandfathered_at` (timestamptz nullable) — first 100 linked beta users get this stamped via trigger; trigger raises `grandfathered_at is read-only` on any client modification attempt.

---

## 7. Non-obvious behaviors

1. **Rate limit applies to failed attempts only** — successful redemption is free. Typos don't permanently lock the user.
2. **Hash collision returns `wrong_code`** — if 2+ rows match the same `code_hash`, we refuse to guess. Forces support contact.
3. **Resend is silent on no-match and cooldown** — anti-enumeration + anti-spam, identical 200 response either way.
4. **Auto-link is case-insensitive** by design — different auth providers normalize email differently.
5. **Account deletion preserves the waitlist row** — only `supabase_user_id` and `linked_at` are nulled; same email can re-enroll.
6. **Grandfathered status is immutable** — DB trigger blocks writes from authenticated users. First 100 beta testers get lifetime free Premium.
7. **JWT verified via JWKS in the function**, not via gateway `verify_jwt` — gateway rejects ES256, project uses asymmetric keys. JWKS cached in isolate.
8. **Avatar storage cleanup is best-effort** — failures don't block account delete or profile save.
9. **Beta status sheet is gated by `betaStatusKnown`** — prevents flashing the redemption sheet during the brief window before `checkBetaStatus()` settles on cold start.
10. **`emitLocalSessionAsInitialSession: true`** + `AuthCache` means the app shows the correct root view on cold start without a flash, even before the network call to refresh the session resolves.

---

## 8. Recent commits on `feat/beta-code-reconciliation`

| Commit | Summary |
|---|---|
| `bb2a168` | feat(email): match Supabase confirm-email template for beta code |
| `5a00dd2` | feat(beta): code-only redemption, lookup row by code_hash |
| `4749f85` | fix(beta): bring back email field + soften the rate limit |
| `222d2b4` | chore: remove macOS Finder duplicate Group 2.pdf |
| `879b6dd` | fix(auth): surface the real verify-beta-code error to the UI |
