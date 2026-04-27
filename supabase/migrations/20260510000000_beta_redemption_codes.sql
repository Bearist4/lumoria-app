-- 20260510000000_beta_redemption_codes.sql
-- Adds 6-digit redemption code support for the beta waitlist.
--
-- Design notes:
--  * Plaintext codes are never stored; we keep SHA-256 hex of the code.
--  * Codes expire after 30 days (set by the issuer on insert/update).
--  * Existing rows keep working with NULL code fields; auto-link by email
--    handles them when the user's auth email matches.

-- 1. Code columns on waitlist_subscribers.
alter table public.waitlist_subscribers
  add column if not exists code_hash text,
  add column if not exists code_expires_at timestamptz,
  add column if not exists code_generated_at timestamptz;

create index if not exists waitlist_subscribers_email_lower_idx
  on public.waitlist_subscribers (lower(email));

comment on column public.waitlist_subscribers.code_hash is
  'SHA-256 hex of plaintext 6-digit code. Never expose to clients.';

-- 2. Defense in depth: column-level revoke on the new secret-bearing
--    columns so they cannot be selected by clients regardless of any
--    existing row-level policy on the table. Edge functions use the
--    service role and bypass column grants.
revoke select (code_hash, code_expires_at, code_generated_at)
  on public.waitlist_subscribers from anon, authenticated;

-- 3. Per-attempt log for rate limiting and audit.
create table if not exists public.beta_redemption_attempts (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null references auth.users(id) on delete cascade,
  email_attempted text not null,
  success boolean not null,
  attempted_at timestamptz not null default now()
);

create index if not exists beta_redemption_attempts_user_time_idx
  on public.beta_redemption_attempts (auth_user_id, attempted_at desc);

-- 4. RLS: clients have no direct access. Edge functions use the service
--    role which bypasses RLS.
alter table public.beta_redemption_attempts enable row level security;
-- (intentionally no policies = deny by default)
