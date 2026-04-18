-- Ticket-level locations.
--
-- Each ticket can now carry one or two locations, both encrypted as JSON:
--   • location_primary_enc   — single venue, or the "from" leg of a trip
--                              (origin airport / departure station).
--   • location_secondary_enc — the "to" leg of a trip (destination airport /
--                              arrival station). NULL for single-venue
--                              tickets (movie, dining, single event).
--
-- Encrypted with the same AES-GCM-256 envelope used for `name`/`emoji_enc`
-- on memories and `payload` on tickets — base64 ciphertext of a JSON blob.
-- The cleartext shape mirrors the Swift `TicketLocation` struct:
--   { "name": "…", "subtitle": "…", "city": "…", "country": "…",
--     "lat": 0.0, "lng": 0.0, "kind": "airport" | "station" | "venue" }
--
-- Apply with `supabase db push` or paste into Supabase Studio → SQL Editor.

alter table public.tickets
    add column if not exists location_primary_enc   text,
    add column if not exists location_secondary_enc text;

comment on column public.tickets.location_primary_enc is
  'Base64 AES-GCM-256 ciphertext of the primary location JSON (single venue, or origin for a trip), nullable.';

comment on column public.tickets.location_secondary_enc is
  'Base64 AES-GCM-256 ciphertext of the secondary location JSON (destination for a trip), nullable.';
