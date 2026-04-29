-- 20260510000001_beta_helpers.sql
-- Postgres helpers for beta reconciliation. Both run security definer so
-- the calling user can invoke them without write access to the table.

-- 1. Auto-link by exact email match. Returns true if a row was linked.
--    Idempotent: returns false when no match or row already linked.
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

-- 2. Count attempts in the trailing window (default 24h) for the calling
--    user. Used by edge functions before processing a redemption.
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
