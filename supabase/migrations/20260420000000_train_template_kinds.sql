-- Expand `tickets.template_kind` CHECK constraint to include the
-- train-category templates. Original constraint (from
-- 20260415000000_tickets.sql) only permitted the 5 plane templates;
-- attempting to insert `'express'` or `'orient'` fails with
-- `tickets_template_kind_check`.
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
        'orient'
    ));
