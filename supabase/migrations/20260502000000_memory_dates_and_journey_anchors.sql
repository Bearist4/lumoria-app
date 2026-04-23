-- Memory date range + journey anchors.
--
-- 1. Adds optional encrypted start/end date columns on `memories`. Stored as
--    base64 AES-GCM-256 ciphertext of an ISO-8601 date string. Matches the
--    privacy model used for `name` / `emoji_enc`.
--
-- 2. Creates `public.journey_anchors` — user-defined places that belong to a
--    memory but are not backed by a ticket (e.g. "Home — Paris", a hotel, a
--    connecting city). Mirrors `ticket_locations` encryption: a single
--    `payload_enc` column carries ciphertext JSON of `{name, lat, lng,
--    kind}`. `date_enc` positions the anchor on the memory's timeline and is
--    encrypted for consistency with other user-entered dates.
--
-- Apply with `supabase db push` or paste into Supabase Studio → SQL Editor.

-- ---------------------------------------------------------------------------
-- 1. Memory start / end date
-- ---------------------------------------------------------------------------
alter table public.memories
    add column if not exists start_date_enc text,
    add column if not exists end_date_enc   text;

comment on column public.memories.start_date_enc is
  'Base64 AES-GCM-256 ciphertext of the memory start date (ISO-8601), nullable.';

comment on column public.memories.end_date_enc is
  'Base64 AES-GCM-256 ciphertext of the memory end date (ISO-8601), nullable.';

-- ---------------------------------------------------------------------------
-- 2. Journey anchors
-- ---------------------------------------------------------------------------
create table if not exists public.journey_anchors (
    id          uuid primary key default gen_random_uuid(),
    user_id     uuid not null references auth.users (id) on delete cascade,
    memory_id   uuid not null references public.memories (id) on delete cascade,
    payload_enc text not null,
    date_enc    text not null,
    kind        text not null check (kind in ('start', 'end', 'waypoint')),
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now()
);

comment on table public.journey_anchors is
  'User-defined locations attached to a memory without a backing ticket.';
comment on column public.journey_anchors.payload_enc is
  'Base64 AES-GCM-256 ciphertext of {name, lat, lng} JSON.';
comment on column public.journey_anchors.date_enc is
  'Base64 AES-GCM-256 ciphertext of ISO-8601 date placing this anchor in the story sequence.';
comment on column public.journey_anchors.kind is
  'Role of this anchor in the journey: start, end, or waypoint.';

create index if not exists journey_anchors_memory_id_idx
    on public.journey_anchors (memory_id);
create index if not exists journey_anchors_user_id_idx
    on public.journey_anchors (user_id);

create trigger journey_anchors_set_updated_at
    before update on public.journey_anchors
    for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 3. RLS — owner-only, mirrors memories policies
-- ---------------------------------------------------------------------------
alter table public.journey_anchors enable row level security;

create policy "journey_anchors_select_own" on public.journey_anchors
    for select using (auth.uid() = user_id);

create policy "journey_anchors_insert_own" on public.journey_anchors
    for insert with check (
        auth.uid() = user_id
        and exists (
            select 1 from public.memories m
            where m.id = memory_id and m.user_id = auth.uid()
        )
    );

create policy "journey_anchors_update_own" on public.journey_anchors
    for update using (auth.uid() = user_id)
                 with check (auth.uid() = user_id);

create policy "journey_anchors_delete_own" on public.journey_anchors
    for delete using (auth.uid() = user_id);
