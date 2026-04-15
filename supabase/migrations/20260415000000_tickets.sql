-- Tickets + collection membership.
-- Each user owns any number of tickets; a ticket can belong to zero, one,
-- or many collections, but never appears twice inside the same collection.

-- ---------------------------------------------------------------------------
-- Shared trigger: bump updated_at on UPDATE
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- tickets: one row per user-created ticket
-- ---------------------------------------------------------------------------
create table if not exists public.tickets (
    id             uuid         primary key default gen_random_uuid(),
    user_id        uuid         not null references auth.users(id) on delete cascade,
    template_kind  text         not null check (template_kind in
                       ('afterglow','studio','heritage','terminal','prism')),
    orientation    text         not null check (orientation in ('horizontal','vertical')),
    payload        jsonb        not null,
    created_at     timestamptz  not null default now(),
    updated_at     timestamptz  not null default now()
);

create index if not exists tickets_user_id_idx         on public.tickets(user_id);
create index if not exists tickets_user_created_at_idx on public.tickets(user_id, created_at desc);

drop trigger if exists tickets_set_updated_at on public.tickets;
create trigger tickets_set_updated_at
before update on public.tickets
for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- collection_tickets: junction. PK prevents duplicates inside a collection.
-- ---------------------------------------------------------------------------
create table if not exists public.collection_tickets (
    collection_id  uuid         not null references public.collections(id) on delete cascade,
    ticket_id      uuid         not null references public.tickets(id)     on delete cascade,
    added_at       timestamptz  not null default now(),
    primary key (collection_id, ticket_id)
);

create index if not exists collection_tickets_ticket_id_idx     on public.collection_tickets(ticket_id);
create index if not exists collection_tickets_collection_id_idx on public.collection_tickets(collection_id);

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------
alter table public.tickets             enable row level security;
alter table public.collection_tickets  enable row level security;

-- tickets: only the owner can read/write their rows
drop policy if exists "tickets owner select" on public.tickets;
create policy "tickets owner select" on public.tickets
  for select using (auth.uid() = user_id);

drop policy if exists "tickets owner insert" on public.tickets;
create policy "tickets owner insert" on public.tickets
  for insert with check (auth.uid() = user_id);

drop policy if exists "tickets owner update" on public.tickets;
create policy "tickets owner update" on public.tickets
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "tickets owner delete" on public.tickets;
create policy "tickets owner delete" on public.tickets
  for delete using (auth.uid() = user_id);

-- junction: the caller must own BOTH the ticket and the collection
drop policy if exists "collection_tickets owner select" on public.collection_tickets;
create policy "collection_tickets owner select" on public.collection_tickets
  for select using (
    exists (select 1 from public.tickets     t where t.id = ticket_id     and t.user_id = auth.uid())
    and
    exists (select 1 from public.collections c where c.id = collection_id and c.user_id = auth.uid())
  );

drop policy if exists "collection_tickets owner insert" on public.collection_tickets;
create policy "collection_tickets owner insert" on public.collection_tickets
  for insert with check (
    exists (select 1 from public.tickets     t where t.id = ticket_id     and t.user_id = auth.uid())
    and
    exists (select 1 from public.collections c where c.id = collection_id and c.user_id = auth.uid())
  );

drop policy if exists "collection_tickets owner delete" on public.collection_tickets;
create policy "collection_tickets owner delete" on public.collection_tickets
  for delete using (
    exists (select 1 from public.tickets     t where t.id = ticket_id     and t.user_id = auth.uid())
    and
    exists (select 1 from public.collections c where c.id = collection_id and c.user_id = auth.uid())
  );
