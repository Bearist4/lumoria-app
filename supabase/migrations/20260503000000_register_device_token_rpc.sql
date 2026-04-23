-- RPC to register an APNs device token against the caller.
--
-- Background: `device_tokens.token` is the primary key. When a device
-- changes hands between users (sign-out → sign-in on the same sim, or
-- a shared dev device), the existing row is owned by the previous
-- user_id. A plain `upsert(onConflict: "token")` then runs the UPDATE
-- policy's USING clause — `auth.uid() = user_id` on the EXISTING row —
-- which fails with 42501 ("violates row-level security policy (USING
-- expression)") because the row belongs to someone else.
--
-- Fix: a `security definer` function that takes a token, stamps
-- `user_id = auth.uid()` on conflict, and is `execute`-granted only to
-- authenticated callers. Ordinary select/update policies stay strict;
-- this single function is the blessed path for re-assigning a token.
--
-- Apply with `supabase db push` or paste into Supabase Studio →
-- SQL Editor.

create or replace function public.register_device_token(
    p_token       text,
    p_environment text default 'production',
    p_platform    text default 'ios'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_uid uuid := auth.uid();
begin
    if v_uid is null then
        raise exception 'register_device_token: not authenticated'
            using errcode = '28000';
    end if;
    if p_environment not in ('production', 'sandbox') then
        raise exception 'register_device_token: invalid environment %', p_environment
            using errcode = '22023';
    end if;
    if p_platform not in ('ios') then
        raise exception 'register_device_token: invalid platform %', p_platform
            using errcode = '22023';
    end if;

    insert into public.device_tokens
        (token, user_id, platform, environment, last_seen_at)
    values
        (p_token, v_uid, p_platform, p_environment, now())
    on conflict (token) do update
        set user_id      = excluded.user_id,
            platform     = excluded.platform,
            environment  = excluded.environment,
            last_seen_at = excluded.last_seen_at;
end;
$$;

revoke all on function public.register_device_token(text, text, text) from public;
grant execute on function public.register_device_token(text, text, text) to authenticated;

comment on function public.register_device_token(text, text, text) is
  'Blessed path for clients to (re)register their APNs device token. Runs SECURITY DEFINER so a token that currently belongs to another user can be re-owned by the caller — ordinary UPDATE on device_tokens is still blocked by RLS.';
