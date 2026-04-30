-- Per-memory sort preference for MemoryDetailView. Plain columns (non-
-- sensitive metadata, like `color_family`). Defaults match the app-side
-- default: oldest-first by date the ticket was added to the memory.
alter table public.memories
    add column sort_field      text    not null default 'date_added',
    add column sort_ascending  boolean not null default true;

-- Sort field is one of three known values; reject typos at the DB.
alter table public.memories
    add constraint memories_sort_field_check
    check (sort_field in ('date_added', 'event_date', 'date_created'));
