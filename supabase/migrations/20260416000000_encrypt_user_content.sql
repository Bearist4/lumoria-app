-- Encrypt user content at rest.
--
-- Client-side AES-GCM-256 now wraps:
--   * collections.name  -- stored as base64 ciphertext (text)
--   * collections.location_*  -- bundled into a single ciphertext column
--   * tickets.payload  -- stored as jsonb wrapper { "c": "<base64-ciphertext>" }
--
-- Plaintext columns that stay readable server-side (for RLS / indexing /
-- app-admin sanity): tickets.template_kind, tickets.orientation,
-- collections.color_family, and all id / user_id / timestamp columns.
--
-- Existing rows are wiped — the only historical data was developer test
-- data that cannot be decrypted server-side after this migration runs.

-- ---------------------------------------------------------------------------
-- Wipe existing rows (dev-only test data)
-- ---------------------------------------------------------------------------
truncate table public.collection_tickets;
truncate table public.tickets;
truncate table public.collections cascade;

-- ---------------------------------------------------------------------------
-- collections: drop separate location columns, add a single encrypted blob
-- ---------------------------------------------------------------------------
alter table public.collections drop column if exists location_name;
alter table public.collections drop column if exists location_lat;
alter table public.collections drop column if exists location_lng;

alter table public.collections
    add column if not exists location_enc text;

comment on column public.collections.name         is 'Base64 AES-GCM-256 ciphertext of the user-entered name.';
comment on column public.collections.location_enc is 'Base64 AES-GCM-256 ciphertext of the location JSON, nullable.';
comment on column public.tickets.payload          is 'JSONB wrapper { "c": "<base64 AES-GCM-256 ciphertext>" } of the template payload.';
