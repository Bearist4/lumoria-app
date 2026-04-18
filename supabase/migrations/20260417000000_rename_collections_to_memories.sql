-- Rename Collections → Memories, drop collection-level location, add emoji.
--
-- Background: location now lives on individual tickets (future migration),
-- so the per-collection location_enc column is removed. Collections are
-- renamed to "memories" to better match their user-facing meaning.
-- An optional emoji_enc column is added so users can personalize a memory
-- alongside its color.
--
-- Apply with `supabase db push` or paste into Supabase Studio → SQL Editor.
--
-- Rename is data-preserving: existing rows survive. Constraint + primary-key
-- names keep their old prefix (cosmetic only, does not affect behavior).

-- ---------------------------------------------------------------------------
-- 1. Drop policies, triggers, and indexes that reference the old names
-- ---------------------------------------------------------------------------
drop policy if exists "collections_select_own"          on public.collections;
drop policy if exists "collections_insert_own"          on public.collections;
drop policy if exists "collections_update_own"          on public.collections;
drop policy if exists "collections_delete_own"          on public.collections;
drop policy if exists "collection_tickets owner select" on public.collection_tickets;
drop policy if exists "collection_tickets owner insert" on public.collection_tickets;
drop policy if exists "collection_tickets owner delete" on public.collection_tickets;

drop trigger if exists collections_set_updated_at on public.collections;

drop index if exists public.collections_user_id_created_at_idx;
drop index if exists public.collection_tickets_ticket_id_idx;
drop index if exists public.collection_tickets_collection_id_idx;

-- ---------------------------------------------------------------------------
-- 2. Column changes on the old collections table
-- ---------------------------------------------------------------------------
alter table public.collections drop column if exists location_enc;

alter table public.collections
    add column if not exists emoji_enc text;

comment on column public.collections.emoji_enc is
  'Base64 AES-GCM-256 ciphertext of the user-picked emoji, nullable.';

-- ---------------------------------------------------------------------------
-- 3. Rename tables + junction column
-- ---------------------------------------------------------------------------
alter table public.collections       rename to memories;
alter table public.collection_tickets rename to memory_tickets;
alter table public.memory_tickets    rename column collection_id to memory_id;

comment on table public.memories is
  'A user-created memory that groups tickets. Owned by auth.users.';

-- ---------------------------------------------------------------------------
-- 4. Recreate indexes with the new names
-- ---------------------------------------------------------------------------
create index if not exists memories_user_id_created_at_idx
    on public.memories (user_id, created_at desc);

create index if not exists memory_tickets_ticket_id_idx
    on public.memory_tickets (ticket_id);

create index if not exists memory_tickets_memory_id_idx
    on public.memory_tickets (memory_id);

-- ---------------------------------------------------------------------------
-- 5. Recreate the updated_at trigger (shared set_updated_at() still exists)
-- ---------------------------------------------------------------------------
create trigger memories_set_updated_at
    before update on public.memories
    for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 6. Recreate RLS policies with the new names
-- ---------------------------------------------------------------------------
alter table public.memories       enable row level security;
alter table public.memory_tickets enable row level security;

create policy "memories_select_own" on public.memories
    for select using (auth.uid() = user_id);

create policy "memories_insert_own" on public.memories
    for insert with check (auth.uid() = user_id);

create policy "memories_update_own" on public.memories
    for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "memories_delete_own" on public.memories
    for delete using (auth.uid() = user_id);

-- junction: caller must own BOTH the ticket and the memory
create policy "memory_tickets owner select" on public.memory_tickets
    for select using (
      exists (select 1 from public.tickets  t where t.id = ticket_id and t.user_id = auth.uid())
      and
      exists (select 1 from public.memories m where m.id = memory_id and m.user_id = auth.uid())
    );

create policy "memory_tickets owner insert" on public.memory_tickets
    for insert with check (
      exists (select 1 from public.tickets  t where t.id = ticket_id and t.user_id = auth.uid())
      and
      exists (select 1 from public.memories m where m.id = memory_id and m.user_id = auth.uid())
    );

create policy "memory_tickets owner delete" on public.memory_tickets
    for delete using (
      exists (select 1 from public.tickets  t where t.id = ticket_id and t.user_id = auth.uid())
      and
      exists (select 1 from public.memories m where m.id = memory_id and m.user_id = auth.uid())
    );
