-- Device tokens + APNs wiring.
--
-- On top of the in-app notifications feed added in the previous
-- migration, this layer pushes a banner via APNs every time a new row
-- lands in `public.notifications`. Delivery is best-effort — a failed
-- push never blocks the insert, because the client still shows the row
-- on its next fetch.
--
-- Flow:
--   * iOS registers for push → uploads the hex device token to
--     `public.device_tokens`.
--   * Any time a row is inserted into `public.notifications`
--     (by cron, trigger, or `broadcast_news`), an AFTER trigger fires
--     `pg_net.http_post` to the `send-push` edge function.
--   * The edge function looks up every `device_tokens` row for
--     `notifications.user_id`, signs an APNs JWT, and sends one HTTP/2
--     POST per token. A 410 response means the token is stale and the
--     function deletes it.
--
-- Apply with `supabase db push`, then from the dashboard:
--   * Database → Extensions → enable `pg_net` (if not already on)
--   * Edge Functions → set the secrets listed in the
--     `app.send_push_function_url` comment block below
--   * Edge Functions → deploy `send-push`
--
-- APNs env:
--   * TestFlight + App Store use `api.push.apple.com` (production)
--   * Xcode debug builds can use `api.sandbox.push.apple.com` if you set
--     `aps-environment = development` in the entitlements
--   The edge function reads `APNS_ENV` (`production` | `sandbox`) and
--   picks accordingly.

-- ---------------------------------------------------------------------------
-- 1. pg_net — enable if missing (idempotent)
-- ---------------------------------------------------------------------------
create extension if not exists pg_net with schema extensions;

-- ---------------------------------------------------------------------------
-- 2. device_tokens: one row per (user, device)
-- ---------------------------------------------------------------------------
create table if not exists public.device_tokens (
    token         text         primary key,
    user_id       uuid         not null references auth.users(id) on delete cascade,
    platform      text         not null default 'ios' check (platform in ('ios')),
    environment   text         not null default 'production' check (environment in ('production','sandbox')),
    created_at    timestamptz  not null default now(),
    last_seen_at  timestamptz  not null default now()
);

comment on table public.device_tokens is
  'APNs device tokens uploaded by signed-in clients. Used by the send-push edge function to fan out pushes.';

create index if not exists device_tokens_user_id_idx
  on public.device_tokens(user_id);

alter table public.device_tokens enable row level security;

drop policy if exists "device_tokens owner select" on public.device_tokens;
create policy "device_tokens owner select" on public.device_tokens
  for select using (auth.uid() = user_id);

drop policy if exists "device_tokens owner insert" on public.device_tokens;
create policy "device_tokens owner insert" on public.device_tokens
  for insert with check (auth.uid() = user_id);

drop policy if exists "device_tokens owner update" on public.device_tokens;
create policy "device_tokens owner update" on public.device_tokens
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "device_tokens owner delete" on public.device_tokens;
create policy "device_tokens owner delete" on public.device_tokens
  for delete using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 3. Link trigger — now wired to the real `invites` schema
-- ---------------------------------------------------------------------------
-- Replaces the placeholder from 20260422. When a user creates their
-- first ticket, find the invite they claimed and notify the inviter.
-- Also stamps `invites.redeemed_at` so the inviter's own invite tile
-- shows the "redeemed" state.
create or replace function public.fire_link_on_first_ticket()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    is_first_ticket boolean;
    v_inviter_id uuid;
    v_invite_id uuid;
begin
    select not exists (
        select 1
        from public.tickets t
        where t.user_id = new.user_id and t.id <> new.id
    )
    into is_first_ticket;

    if not is_first_ticket then
        return new;
    end if;

    select i.id, i.inviter_id
      into v_invite_id, v_inviter_id
      from public.invites i
     where i.claimed_by = new.user_id
       and i.redeemed_at is null
       and i.revoked_at is null
     order by i.claimed_at desc nulls last
     limit 1;

    if v_inviter_id is null then
        return new;
    end if;

    update public.invites
       set redeemed_at = now()
     where id = v_invite_id;

    insert into public.notifications (user_id, kind, title, message)
    values (
        v_inviter_id,
        'link',
        'Your friend is in!',
        'Your link has been redeemed. A new collection slot is ready for you.'
    );

    return new;
end;
$$;

-- Trigger was created in the previous migration; the CREATE OR REPLACE
-- above updates the function behind it in place.

-- ---------------------------------------------------------------------------
-- 4. Fan-out trigger on `public.notifications` → edge function
-- ---------------------------------------------------------------------------
-- The edge function URL + service-role key are read from the app
-- settings namespace. Set them via:
--
--   alter database postgres
--     set app.send_push_function_url = 'https://<PROJECT_REF>.supabase.co/functions/v1/send-push';
--   alter database postgres
--     set app.service_role_key = '<SERVICE_ROLE_KEY>';
--
-- (One time per project. `<PROJECT_REF>` is the subdomain of your
-- Supabase URL; `<SERVICE_ROLE_KEY>` is from Project Settings → API.)
create or replace function public.notifications_fanout_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    fn_url   text;
    sr_key   text;
    payload  jsonb;
begin
    -- Best-effort. If config is missing the push is skipped; the
    -- notification still shows up in the app on next fetch.
    fn_url := current_setting('app.send_push_function_url', true);
    sr_key := current_setting('app.service_role_key', true);
    if fn_url is null or sr_key is null then
        return new;
    end if;

    payload := jsonb_build_object('notification_id', new.id);

    perform
        net.http_post(
            url     := fn_url,
            headers := jsonb_build_object(
                'Content-Type',  'application/json',
                'Authorization', 'Bearer ' || sr_key
            ),
            body    := payload
        );

    return new;
end;
$$;

drop trigger if exists notifications_fanout_push on public.notifications;
create trigger notifications_fanout_push
after insert on public.notifications
for each row execute function public.notifications_fanout_push();

comment on function public.notifications_fanout_push() is
  'Calls the send-push edge function whenever a notification is inserted. Best-effort — missing config skips the call without raising.';
