-- 20260424000000_profiles.sql
-- Per-user onboarding state. One row per auth.users row, created via trigger
-- at signup, deleted on cascade. RLS: owner read/update only. Insert and
-- delete are handled by triggers / cascade so clients have no policies for
-- them.
--
-- Idempotent: each object is guarded with IF NOT EXISTS / OR REPLACE so the
-- file can be re-run against a database that already has the migration
-- applied (dev databases, Supabase dashboard, CI resets, etc.).

create extension if not exists moddatetime;

create table if not exists public.profiles (
    user_id uuid primary key references auth.users(id) on delete cascade,
    show_onboarding boolean not null default true,
    onboarding_step text not null default 'welcome'
        check (onboarding_step in (
            'welcome','createMemory','memoryCreated','enterMemory',
            'pickCategory','pickTemplate','fillInfo','pickStyle',
            'allDone','exportOrAddMemory','endCover','done'
        )),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "profiles_self_read" on public.profiles;
create policy "profiles_self_read"
    on public.profiles for select
    using (auth.uid() = user_id);

drop policy if exists "profiles_self_update" on public.profiles;
create policy "profiles_self_update"
    on public.profiles for update
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

drop trigger if exists profiles_updated_at on public.profiles;
create trigger profiles_updated_at
    before update on public.profiles
    for each row execute function moddatetime(updated_at);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
    insert into public.profiles (user_id) values (new.id)
        on conflict (user_id) do nothing;
    return new;
end;
$$;

-- Named distinctly so it co-exists with the waitlist trigger already on
-- auth.users. Both fire after insert; order between them is irrelevant.
drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile
    after insert on auth.users
    for each row execute function public.handle_new_user();

-- Backfill existing users: treat anyone who pre-dates this migration as
-- having already completed onboarding, so the new tutorial doesn't interrupt
-- testers or beta users.
insert into public.profiles (user_id, show_onboarding, onboarding_step)
    select id, false, 'done' from auth.users
    on conflict (user_id) do nothing;
