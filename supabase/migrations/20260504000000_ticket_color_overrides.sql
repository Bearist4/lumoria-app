-- Per-element color overrides per ticket.
--
-- Layered on top of the chosen `style_id` at render time so a user can
-- pick "studio.mist" and then tweak the accent / text / background
-- colors individually without inventing a new style variant. Stored as
-- JSONB to keep the column flexible — keys come from
-- `TicketStyleVariant.Element` raw values (e.g. "accent",
-- "background"); values are 6-char uppercase RGB hex strings without a
-- leading "#".
--
-- Plaintext on purpose, like `style_id` — these are user-picked colors,
-- not personal content, and keeping them out of the encrypted payload
-- lets us query / migrate themes without touching encryption.
--
-- NULL or empty object means: no overrides — render the variant
-- verbatim. Existing rows therefore keep working unchanged.
--
-- Apply with `supabase db push` or paste into Supabase Studio → SQL Editor.

alter table public.tickets
    add column if not exists color_overrides jsonb;

comment on column public.tickets.color_overrides is
  'Per-element color overrides keyed by TicketStyleVariant.Element raw values (e.g. "accent": "D94544"). NULL = no overrides.';
