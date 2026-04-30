-- Adds an optional encrypted ISO-8601 event date for client-side sorting
-- in MemoryDetailView. Ciphertext shape matches `memories.start_date_enc`
-- (AES-GCM-256, base64) — see Lumoria App/views/collections/Collection.swift
-- (`MemoryDateCodec`).
alter table public.tickets
    add column event_date_enc text null;

comment on column public.tickets.event_date_enc is
    'AES-GCM-256 base64 ciphertext of the ISO-8601 event date '
    '(departure for journey templates, single date for venue templates). '
    'Optional. Used for client-side sort in MemoryDetailView.';
