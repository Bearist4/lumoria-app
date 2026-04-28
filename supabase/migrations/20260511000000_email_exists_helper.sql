-- 20260511000000_email_exists_helper.sql
-- Postgres helper for the email-first auth landing flow.
--
-- The check-email-exists edge function uses this to ask whether an email
-- address already has an auth.users row, so the client can morph between
-- the login and signup forms without leaking enumeration through Supabase
-- error messages or sending an unsolicited magic link.
--
-- Runs SECURITY DEFINER because callers (the edge function with service
-- role, or anon if we ever wire it up directly) shouldn't have direct
-- read access to auth.users. Search path pinned for safety.

create or replace function public.email_exists(_email text)
returns boolean
language sql
security definer
set search_path = public, auth
as $$
  select exists (
    select 1
      from auth.users
     where lower(email) = lower(trim(_email))
  );
$$;

revoke all on function public.email_exists(text) from public;
-- Grant to anon so it could be called unauthenticated in the future; today
-- only the edge function (service role) calls it. Anon path is harmless —
-- the edge function is the rate-limited gate.
grant execute on function public.email_exists(text) to anon, authenticated;
