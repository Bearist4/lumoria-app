-- Add the "night" train template to the `tickets.template_kind`
-- CHECK constraint. Without this, inserts with `template_kind =
-- 'night'` fail with `tickets_template_kind_check`.
--
-- Apply with `supabase db push` or paste into Supabase Studio → SQL
-- Editor.

alter table public.tickets
    drop constraint if exists tickets_template_kind_check;

alter table public.tickets
    add constraint tickets_template_kind_check
    check (template_kind in (
        'afterglow',
        'studio',
        'heritage',
        'terminal',
        'prism',
        'express',
        'orient',
        'night'
    ));
