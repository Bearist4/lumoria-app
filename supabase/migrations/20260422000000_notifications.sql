-- Per-user in-app notifications feed.
--
-- Four kinds, different producers:
--
--   throwback   — fired by a daily cron. For every memory whose
--                 created_at is exactly one year old today, insert one
--                 throwback row for that memory's owner.
--   onboarding  — fired by a daily cron. Two flavours:
--                 (a) user signed up ≥ 1 day ago and has zero tickets,
--                 (b) a memory was created ≥ 1 day ago and still has
--                     zero tickets.
--   news        — broadcast by Lumoria staff. Use `public.broadcast_news`
--                 below — it fans out one row per user.
--   link        — fired by a trigger on `public.tickets` when the ticket
--                 is the owner's very first, AND the owner was invited
--                 by someone. Requires a future `invites` table — the
--                 trigger is a placeholder until that schema lands.
--
-- Nothing in this table is encrypted. Copy is authored by Lumoria (or
-- generated from non-sensitive timestamps). When a notification needs to
-- reference user content (e.g. "you were in Lake Tahoe"), store the
-- `memory_id` and let the client resolve the name client-side against
-- the decrypted memories cache.
--
-- Apply with `supabase db push` or paste into Supabase Studio → SQL Editor.

-- ---------------------------------------------------------------------------
-- 1. Table
-- ---------------------------------------------------------------------------
create table if not exists public.notifications (
    id             uuid         primary key default gen_random_uuid(),
    user_id        uuid         not null references auth.users(id) on delete cascade,
    kind           text         not null check (kind in
                       ('throwback','onboarding','news','link')),
    title          text         not null,
    message        text         not null,
    memory_id      uuid         references public.memories(id) on delete cascade,
    template_kind  text,
    created_at     timestamptz  not null default now(),
    read_at        timestamptz,
    dismissed_at   timestamptz
);

comment on table public.notifications is
  'Per-user in-app notifications. One row = one card in the notification center.';
comment on column public.notifications.kind is
  'Drives card colour and tap destination: throwback | onboarding | news | link.';
comment on column public.notifications.memory_id is
  'Optional pointer to a memory (for throwback / onboarding). Client resolves the display name locally.';
comment on column public.notifications.template_kind is
  'Optional pointer to a ticket template (for kind = news). Must match TicketTemplateKind raw values.';

create index if not exists notifications_user_created_at_idx
  on public.notifications(user_id, created_at desc);

create index if not exists notifications_user_unread_idx
  on public.notifications(user_id)
  where read_at is null and dismissed_at is null;

-- Prevent duplicate throwbacks / onboardings — the cron jobs below rely
-- on these partial unique indexes so they can be re-run idempotently.
create unique index if not exists notifications_unique_throwback_per_memory
  on public.notifications(user_id, memory_id)
  where kind = 'throwback' and memory_id is not null;

create unique index if not exists notifications_unique_onboarding_user
  on public.notifications(user_id)
  where kind = 'onboarding' and memory_id is null;

create unique index if not exists notifications_unique_onboarding_memory
  on public.notifications(user_id, memory_id)
  where kind = 'onboarding' and memory_id is not null;

-- ---------------------------------------------------------------------------
-- 2. Row-level security
-- ---------------------------------------------------------------------------
alter table public.notifications enable row level security;

-- Users only ever see their own rows. Inserts happen via SECURITY DEFINER
-- functions below (staff + crons), never from the client.
drop policy if exists "notifications owner select" on public.notifications;
create policy "notifications owner select" on public.notifications
  for select using (auth.uid() = user_id);

drop policy if exists "notifications owner update" on public.notifications;
create policy "notifications owner update" on public.notifications
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Clients must not insert or delete — all writes come from backend jobs.
-- (No insert/delete policies = all denied for non-service-role.)

-- ---------------------------------------------------------------------------
-- 3. News broadcast helper
-- ---------------------------------------------------------------------------
-- Call from the SQL editor when you want to announce something:
--
--   select public.broadcast_news(
--       'New templates just landed',
--       'Fresh designs are waiting. Go make something beautiful.',
--       'night'
--   );
--
-- Returns the number of rows inserted.
create or replace function public.broadcast_news(
    p_title         text,
    p_message       text,
    p_template_kind text default null
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    inserted_count integer;
begin
    insert into public.notifications (user_id, kind, title, message, template_kind)
    select u.id, 'news', p_title, p_message, p_template_kind
    from auth.users u;

    get diagnostics inserted_count = row_count;
    return inserted_count;
end;
$$;

comment on function public.broadcast_news(text, text, text) is
  'Fans out a news notification to every auth.users row. Manual — call from the SQL editor.';

-- ---------------------------------------------------------------------------
-- 4. Throwback cron
-- ---------------------------------------------------------------------------
-- Scans memories whose creation date matches "one year ago today" and
-- inserts one throwback per memory owner. Idempotent — the unique index
-- on (user_id, memory_id) where kind = 'throwback' prevents duplicates
-- if the job runs more than once in the same day.
create or replace function public.fire_throwbacks()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    inserted_count integer;
begin
    insert into public.notifications (user_id, kind, title, message, memory_id)
    select
        m.user_id,
        'throwback',
        'One year ago today',
        'Take a look back at this memory.',
        m.id
    from public.memories m
    where m.created_at::date = (now() - interval '1 year')::date
    on conflict do nothing;

    get diagnostics inserted_count = row_count;
    return inserted_count;
end;
$$;

comment on function public.fire_throwbacks() is
  'Insert throwback notifications for memories created exactly one year ago. Run daily via pg_cron.';

-- ---------------------------------------------------------------------------
-- 5. Onboarding cron
-- ---------------------------------------------------------------------------
-- Two flavours of onboarding nudge, both fire one day after the anchor
-- event IF the user still hasn't created a ticket in the relevant scope.
create or replace function public.fire_onboarding()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    inserted_count integer := 0;
    tmp integer;
begin
    -- (a) Account-level: signed up ≥ 1 day ago, still no tickets anywhere.
    insert into public.notifications (user_id, kind, title, message)
    select
        u.id,
        'onboarding',
        'Your first ticket is waiting',
        'Turn your next trip into something beautiful. It only takes a moment.'
    from auth.users u
    where u.created_at <= now() - interval '1 day'
      and not exists (
          select 1 from public.tickets t where t.user_id = u.id
      )
    on conflict do nothing;

    get diagnostics tmp = row_count;
    inserted_count := inserted_count + tmp;

    -- (b) Memory-level: memory created ≥ 1 day ago, still has zero tickets.
    insert into public.notifications (user_id, kind, title, message, memory_id)
    select
        m.user_id,
        'onboarding',
        'Your memory is waiting for its first ticket',
        'Add a ticket to bring this memory to life.',
        m.id
    from public.memories m
    where m.created_at <= now() - interval '1 day'
      and not exists (
          select 1
          from public.memory_tickets mt
          where mt.memory_id = m.id
      )
    on conflict do nothing;

    get diagnostics tmp = row_count;
    inserted_count := inserted_count + tmp;

    return inserted_count;
end;
$$;

comment on function public.fire_onboarding() is
  'Insert onboarding notifications for users/memories that have sat idle for a day. Run daily via pg_cron.';

-- ---------------------------------------------------------------------------
-- 6. Schedule the crons
-- ---------------------------------------------------------------------------
-- Requires the pg_cron extension, which is enabled from Dashboard →
-- Database → Extensions → search "pg_cron" → toggle on. The `cron`
-- schema only exists after the extension is installed.
--
-- Once it's on, run this block (commented out here because it fails if
-- pg_cron isn't enabled yet):
--
--   select cron.schedule(
--       'lumoria_fire_throwbacks',
--       '15 0 * * *',
--       $$ select public.fire_throwbacks(); $$
--   );
--   select cron.schedule(
--       'lumoria_fire_onboarding',
--       '30 0 * * *',
--       $$ select public.fire_onboarding(); $$
--   );

-- ---------------------------------------------------------------------------
-- 7. Link notification trigger (placeholder)
-- ---------------------------------------------------------------------------
-- Fires when a user creates their *first* ticket. If they were invited
-- by someone, the inviter gets the link notification. The `invites`
-- table doesn't exist yet — this trigger only fills in the inviter
-- lookup once that schema lands.
create or replace function public.fire_link_on_first_ticket()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    is_first_ticket boolean;
    inviter_id uuid;
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

    -- TODO: once the `invites` table exists, look up the inviter here:
    --
    --   select i.inviter_id
    --     into inviter_id
    --     from public.invites i
    --    where i.redeemed_user_id = new.user_id
    --    limit 1;
    --
    -- For now, no-op when the lookup yields nothing.
    inviter_id := null;

    if inviter_id is null then
        return new;
    end if;

    insert into public.notifications (user_id, kind, title, message)
    values (
        inviter_id,
        'link',
        'Your friend is in!',
        'Your link has been redeemed. A new collection slot is ready for you.'
    );

    return new;
end;
$$;

drop trigger if exists tickets_fire_link on public.tickets;
create trigger tickets_fire_link
after insert on public.tickets
for each row execute function public.fire_link_on_first_ticket();

comment on function public.fire_link_on_first_ticket() is
  'When a user creates their first ticket, notify the inviter. Requires an invites table — wire up the lookup once it exists.';
