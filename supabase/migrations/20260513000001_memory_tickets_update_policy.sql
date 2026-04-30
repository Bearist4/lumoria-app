-- The original `memory_tickets` policies (in 20260417000000) granted
-- select / insert / delete but no UPDATE. That was harmless until the
-- 20260513000000 migration added `display_order` — without an UPDATE
-- policy, RLS silently rejects every write to the column, so manual
-- reorders never persist.
create policy "memory_tickets owner update" on public.memory_tickets
    for update using (
        exists (
            select 1 from public.tickets t
            where t.id = ticket_id and t.user_id = auth.uid()
        )
    )
    with check (
        exists (
            select 1 from public.tickets t
            where t.id = ticket_id and t.user_id = auth.uid()
        )
    );
