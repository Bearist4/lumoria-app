-- Adds an optional group_id linking tickets that were "printed together"
-- (multi-leg trip, return + outbound flight, etc.). Tickets sharing a
-- group_id collapse into a single row in the All Tickets list and a
-- single paged TicketDetailView. The map deliberately keeps each
-- group member as its own pin — geography is per-leg, not per-group.
--
-- Apply with `supabase db push` or paste into Supabase Studio → SQL
-- Editor.

alter table public.tickets
    add column group_id uuid null;

comment on column public.tickets.group_id is
    'Optional grouping key. Tickets sharing a group_id were created '
    'together (e.g. outbound + return) and surface as a single, '
    'horizontally-paged entry in the All Tickets list and detail view. '
    'NULL means the ticket stands alone.';

create index if not exists tickets_group_id_idx
    on public.tickets (group_id)
    where group_id is not null;
