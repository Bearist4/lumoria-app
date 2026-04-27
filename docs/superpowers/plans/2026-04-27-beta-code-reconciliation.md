# Beta Code Reconciliation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let any signed-in user (regardless of auth provider) claim their beta status by entering a 6-digit code we mailed them at website signup, when their auth-account email does not match their waitlist email (e.g. Apple Private Relay, typos, separate inboxes).

**Architecture:** Website generates a 6-digit numeric code at signup, stores `(code_hash, expires_at)` on the existing `waitlist_subscribers` row, and includes the code in the existing Resend confirmation email. iOS app calls Postgres RPC `link_beta_by_email()` post-signin to silently auto-link when emails match. If they don't match, the app shows a redemption screen that calls edge function `verify-beta-code` (rate-limited, hash-checked) and a `resend-beta-code` function for regenerating. Codes expire after 30 days. Rate limit: 1 redemption attempt / 24h per auth user (brute-force trivial: 1M codes × 1/day = 2700yr).

**Tech Stack:** Supabase Postgres + RLS, Supabase Edge Functions (Deno), Resend, Next.js Server Actions (Node), SwiftUI, Supabase Swift SDK, Swift Testing.

**Companion plan:** `2026-04-27-apple-google-signin.md` (to be written) layers Apple + Google providers on top of this — this plan works standalone with current email/password auth.

---

## File Structure

**New files (Supabase backend):**
- `Lumoria App/supabase/migrations/20260510000000_beta_redemption_codes.sql` — adds `code_hash`, `code_expires_at`, `code_generated_at` to `waitlist_subscribers`; new `beta_redemption_attempts` table; RLS.
- `Lumoria App/supabase/migrations/20260510000001_beta_helpers.sql` — `link_beta_by_email()` and `count_recent_redemption_attempts()` Postgres functions.
- `Lumoria App/supabase/functions/_shared/beta_code.ts` — code generation + hashing helpers (shared by both edge functions).
- `Lumoria App/supabase/functions/_shared/beta_code.test.ts` — Deno unit tests for helpers.
- `Lumoria App/supabase/functions/verify-beta-code/index.ts` — verifies submitted code, links row, logs attempt.
- `Lumoria App/supabase/functions/verify-beta-code/index.test.ts` — Deno integration tests.
- `Lumoria App/supabase/functions/resend-beta-code/index.ts` — generates a fresh code (or first one for legacy rows), updates row, mails it.

**Modified file (website):**
- `lumoria/src/app/actions/subscribe.ts` — generate code, hash + insert, include code in email body. Update `buildEmailHtml()` signature to accept the code.

**New files (iOS):**
- `Lumoria App/components/LumoriaCodeInput.swift` — 6-digit segmented numeric input.
- `Lumoria App/components/LumoriaCodeInputTests.swift` (in test target) — Swift Testing for digit constraints + paste handling.
- `Lumoria App/views/authentication/BetaCodeRedemptionView.swift` — full-screen sheet: email + code + verify + resend.

**Modified files (iOS):**
- `Lumoria App/views/authentication/AuthManager.swift` — add `autoLinkBetaByEmail()`, `redeemBetaCode(email:code:)`, `resendBetaCode(email:)`; call `autoLinkBetaByEmail()` from `listenForAuthChanges` before `checkBetaStatus()`.
- `Lumoria App/views/onboarding/OnboardingCoordinator.swift` — surface `BetaCodeRedemptionView` when `isAuthenticated && !isBetaSubscriber` after sign-in.

---

## Phase 1: Schema

### Task 1: Migration — add code columns + attempts table

**Files:**
- Create: `Lumoria App/supabase/migrations/20260510000000_beta_redemption_codes.sql`

- [ ] **Step 1: Write migration**

```sql
-- 20260510000000_beta_redemption_codes.sql
-- Adds 6-digit redemption code support for the beta waitlist.

-- 1. New columns on waitlist_subscribers. All nullable: existing rows keep
--    working without a code, new rows get one at insert time. The hash is
--    SHA-256 hex of the plaintext code; we never store the plaintext.
alter table public.waitlist_subscribers
  add column if not exists code_hash text,
  add column if not exists code_expires_at timestamptz,
  add column if not exists code_generated_at timestamptz;

create index if not exists waitlist_subscribers_email_lower_idx
  on public.waitlist_subscribers (lower(email));

-- 2. Per-attempt log. One row per redemption attempt (success or failure)
--    keyed by the authenticated user. Used for rate limiting and audit.
create table if not exists public.beta_redemption_attempts (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null references auth.users(id) on delete cascade,
  email_attempted text not null,
  success boolean not null,
  attempted_at timestamptz not null default now()
);

create index if not exists beta_redemption_attempts_user_time_idx
  on public.beta_redemption_attempts (auth_user_id, attempted_at desc);

-- 3. RLS: clients never read or write attempts directly. Edge functions
--    use the service role and bypass RLS.
alter table public.beta_redemption_attempts enable row level security;

-- No policies = no client access. Service role bypasses RLS.

-- 4. waitlist_subscribers RLS already exists from prior migrations; verify
--    that clients cannot read code_hash. Update existing read policies if
--    they used `select *`. (Inspect existing policies before deploying.)
comment on column public.waitlist_subscribers.code_hash is
  'SHA-256 hex of plaintext 6-digit code. Never expose to clients.';
```

- [ ] **Step 2: Inspect existing waitlist_subscribers RLS to make sure code_hash is not exposed**

Run:
```bash
supabase db diff --schema public --linked
```
And manually open `Lumoria App/supabase/migrations/` to find any prior policy on `waitlist_subscribers`. If a policy uses `select *` or grants column-level access including `code_hash`, narrow it to specific columns excluding `code_hash`, `code_expires_at`, `code_generated_at`. Add a follow-up `alter policy` migration if needed.

Expected: confirm that authenticated users can only `select` `id, email, supabase_user_id, linked_at` (the columns currently consumed by `WaitlistRecord` in `AuthManager.swift`). If the policy is permissive, write a narrowing migration in this same file before commit.

- [ ] **Step 3: Apply migration locally**

Run: `supabase db reset --linked` or `supabase db push` against staging.
Expected: migration applies cleanly. Verify in psql:
```sql
\d public.waitlist_subscribers
\d public.beta_redemption_attempts
```
Both tables show the new columns/structure.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/supabase/migrations/20260510000000_beta_redemption_codes.sql"
git commit -m "feat(beta): schema for 6-digit redemption codes + attempt log"
```

### Task 2: Migration — Postgres helpers (`link_beta_by_email`, `count_recent_redemption_attempts`)

**Files:**
- Create: `Lumoria App/supabase/migrations/20260510000001_beta_helpers.sql`

- [ ] **Step 1: Write migration**

```sql
-- 20260510000001_beta_helpers.sql
-- Postgres helpers for beta reconciliation. Both run as security definer
-- so the calling user can invoke them without write access to the table.

-- 1. Auto-link by email match. Returns true if a row was linked.
create or replace function public.link_beta_by_email()
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_email text;
  v_updated int;
begin
  if v_user_id is null then
    return false;
  end if;

  select email into v_email from auth.users where id = v_user_id;
  if v_email is null then
    return false;
  end if;

  update public.waitlist_subscribers
     set supabase_user_id = v_user_id,
         linked_at = now()
   where lower(email) = lower(v_email)
     and supabase_user_id is null;

  get diagnostics v_updated = row_count;
  return v_updated > 0;
end;
$$;

revoke all on function public.link_beta_by_email() from public;
grant execute on function public.link_beta_by_email() to authenticated;

-- 2. Count attempts in the trailing 24h window for the calling user.
--    Used by edge functions before processing a redemption.
create or replace function public.count_recent_redemption_attempts(window_hours int default 24)
returns int
language sql
security definer
set search_path = public
as $$
  select count(*)::int
    from public.beta_redemption_attempts
   where auth_user_id = auth.uid()
     and attempted_at > now() - make_interval(hours => window_hours);
$$;

revoke all on function public.count_recent_redemption_attempts(int) from public;
grant execute on function public.count_recent_redemption_attempts(int) to authenticated;
```

- [ ] **Step 2: Apply migration locally**

Run: `supabase db push`
Expected: migration applies. In psql, with a test JWT, `select link_beta_by_email();` returns `false` for an account with no matching waitlist row, `true` for one that matches.

- [ ] **Step 3: Commit**

```bash
git add "Lumoria App/supabase/migrations/20260510000001_beta_helpers.sql"
git commit -m "feat(beta): Postgres RPCs for auto-link and attempt counting"
```

---

## Phase 2: Edge functions

### Task 3: Shared code helper + tests

**Files:**
- Create: `Lumoria App/supabase/functions/_shared/beta_code.ts`
- Create: `Lumoria App/supabase/functions/_shared/beta_code.test.ts`

- [ ] **Step 1: Write the failing test file**

```ts
// beta_code.test.ts
import { assertEquals, assertMatch } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { generateCode, hashCode, normalizeCode, isExpired } from "./beta_code.ts";

Deno.test("generateCode returns 6 numeric digits", () => {
  for (let i = 0; i < 50; i++) {
    const code = generateCode();
    assertMatch(code, /^[0-9]{6}$/);
  }
});

Deno.test("hashCode is stable and SHA-256 hex (64 chars)", async () => {
  const a = await hashCode("123456");
  const b = await hashCode("123456");
  assertEquals(a, b);
  assertEquals(a.length, 64);
});

Deno.test("hashCode differs for different inputs", async () => {
  const a = await hashCode("123456");
  const b = await hashCode("123457");
  if (a === b) throw new Error("hash collision on adjacent codes");
});

Deno.test("normalizeCode strips whitespace and dashes", () => {
  assertEquals(normalizeCode(" 123 456 "), "123456");
  assertEquals(normalizeCode("123-456"), "123456");
  assertEquals(normalizeCode("123456"), "123456");
});

Deno.test("isExpired", () => {
  const past = new Date(Date.now() - 1000).toISOString();
  const future = new Date(Date.now() + 60_000).toISOString();
  assertEquals(isExpired(past), true);
  assertEquals(isExpired(future), false);
  assertEquals(isExpired(null), true);
});
```

- [ ] **Step 2: Run test, expect failure**

Run: `deno test "Lumoria App/supabase/functions/_shared/beta_code.test.ts"`
Expected: FAIL with "Module not found ./beta_code.ts".

- [ ] **Step 3: Write the implementation**

```ts
// beta_code.ts
const CODE_LENGTH = 6;

/** Generates a uniformly-random 6-digit string using crypto.getRandomValues. */
export function generateCode(): string {
  const buf = new Uint32Array(1);
  // Reject samples in the high tail to avoid modulo bias.
  // 4_000_000_000 is the largest multiple of 1_000_000 ≤ 2^32.
  const limit = 4_000_000_000;
  let n: number;
  do {
    crypto.getRandomValues(buf);
    n = buf[0];
  } while (n >= limit);
  return (n % 1_000_000).toString().padStart(CODE_LENGTH, "0");
}

/** SHA-256 hex digest of the plaintext code. */
export async function hashCode(code: string): Promise<string> {
  const data = new TextEncoder().encode(code);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/** Strips whitespace and common separators users paste. */
export function normalizeCode(input: string): string {
  return input.replace(/[\s\-_.]/g, "");
}

/** True if expiry is null/in the past. */
export function isExpired(expiresAt: string | null): boolean {
  if (!expiresAt) return true;
  return new Date(expiresAt).getTime() <= Date.now();
}
```

- [ ] **Step 4: Run test, expect pass**

Run: `deno test "Lumoria App/supabase/functions/_shared/beta_code.test.ts"`
Expected: 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add "Lumoria App/supabase/functions/_shared/beta_code.ts" \
        "Lumoria App/supabase/functions/_shared/beta_code.test.ts"
git commit -m "feat(beta): shared code generation + hashing helpers"
```

### Task 4: `verify-beta-code` edge function

**Files:**
- Create: `Lumoria App/supabase/functions/verify-beta-code/index.ts`
- Create: `Lumoria App/supabase/functions/verify-beta-code/index.test.ts`

- [ ] **Step 1: Write the failing test**

```ts
// index.test.ts — focused on the pure decision logic. Network/DB calls
// are wrapped behind a small port we mock.
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { decide, type WaitlistRow } from "./index.ts";

const fresh: WaitlistRow = {
  id: "row-1",
  email: "user@example.com",
  code_hash: "fakehash",
  code_expires_at: new Date(Date.now() + 60_000).toISOString(),
  supabase_user_id: null,
};

Deno.test("decide: rate limited", () => {
  const r = decide({ row: fresh, submittedHash: "fakehash", attemptsIn24h: 1 });
  assertEquals(r.outcome, "rate_limited");
});

Deno.test("decide: no row for email", () => {
  const r = decide({ row: null, submittedHash: "x", attemptsIn24h: 0 });
  assertEquals(r.outcome, "not_found");
});

Deno.test("decide: expired", () => {
  const expired = { ...fresh, code_expires_at: new Date(Date.now() - 1).toISOString() };
  const r = decide({ row: expired, submittedHash: "fakehash", attemptsIn24h: 0 });
  assertEquals(r.outcome, "expired");
});

Deno.test("decide: wrong code", () => {
  const r = decide({ row: fresh, submittedHash: "wrong", attemptsIn24h: 0 });
  assertEquals(r.outcome, "wrong_code");
});

Deno.test("decide: already linked to someone else", () => {
  const linked = { ...fresh, supabase_user_id: "other-user" };
  const r = decide({ row: linked, submittedHash: "fakehash", attemptsIn24h: 0 });
  assertEquals(r.outcome, "already_claimed");
});

Deno.test("decide: success", () => {
  const r = decide({ row: fresh, submittedHash: "fakehash", attemptsIn24h: 0 });
  assertEquals(r.outcome, "ok");
});
```

- [ ] **Step 2: Run test, expect failure**

Run: `deno test "Lumoria App/supabase/functions/verify-beta-code/index.test.ts"`
Expected: FAIL — module not found.

- [ ] **Step 3: Write the function**

```ts
// index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { hashCode, isExpired, normalizeCode } from "../_shared/beta_code.ts";

const ATTEMPT_LIMIT = 1; // per 24h window per auth user
const WINDOW_HOURS = 24;

export interface WaitlistRow {
  id: string;
  email: string;
  code_hash: string | null;
  code_expires_at: string | null;
  supabase_user_id: string | null;
}

export type Outcome =
  | "ok"
  | "rate_limited"
  | "not_found"
  | "expired"
  | "wrong_code"
  | "already_claimed";

export function decide(args: {
  row: WaitlistRow | null;
  submittedHash: string;
  attemptsIn24h: number;
}): { outcome: Outcome } {
  if (args.attemptsIn24h >= ATTEMPT_LIMIT) return { outcome: "rate_limited" };
  if (!args.row) return { outcome: "not_found" };
  if (args.row.supabase_user_id !== null) return { outcome: "already_claimed" };
  if (isExpired(args.row.code_expires_at)) return { outcome: "expired" };
  if (args.row.code_hash !== args.submittedHash) return { outcome: "wrong_code" };
  return { outcome: "ok" };
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json({ error: "unauthenticated" }, 401);

  const { email, code } = await req.json().catch(() => ({}));
  if (typeof email !== "string" || typeof code !== "string") {
    return json({ error: "bad_request" }, 400);
  }
  const normalizedCode = normalizeCode(code);
  if (!/^[0-9]{6}$/.test(normalizedCode)) {
    return json({ error: "bad_request" }, 400);
  }

  // User-scoped client: enforces RLS, gives us auth.uid() in RPCs.
  const userClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } }
  );

  const { data: userData, error: userErr } = await userClient.auth.getUser();
  if (userErr || !userData.user) return json({ error: "unauthenticated" }, 401);
  const authUserId = userData.user.id;

  // Service-role client for privileged reads/writes on waitlist + attempts.
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  // 1. Count attempts in window (uses RPC for consistency with iOS path).
  const { data: attempts } = await userClient.rpc(
    "count_recent_redemption_attempts",
    { window_hours: WINDOW_HOURS }
  );
  const attemptsIn24h = (attempts as number | null) ?? 0;

  // 2. Fetch row.
  const { data: row } = await admin
    .from("waitlist_subscribers")
    .select("id, email, code_hash, code_expires_at, supabase_user_id")
    .ilike("email", email.trim())
    .maybeSingle();

  const submittedHash = await hashCode(normalizedCode);
  const result = decide({ row, submittedHash, attemptsIn24h });

  // 3. Log attempt (always, even rate-limited).
  await admin.from("beta_redemption_attempts").insert({
    auth_user_id: authUserId,
    email_attempted: email.trim().toLowerCase(),
    success: result.outcome === "ok",
  });

  // 4. On success, link.
  if (result.outcome === "ok" && row) {
    const { error: updErr } = await admin
      .from("waitlist_subscribers")
      .update({ supabase_user_id: authUserId, linked_at: new Date().toISOString() })
      .eq("id", row.id);
    if (updErr) return json({ error: "link_failed" }, 500);
  }

  return json({ outcome: result.outcome });
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", ...corsHeaders },
  });
}
```

- [ ] **Step 4: Run test, expect pass**

Run: `deno test "Lumoria App/supabase/functions/verify-beta-code/index.test.ts"`
Expected: 6 tests pass.

- [ ] **Step 5: Deploy and smoke-test against staging**

Run:
```bash
supabase functions deploy verify-beta-code \
  --project-ref <staging-ref>
```

Manually call from a staging-authenticated context (e.g. via the Supabase dashboard "Invoke" tab) with a known test email + code. Verify:
- Wrong code → 200 with `{outcome: "wrong_code"}`, attempt logged.
- Right code → 200 with `{outcome: "ok"}`, `waitlist_subscribers.supabase_user_id` set.
- Second attempt within 24h → `{outcome: "rate_limited"}`.

- [ ] **Step 6: Commit**

```bash
git add "Lumoria App/supabase/functions/verify-beta-code/"
git commit -m "feat(beta): verify-beta-code edge function with attempt log + rate limit"
```

### Task 5: `resend-beta-code` edge function

**Files:**
- Create: `Lumoria App/supabase/functions/resend-beta-code/index.ts`

- [ ] **Step 1: Write the function**

This function is callable from both the website (no auth, captcha-gated client-side) and the iOS app (authenticated). To keep parity with the website's existing model, we accept an unauthenticated request keyed by email but require Upstash rate limiting (1/hour per email) — matching the existing `getEmailRatelimit()` pattern in `subscribe.ts`.

```ts
// index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { Resend } from "https://esm.sh/resend@4";
import { generateCode, hashCode } from "../_shared/beta_code.ts";

const CODE_TTL_MS = 30 * 24 * 60 * 60 * 1000; // 30 days

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const { email } = await req.json().catch(() => ({}));
  if (typeof email !== "string" || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    return json({ error: "bad_request" }, 400);
  }
  const normalizedEmail = email.trim().toLowerCase();

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  // 1. Look up the row. Silent success if no match — never confirm or deny
  //    membership of the waitlist to an unauthenticated caller.
  const { data: row } = await admin
    .from("waitlist_subscribers")
    .select("id, email, code_generated_at")
    .ilike("email", normalizedEmail)
    .maybeSingle();

  if (!row) return json({ ok: true });

  // 2. Per-email cooldown. Compare against `code_generated_at` to throttle
  //    1/hour without an external store. Cheap; acceptable for a low-volume
  //    flow.
  if (row.code_generated_at) {
    const lastMs = new Date(row.code_generated_at as string).getTime();
    if (Date.now() - lastMs < 60 * 60 * 1000) {
      return json({ ok: true }); // silent
    }
  }

  // 3. Generate a new code, store its hash + new expiry.
  const plaintext = generateCode();
  const codeHash = await hashCode(plaintext);
  const expiresAt = new Date(Date.now() + CODE_TTL_MS).toISOString();
  const generatedAt = new Date().toISOString();

  const { error: updErr } = await admin
    .from("waitlist_subscribers")
    .update({
      code_hash: codeHash,
      code_expires_at: expiresAt,
      code_generated_at: generatedAt,
    })
    .eq("id", row.id);

  if (updErr) return json({ error: "update_failed" }, 500);

  // 4. Mail it.
  const resend = new Resend(Deno.env.get("RESEND_API_KEY")!);
  await resend.emails.send({
    from: Deno.env.get("RESEND_FROM_ADDRESS") ?? "hello@lumoria.com",
    to: normalizedEmail,
    subject: "Your Lumoria beta code",
    html: buildEmailHtml(plaintext),
  });

  return json({ ok: true });
});

function buildEmailHtml(code: string): string {
  return `<!DOCTYPE html>
<html lang="en"><body style="margin:0;padding:0;background:#fff;font-family:Georgia,serif;">
<table width="100%" cellpadding="0" cellspacing="0">
  <tr><td align="center" style="padding:64px 24px;">
    <table width="560" cellpadding="0" cellspacing="0" style="max-width:560px;width:100%;">
      <tr><td style="padding-bottom:32px;font-size:18px;font-weight:600;letter-spacing:0.06em;text-transform:uppercase;">Lumoria</td></tr>
      <tr><td style="padding-bottom:24px;"><h1 style="margin:0;font-size:34px;font-weight:600;line-height:1.2;letter-spacing:-0.01em;">Your beta code</h1></td></tr>
      <tr><td style="padding-bottom:32px;font-size:17px;line-height:1.65;color:#404040;">
        Enter this code in the Lumoria app to claim your beta access. It expires in 30 days.
      </td></tr>
      <tr><td align="center" style="padding-bottom:32px;">
        <div style="font-family:'SF Mono',Menlo,Consolas,monospace;font-size:42px;font-weight:600;letter-spacing:0.4em;color:#000;padding:24px 32px;background:#f5f5f5;border-radius:12px;display:inline-block;">${code}</div>
      </td></tr>
      <tr><td style="border-top:1px solid #e5e5e5;padding-top:32px;font-family:-apple-system,BlinkMacSystemFont,sans-serif;font-size:13px;line-height:1.6;color:#737373;">
        Didn't request this? You can ignore this email.
      </td></tr>
    </table>
  </td></tr>
</table>
</body></html>`;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", ...corsHeaders },
  });
}
```

- [ ] **Step 2: Deploy + smoke-test**

Run:
```bash
supabase functions deploy resend-beta-code --project-ref <staging-ref>
```
Manually call with a known test email. Verify:
- New email arrives with a 6-digit code.
- Repeating the call within an hour returns 200 but no duplicate email is sent (DB row's `code_generated_at` unchanged when blocked — actually it IS unchanged because we early-returned before the update; verify in dashboard).
- After 1 hour, calling again does send a fresh code.

- [ ] **Step 3: Commit**

```bash
git add "Lumoria App/supabase/functions/resend-beta-code/"
git commit -m "feat(beta): resend-beta-code edge function (1/hour cooldown per email)"
```

---

## Phase 3: Website signup flow

### Task 6: Generate code at signup + include in email

**Files:**
- Modify: `lumoria/src/app/actions/subscribe.ts`

- [ ] **Step 1: Add code generation helpers at the top of subscribe.ts**

After the imports (line 9), add:

```ts
const CODE_TTL_MS = 30 * 24 * 60 * 60 * 1000

function generateBetaCode(): string {
  const buf = new Uint32Array(1)
  const limit = 4_000_000_000
  let n: number
  do {
    crypto.getRandomValues(buf)
    n = buf[0]
  } while (n >= limit)
  return (n % 1_000_000).toString().padStart(6, '0')
}

async function hashBetaCode(code: string): Promise<string> {
  const data = new TextEncoder().encode(code)
  const digest = await crypto.subtle.digest('SHA-256', data)
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('')
}
```

- [ ] **Step 2: Wire code into the insert**

Replace lines 71–94 (the Supabase insert block) with:

```ts
  // Step 5 — Generate code, insert row.
  const plaintextCode = generateBetaCode()
  const codeHash = await hashBetaCode(plaintextCode)
  const generatedAt = new Date().toISOString()
  const expiresAt = new Date(Date.now() + CODE_TTL_MS).toISOString()

  try {
    const { error: dbError } = await getSupabaseClient()
      .from('waitlist_subscribers')
      .insert({
        email,
        ip_hash: ipHash,
        user_agent: userAgent,
        referrer,
        invite_token: invite_token ?? null,
        code_hash: codeHash,
        code_generated_at: generatedAt,
        code_expires_at: expiresAt,
      })

    if (dbError) {
      if (dbError.code === '23505') {
        return {
          status: 'duplicate',
          message: "You're already on the list. We'll be in touch soon.",
        }
      }
      console.error('[subscribe] DB insert error:', dbError)
      return {
        status: 'error',
        message: 'Something went wrong. Please try again in a moment.',
      }
    }
  } catch (err) {
    console.error('[subscribe] Unexpected DB error:', err)
    return {
      status: 'error',
      message: 'Something went wrong. Please try again in a moment.',
    }
  }
```

- [ ] **Step 3: Pass code to email builder**

Replace the `getResendClient().emails.send(...)` call (lines 105–111) with:

```ts
    getResendClient().emails
      .send({
        from: process.env.RESEND_FROM_ADDRESS ?? 'hello@lumoria.com',
        to: email,
        subject: 'Your spot is saved.',
        html: buildEmailHtml(plaintextCode),
      })
      .catch((err: unknown) => {
        console.error('[subscribe] Resend send error:', err)
      })
```

- [ ] **Step 4: Update `buildEmailHtml` to accept and render the code**

Replace the entire `buildEmailHtml` function (lines 124–199) with:

```ts
function buildEmailHtml(code: string): string {
  const appUrl = process.env.NEXT_PUBLIC_APP_URL ?? 'https://lumoria.com'

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Your spot is saved.</title>
</head>
<body style="margin:0;padding:0;background:#ffffff;font-family:Georgia,'Times New Roman',serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#ffffff;">
    <tr>
      <td align="center" style="padding:64px 24px;">
        <table width="560" cellpadding="0" cellspacing="0" style="max-width:560px;width:100%;">

          <tr>
            <td style="padding-bottom:48px;">
              <span style="font-family:Georgia,serif;font-size:18px;font-weight:600;letter-spacing:0.06em;color:#000000;text-transform:uppercase;">Lumoria</span>
            </td>
          </tr>

          <tr>
            <td style="padding-bottom:24px;">
              <h1 style="margin:0;font-family:Georgia,serif;font-size:34px;font-weight:600;line-height:1.2;color:#000000;letter-spacing:-0.01em;">Your spot is saved.</h1>
            </td>
          </tr>

          <tr>
            <td style="padding-bottom:32px;">
              <p style="margin:0 0 16px;font-family:Georgia,serif;font-size:17px;line-height:1.65;color:#404040;">
                You're now on the Lumoria beta list. Sign up in the app with this email to be recognized automatically — or enter the code below if your email differs (e.g. when using Sign in with Apple's private relay).
              </p>
            </td>
          </tr>

          <tr>
            <td align="center" style="padding-bottom:32px;">
              <div style="font-family:'SF Mono',Menlo,Consolas,monospace;font-size:42px;font-weight:600;letter-spacing:0.4em;color:#000000;padding:24px 32px;background:#f5f5f5;border-radius:12px;display:inline-block;">${code}</div>
              <p style="margin:12px 0 0;font-family:Georgia,serif;font-size:14px;color:#737373;">Code expires in 30 days. Tap "Resend code" in the app for a fresh one.</p>
            </td>
          </tr>

          <tr>
            <td style="border-top:1px solid #e5e5e5;padding-top:32px;">
              <p style="margin:0;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;font-size:13px;line-height:1.6;color:#737373;">
                You received this because you signed up at
                <a href="${appUrl}" style="color:#737373;">${appUrl.replace('https://', '')}</a>.
                We will never sell or share your email address.<br />
                <a href="${appUrl}/privacy" style="color:#737373;text-decoration:underline;">Privacy policy</a>
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>`
}
```

- [ ] **Step 5: Manual test against staging**

Sign up a fresh email on the staging site. Verify:
- Email arrives with a 6-digit code rendered.
- DB row has non-null `code_hash`, `code_expires_at` ≈ +30d, `code_generated_at` ≈ now.

- [ ] **Step 6: Commit**

```bash
git add lumoria/src/app/actions/subscribe.ts
git commit -m "feat(waitlist): generate 6-digit code + include in confirmation email"
```

---

## Phase 4: iOS — auto-link RPC + AuthManager methods

### Task 7: Wire `link_beta_by_email` into AuthManager

**Files:**
- Modify: `Lumoria App/views/authentication/AuthManager.swift`

- [ ] **Step 1: Add the auto-link method**

Open `Lumoria App/views/authentication/AuthManager.swift`. Above `checkBetaStatus()` (currently at line 104), add:

```swift
    /// Asks Postgres to link the calling auth user to a waitlist row whose
    /// email matches `auth.users.email` exactly. Idempotent: returns false
    /// when there is no match or the row is already linked.
    @discardableResult
    private func autoLinkBetaByEmail() async -> Bool {
        do {
            let linked: Bool = try await supabase
                .rpc("link_beta_by_email")
                .execute()
                .value
            return linked
        } catch {
            print("[AuthManager] auto-link failed: \(error)")
            return false
        }
    }
```

- [ ] **Step 2: Call it before `checkBetaStatus()` on signed-in/initialSession**

In `listenForAuthChanges()`, replace both `await checkBetaStatus()` calls (currently at lines 47 and 63) with:

```swift
                    await autoLinkBetaByEmail()
                    await checkBetaStatus()
```

- [ ] **Step 3: Add public methods for code redemption + resend**

At the end of the `AuthManager` class (after `checkBetaStatus()` closes, before line 118), add:

```swift
    enum BetaRedemptionOutcome: String, Decodable {
        case ok
        case rateLimited = "rate_limited"
        case notFound = "not_found"
        case expired
        case wrongCode = "wrong_code"
        case alreadyClaimed = "already_claimed"
    }

    enum BetaRedemptionError: Error {
        case network
        case server(String)
    }

    /// Calls `verify-beta-code` edge function. On success, refreshes
    /// `isBetaSubscriber` so the UI updates immediately.
    func redeemBetaCode(email: String, code: String) async throws -> BetaRedemptionOutcome {
        struct Body: Encodable { let email: String; let code: String }
        struct Resp: Decodable { let outcome: BetaRedemptionOutcome }

        do {
            let resp: Resp = try await supabase.functions.invoke(
                "verify-beta-code",
                options: .init(body: Body(email: email, code: code))
            )
            if resp.outcome == .ok {
                await checkBetaStatus()
            }
            return resp.outcome
        } catch {
            throw BetaRedemptionError.network
        }
    }

    /// Calls `resend-beta-code` edge function. Silent success on the server
    /// side (no membership confirmation), so we always return without
    /// surfacing whether the email is on the waitlist.
    func resendBetaCode(email: String) async {
        struct Body: Encodable { let email: String }
        struct Resp: Decodable { let ok: Bool? }
        do {
            let _: Resp = try await supabase.functions.invoke(
                "resend-beta-code",
                options: .init(body: Body(email: email))
            )
        } catch {
            print("[AuthManager] resend-beta-code failed: \(error)")
        }
    }
```

- [ ] **Step 4: Build + run**

Run: build target `Lumoria App` in Xcode (or `xcodebuild -scheme "Lumoria App" build`).
Expected: clean compile.

- [ ] **Step 5: Manual smoke test against staging**

Sign in with a test account whose `auth.users.email` matches a `waitlist_subscribers.email`. Verify in Xcode logs that no error is printed and `isBetaSubscriber` becomes true.

- [ ] **Step 6: Commit**

```bash
git add "Lumoria App/views/authentication/AuthManager.swift"
git commit -m "feat(auth): auto-link beta by email + redeem/resend code methods"
```

---

## Phase 5: iOS — code input component

### Task 8: `LumoriaCodeInput` component + tests

**Files:**
- Create: `Lumoria App/components/LumoriaCodeInput.swift`
- Create: `Lumoria App/tests/components/LumoriaCodeInputTests.swift`

(Place test in whatever Swift Testing target the project already uses. If no test target exists yet, skip Step 1–2 and write the component only — note this in the commit and create a follow-up to add a test target.)

- [ ] **Step 1: Write the failing test**

```swift
// LumoriaCodeInputTests.swift
import Testing
@testable import Lumoria_App

@Suite("LumoriaCodeInput sanitization")
struct LumoriaCodeInputSanitizationTests {
    @Test("strips non-digits")
    func stripsNonDigits() {
        #expect(LumoriaCodeInput.sanitize("12a3-4 5b6") == "123456")
    }

    @Test("clamps to 6 digits")
    func clampsToSix() {
        #expect(LumoriaCodeInput.sanitize("12345678") == "123456")
    }

    @Test("empty input stays empty")
    func empty() {
        #expect(LumoriaCodeInput.sanitize("") == "")
    }

    @Test("isComplete only when 6 digits")
    func isCompleteOnly6() {
        #expect(LumoriaCodeInput.isComplete("12345") == false)
        #expect(LumoriaCodeInput.isComplete("123456") == true)
        #expect(LumoriaCodeInput.isComplete("1234567") == false)
    }
}
```

- [ ] **Step 2: Run test, expect failure**

Run the test target. Expected: FAIL — types/methods undefined.

- [ ] **Step 3: Implement the component**

```swift
//
//  LumoriaCodeInput.swift
//  Lumoria App
//

import SwiftUI

struct LumoriaCodeInput: View {
    @Binding var code: String
    var onComplete: ((String) -> Void)? = nil

    @FocusState private var focused: Bool
    private let length = 6

    var body: some View {
        ZStack {
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focused)
                .opacity(0.001)
                .frame(maxWidth: .infinity, maxHeight: 64)
                .onChange(of: code) { _, new in
                    let cleaned = Self.sanitize(new)
                    if cleaned != new { code = cleaned }
                    if Self.isComplete(cleaned) { onComplete?(cleaned) }
                }

            HStack(spacing: 10) {
                ForEach(0..<length, id: \.self) { i in
                    digitCell(at: i)
                }
            }
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
        .onAppear { focused = true }
    }

    private func digitCell(at index: Int) -> some View {
        let chars = Array(code)
        let char: Character? = index < chars.count ? chars[index] : nil
        let isCursor = index == chars.count && focused

        return Text(char.map { String($0) } ?? "")
            .font(.system(size: 28, weight: .semibold, design: .monospaced))
            .frame(width: 44, height: 56)
            .background(Color(.systemGray6))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isCursor ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    static func sanitize(_ raw: String) -> String {
        let digits = raw.filter { $0.isNumber }
        return String(digits.prefix(6))
    }

    static func isComplete(_ value: String) -> Bool {
        value.count == 6 && value.allSatisfy { $0.isNumber }
    }
}

#Preview {
    @Previewable @State var code = ""
    return LumoriaCodeInput(code: $code)
        .padding()
}
```

- [ ] **Step 4: Run tests, expect pass**

Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add "Lumoria App/components/LumoriaCodeInput.swift" \
        "Lumoria App/tests/components/LumoriaCodeInputTests.swift"
git commit -m "feat(components): LumoriaCodeInput 6-digit OTP-style field"
```

---

## Phase 6: iOS — redemption screen

### Task 9: `BetaCodeRedemptionView`

**Files:**
- Create: `Lumoria App/views/authentication/BetaCodeRedemptionView.swift`

- [ ] **Step 1: Write the view**

```swift
//
//  BetaCodeRedemptionView.swift
//  Lumoria App
//

import SwiftUI

struct BetaCodeRedemptionView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var email: String = ""
    @State private var code: String = ""
    @State private var isVerifying = false
    @State private var isResending = false
    @State private var resendCooldownUntil: Date? = nil
    @State private var statusMessage: String? = nil
    @State private var statusIsError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Enter your beta code")
                    .font(.title2.weight(.semibold))
                Text("Use the email you signed up with on lumoria.com and the 6-digit code we sent.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Email").font(.caption).foregroundStyle(.secondary)
                TextField("you@example.com", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Code").font(.caption).foregroundStyle(.secondary)
                LumoriaCodeInput(code: $code, onComplete: { _ in
                    Task { await verify() }
                })
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(statusIsError ? .red : .green)
            }

            Button(action: { Task { await verify() } }) {
                if isVerifying {
                    ProgressView().tint(Color.Text.OnColor.white)
                } else {
                    Text("Verify code")
                }
            }
            .lumoriaButtonStyle(.primary, size: .large)
            .disabled(isVerifying || !LumoriaCodeInput.isComplete(code) || !isValidEmail)

            Button(action: { Task { await resend() } }) {
                Text(resendButtonLabel)
                    .font(.subheadline)
                    .foregroundStyle(canResend ? Color.accentColor : .secondary)
            }
            .disabled(!canResend || !isValidEmail)

            Spacer()
        }
        .padding(24)
    }

    private var isValidEmail: Bool {
        let pattern = #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    private var canResend: Bool {
        guard !isResending else { return false }
        guard let until = resendCooldownUntil else { return true }
        return Date() >= until
    }

    private var resendButtonLabel: String {
        if isResending { return "Sending…" }
        if let until = resendCooldownUntil, Date() < until {
            let secs = Int(until.timeIntervalSinceNow)
            return "Resend in \(secs)s"
        }
        return "Send a new code"
    }

    private func verify() async {
        statusMessage = nil
        isVerifying = true
        defer { isVerifying = false }

        do {
            let outcome = try await auth.redeemBetaCode(email: email.trimmingCharacters(in: .whitespaces), code: code)
            switch outcome {
            case .ok:
                statusIsError = false
                statusMessage = "Beta access unlocked."
                try? await Task.sleep(for: .seconds(0.6))
                dismiss()
            case .wrongCode:
                statusIsError = true
                statusMessage = "That code doesn't match. Double-check and try again."
                code = ""
            case .expired:
                statusIsError = true
                statusMessage = "That code expired. Tap 'Send a new code'."
            case .rateLimited:
                statusIsError = true
                statusMessage = "Too many tries today. Try again tomorrow."
            case .notFound:
                statusIsError = true
                statusMessage = "We don't see that email on the waitlist."
            case .alreadyClaimed:
                statusIsError = true
                statusMessage = "That email is already linked to another account."
            }
        } catch {
            statusIsError = true
            statusMessage = "Network error. Please try again."
        }
    }

    private func resend() async {
        isResending = true
        defer { isResending = false }
        await auth.resendBetaCode(email: email.trimmingCharacters(in: .whitespaces))
        // Server-side cooldown is 1 hour; mirror with a 60-minute UI lockout.
        resendCooldownUntil = Date().addingTimeInterval(60 * 60)
        statusIsError = false
        statusMessage = "If that email is on the waitlist, a new code is on the way."
    }
}

#Preview {
    BetaCodeRedemptionView()
        .environmentObject(AuthManager())
}
```

- [ ] **Step 2: Build**

Expected: clean compile.

- [ ] **Step 3: Commit**

```bash
git add "Lumoria App/views/authentication/BetaCodeRedemptionView.swift"
git commit -m "feat(auth): BetaCodeRedemptionView with verify + resend flow"
```

### Task 10: Slot redemption screen into onboarding

**Files:**
- Modify: `Lumoria App/views/onboarding/OnboardingCoordinator.swift`

This task is deliberately small: present `BetaCodeRedemptionView` once, automatically, when `isAuthenticated && !isBetaSubscriber` after sign-in. Inspect the existing coordinator to find the cleanest insertion point — likely a new `case .redeemBeta` in its sheet enum, surfaced before any tutorial.

- [ ] **Step 1: Read the coordinator**

Open `Lumoria App/views/onboarding/OnboardingCoordinator.swift`. Identify:
- The current sheet/state enum.
- Where it decides what to show on first authenticated launch.

- [ ] **Step 2: Add a `redeemBeta` step ahead of the welcome tutorial**

Add a case to the coordinator's step enum (e.g. `case redeemBeta`) and a guard that surfaces it when `auth.isAuthenticated && !auth.isBetaSubscriber`. On dismissal of `BetaCodeRedemptionView`, advance to the next existing step regardless of outcome (users who skip without redeeming still get the welcome flow; the same coordinator will re-trigger on subsequent launches until `isBetaSubscriber` flips true).

Actual edit shape (illustrative — adapt to the file):

```swift
// Inside whatever the coordinator's resolution logic is:
if auth.isAuthenticated && !auth.isBetaSubscriber {
    return .redeemBeta
}
// existing logic...
```

And in the view that renders the coordinator:

```swift
case .redeemBeta:
    BetaCodeRedemptionView()
```

- [ ] **Step 3: Build + manually test**

Sign in with a test account whose email does NOT match any waitlist row. Expected: redemption screen appears post-signin. Enter a known-good code → screen dismisses, `isBetaSubscriber` becomes true, normal onboarding resumes.

Sign in with a test account whose email DOES match a waitlist row. Expected: auto-link runs first, `isBetaSubscriber` is true before the coordinator evaluates → redemption screen never appears.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/views/onboarding/OnboardingCoordinator.swift"
git commit -m "feat(onboarding): show beta code redemption when user not yet linked"
```

---

## Phase 7: Changelog + verification

### Task 11: Changelog entry

**Files:**
- Create: `lumoria/src/content/changelog/2026-04-27-beta-code-reconciliation.mdx`

(Per project memory: every shipped change adds an MDX entry to `lumoria/src/content/changelog/` with JS-export frontmatter, not YAML.)

- [ ] **Step 1: Write the entry**

Inspect a recent file under `lumoria/src/content/changelog/` for the exact frontmatter shape, then write a concise entry covering: 6-digit code now sent at signup, redemption screen surfaces in-app for email-mismatch cases, 30-day expiry, resend supported.

- [ ] **Step 2: Commit**

```bash
git add lumoria/src/content/changelog/2026-04-27-beta-code-reconciliation.mdx
git commit -m "docs(changelog): beta code reconciliation"
```

### Task 12: End-to-end verification

- [ ] **Step 1: Fresh-signup happy path**

Sign up a new email at staging website → confirm code arrives → install app on a clean simulator → sign up with the SAME email + password → verify auto-link sets `isBetaSubscriber` (redemption screen never appears).

- [ ] **Step 2: Email-mismatch path**

Sign up new email at staging → confirm code arrives → in app, sign up with a DIFFERENT email → redemption screen appears → enter waitlist email + code → screen dismisses, beta unlocked.

- [ ] **Step 3: Wrong-code path**

Repeat Step 2 but enter a wrong code → red error, code field clears. Try again → "Too many tries today" (rate limit).

- [ ] **Step 4: Expired-code path**

Manually update a waitlist row in staging: `update waitlist_subscribers set code_expires_at = now() - interval '1 day' where email = '...'`. In-app verification → "expired", offer resend → tap resend → new email arrives → enter new code → success.

- [ ] **Step 5: Already-claimed path**

Take a row already linked to user A. Sign in as user B, attempt redemption with that email + code → "already linked to another account."

- [ ] **Step 6: Verify RLS**

In a SQL console with a non-service-role JWT, attempt:
```sql
select code_hash from waitlist_subscribers limit 1;
select * from beta_redemption_attempts limit 1;
```
Expected: both deny / return zero rows.

---

## Self-review checklist (run before handoff)

- [x] Spec covers: code generation, hashing, email delivery, expiry, auto-link by email, code redemption, rate limit (1/24h per auth user), code resend (1/h per email), 30-day TTL, RLS on hash + attempts table.
- [x] No "TODO" or "implement appropriately" placeholders.
- [x] Type names consistent: `BetaRedemptionOutcome` (Swift) ↔ `Outcome` (TS) with snake_case strings (`rate_limited`, `wrong_code`, `not_found`, `already_claimed`).
- [x] Migration filenames are absolute paths and follow the project's `YYYYMMDDHHMMSS_*.sql` convention.
- [x] All file paths quote the space in "Lumoria App".
- [x] Tests added for: code helpers (Deno), `decide()` outcomes (Deno), `LumoriaCodeInput.sanitize` (Swift Testing).
- [x] Changelog entry per project memory.
