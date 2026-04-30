-- Per-memory manual order. Null = no manual order (membership predates
-- a manual reorder; client falls back to whatever sort_field selects).
alter table public.memory_tickets
    add column display_order integer null;

-- Allow 'manual' as a sort_field value. The check constraint was
-- introduced in 20260512000001_memory_sort_prefs.sql; replace it.
alter table public.memories
    drop constraint memories_sort_field_check;

alter table public.memories
    add constraint memories_sort_field_check
    check (sort_field in ('date_added', 'event_date', 'date_created', 'manual'));

-- Lookup index for the client's "load tickets in memory" query.
create index if not exists memory_tickets_memory_id_display_order_idx
    on public.memory_tickets (memory_id, display_order);
