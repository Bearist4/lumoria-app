-- Style variant per ticket.
--
-- Each ticket may carry a `style_id` pointing to a palette in the app's
-- static catalog (e.g. "studio.dark"). This is plaintext on purpose — it
-- is not user content, just a UI selector for a public set of palettes.
-- Keeping it out of the encrypted payload lets us query / migrate styles
-- without touching encryption.
--
-- NULL means: render with the template's default style (so existing rows
-- keep working unchanged).
--
-- Apply with `supabase db push` or paste into Supabase Studio → SQL Editor.

alter table public.tickets
    add column if not exists style_id text;

comment on column public.tickets.style_id is
  'Style variant identifier (e.g. "studio.dark") from the app catalog. NULL = template default.';
