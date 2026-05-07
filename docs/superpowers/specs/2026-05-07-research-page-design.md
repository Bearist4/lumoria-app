# Research page

**Status:** spec
**Date:** 2026-05-07
**Owner:** Benjamin Caillet

## Goal

Turn the empty `ResearchView` stub into a live, remotely-published list of research initiatives. Eligible users (early adopters auto-enrolled, plus any other user who flips a "Participate in research" toggle) get a single push notification when a new entry is published, and can tap through to an external form (Tally / Typeform / Calendly).

## Non-goals (V1)

- In-app forms / answer collection — every entry links out to an external URL.
- Per-tag interest filtering — `tag` is a display pill only.
- Live participant counter / progress bar.
- Reminder / re-engagement pushes (one push per entry, on publish).
- Markdown rendering in `description` — plain text V1.
- Admin UI inside the iOS app — authoring happens via Supabase Studio.
- Server-side `notification_prefs` enforcement. The existing
  `notification_prefs` table referenced by `NotificationPrefsStore.swift`
  does not actually exist as a Postgres table — those toggles are
  `@AppStorage`-only today. Adding a per-kind soft gate for research
  would require building that table + an `notification_allowed()`
  function across all existing kinds, which is out of scope.
  Eligibility for V1 is therefore governed by the single
  `profiles.participates_in_research` master flag, gated server-side
  inside `publish_research_entry()`.

## Brainstorm decisions (locked)

| # | Question | Decision |
|---|---|---|
| Q1 | What does "participate" mean inside Lumoria? | **A.** External-link only. Lumoria announces + notifies + opens URL. |
| Q2 | Eligibility / opt-in semantics? | **A.** Union: early adopter OR `participates_in_research` toggle on. EAs auto-on; non-EAs default off and opt in. |
| Q3 | Notification trigger? | **A.** One push per entry, immediately on publish. No scheduled reminders. |
| Q4 | What is the `date` field? | **A.** Deadline. Past `deadline` → entry shows as Closed and moves to "Past research". |
| Q5 | What is `tag`? | **A.** Display-only pill. Curated lowercase enum. |
| Q6 | Authoring + final fields | **A.** Supabase Studio direct insert. Add `external_url`, `is_published`, standard ids/timestamps. **Skip** participant counter. |

## Data model

### New table: `public.research_entries`

Migration file: `supabase/migrations/20260521000000_research_entries.sql`.

```sql
create table public.research_entries (
  id                    uuid primary key default gen_random_uuid(),
  title                 text not null,
  description           text not null,
  external_url          text not null,
  tag                   text not null,
  minimum_participants  integer not null check (minimum_participants > 0),
  deadline              date not null,
  is_published          boolean not null default false,
  created_at            timestamptz not null default now(),
  published_at          timestamptz
);

alter table public.research_entries enable row level security;

create policy "research_entries_read_published"
  on public.research_entries for select
  to authenticated
  using (is_published = true);

-- writes via service role only (Supabase Studio / publish RPC)
```

Tag values are not enforced in SQL — kept as `text` for flexibility. Allowed values are documented client-side as a Swift enum (`ResearchTag`) with a `.unknown` fallback for forward-compat. V1 starter set: `ux`, `pricing`, `onboarding`, `discovery`, `general`.

### Profile column: `participates_in_research`

Migration file: `supabase/migrations/20260521000001_research_participation.sql`.

The early-adopter flag is `profiles.grandfathered_at` (timestamptz, nullable). EA = `grandfathered_at IS NOT NULL`. Swift exposes this as `EntitlementStore.isEarlyAdopter`.

```sql
alter table public.profiles
  add column participates_in_research boolean not null default false;

-- Backfill: every existing early adopter auto-on.
update public.profiles
   set participates_in_research = true
 where grandfathered_at is not null;
```

Two server-side paths flip `grandfathered_at` and need to mirror to `participates_in_research` in the same statement:

1. `public.handle_new_user()` — trigger on `auth.users` insert, runs the waitlist auto-stamp inside `20260516000000_early_adopter.sql`. Patch the `UPDATE public.profiles SET grandfathered_at = now() WHERE user_id = NEW.id` to also set `participates_in_research = true`.
2. `public.claim_early_adopter_seat()` RPC — the self-service grant from the same migration. Same patch on its `UPDATE` statement.

`public.revoke_early_adopter_seat()` deliberately does NOT clear `participates_in_research`. A user who claimed and then revoked their EA seat may still want to participate in research — keep the flag they last set.

User can flip the toggle off freely after grant — we do not re-assert auto-on.

### Notification routing kind: `research_published`

Migration file: `supabase/migrations/20260521000002_research_notification_kind.sql`.

The `public.notifications` table currently constrains `kind` to `('throwback','onboarding','news','link')` (per `20260422000000_notifications.sql`). Widen that constraint:

```sql
alter table public.notifications
  drop constraint notifications_kind_check;

alter table public.notifications
  add constraint notifications_kind_check
    check (kind in ('throwback','onboarding','news','link','research_published'));

alter table public.notifications
  add column research_entry_id uuid references public.research_entries(id) on delete cascade;
```

The `research_entry_id` column is the deep-link payload for research pushes — same pattern as the existing `memory_id` / `template_kind` columns.

V1 has **no** `notification_prefs.research_published` toggle (see Non-goals). Eligibility is enforced inside `publish_research_entry()` via the master `participates_in_research` flag.

This means the master `participates_in_research` flag is the hard gate; the `research_published` notification toggle is a soft gate users can flip independently inside Notifications settings.

## Publish flow

Bear publishes an entry in two steps:

1. Insert a row in `research_entries` via Supabase Studio with `is_published = false` (drafting).
2. Run `select publish_research_entry('<uuid>')`.

The RPC inserts one row into `public.notifications` per eligible user. The existing `notifications_fanout_push` AFTER INSERT trigger calls `send-push` for each row, which reads the row, looks up `device_tokens` for that user, and pushes via APNs. No new edge function needed.

```sql
create or replace function public.publish_research_entry(p_entry_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_entry         research_entries;
  v_inserted      integer;
begin
  update research_entries
     set is_published = true,
         published_at = coalesce(published_at, now())
   where id = p_entry_id
   returning * into v_entry;

  if not found then
    raise exception 'research entry % not found', p_entry_id;
  end if;

  -- Fan out: one notifications row per opted-in user.
  insert into public.notifications
    (user_id, kind, title, message, research_entry_id)
  select
    p.user_id,
    'research_published',
    'New research opening',
    v_entry.title,
    v_entry.id
  from public.profiles p
  where p.participates_in_research = true;

  get diagnostics v_inserted = row_count;
  return v_inserted;
end;
$$;

revoke all on function public.publish_research_entry(uuid) from public, authenticated, anon;
-- service role retains EXECUTE by default; Bear invokes from Studio.
```

Idempotency: re-running the RPC after a row is already published reuses the original `published_at` timestamp but re-inserts notifications. Since `notifications` has no uniqueness constraint for this kind, that would deliver duplicate pushes. Guard rail: the function checks `was_already_published` and skips fan-out on a second call.

```sql
-- Refined RPC body (replaces the simple version above):
declare
  v_entry             research_entries;
  v_was_published     boolean;
  v_inserted          integer := 0;
begin
  select is_published into v_was_published
    from research_entries where id = p_entry_id;

  if v_was_published is null then
    raise exception 'research entry % not found', p_entry_id;
  end if;

  if v_was_published then
    -- Already published; do not re-fan-out.
    return 0;
  end if;

  update research_entries
     set is_published = true,
         published_at = now()
   where id = p_entry_id
   returning * into v_entry;

  insert into public.notifications
    (user_id, kind, title, message, research_entry_id)
  select
    p.user_id,
    'research_published',
    'New research opening',
    v_entry.title,
    v_entry.id
  from public.profiles p
  where p.participates_in_research = true;

  get diagnostics v_inserted = row_count;
  return v_inserted;
end;
```

Permissions: callable only by service role — never expose to `anon` or `authenticated`.

## iOS — Research page

`Lumoria App/views/settings/ResearchView.swift` is rewritten from stub → live list. Visibility expanded: shown to anyone whose profile has `participates_in_research = true` (covers EAs auto-on + opted-in users). Stale deep-link still safe — empty state already exists.

### Sections

- **Active** — `is_published = true AND deadline >= today()`, sorted by `deadline ASC`.
- **Past research** — collapsible disclosure group, `deadline < today()`, sorted `deadline DESC`. CTA disabled, card dimmed.

### Card

- Tag pill (top-left). Color from `ResearchTag.tint`.
- Title (`.body.weight(.semibold)`).
- Description (`.subheadline`, `.foregroundStyle(.secondary)`, 3-line clamp).
- Footer line: "Looking for at least N participants · Closes Mon DD".
- Primary CTA `LumoriaButton` "Open research" → `UIApplication.shared.open(externalURL)`. Past entries: button replaced with `"Closed"` badge.

### In-page participation toggle

Top of `ResearchView` shows a `LumoriaCard` with the "Participate in research" toggle, mirrored to the same column as the Settings entry. Subtitle: `Help shape Lumoria. Get notified when new studies open.` Flipping it off here also hides the Research row from Settings on next render.

### Empty state

When zero active entries: existing "No active research" copy is retained.

## iOS — Settings surface

One control. Keep it simple:

| Control | What it gates | Default | Where it lives |
|---|---|---|---|
| `participates_in_research` | Visibility of the Research row + push eligibility | `false` (auto-`true` for EAs) | Settings row + mirrored toggle inside `ResearchView` top card |

### Settings list (`SettingsView.swift`)

Two changes:

1. **New row "Participate in research"** under a new "Research" section visible to **every** signed-in user (EA or not). It hosts the master toggle. Title: "Participate in research". Subtitle: "Help shape Lumoria. Get notified when new studies open." Bound to `profiles.participates_in_research`.

2. **The existing "Research" disclosure row** that opens `ResearchView` is reparented under the same section, but conditionally rendered only when:

   ```swift
   entitlement.isEarlyAdopter || profile.participatesInResearch
   ```

   (So an EA who toggles off can still re-enter the Research page to flip it back on via the in-page card; non-EAs who opted in see the row.)

Result: a single "Research" section in Settings with always-visible master toggle on top and the disclosure row appearing/disappearing beneath it based on the gate.

### NotificationsView

**No changes for V1.** A per-kind soft toggle would require building the missing `notification_prefs` server table first — out of scope.

### `ResearchView` top card

Mirrors the master toggle so the user can opt out from inside the page they're reading. Same binding (`profiles.participates_in_research`), same store. Flipping it off here causes the disclosure row in Settings to disappear on next render — the `ResearchView` itself stays visible until the user pops it.

## Client stores

### `ResearchEntry` (Codable struct)

```swift
struct ResearchEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let description: String
    let externalURL: URL
    let tag: ResearchTag
    let minimumParticipants: Int
    let deadline: Date
    let publishedAt: Date?
}

enum ResearchTag: String, Codable, CaseIterable {
    case ux, pricing, onboarding, discovery, general, unknown
    init(from decoder: Decoder) throws { /* fallback to .unknown */ }
}
```

### `ResearchStore` (`@MainActor ObservableObject`)

- `@Published private(set) var entries: [ResearchEntry] = []`
- `@Published private(set) var isLoading = false`
- `@Published var errorMessage: String? = nil`
- `func load() async` — selects published entries, ordered by `deadline asc`.
- `func entry(id: UUID) -> ResearchEntry?` — used by deep-link from push tap.
- V1 reloads on `.task` and on push receipt (`PushNotificationService` posts a Notification name → store reloads). Realtime subscription deferred to V2.

### `ResearchParticipationStore`

Folded into `ProfileStore` to avoid a third store object: extend `ProfileStore` with a `participatesInResearch: Bool` published property, mirrored to `@AppStorage("research.participates")` for instant UI, and a `setParticipates(_ on: Bool) async` method that updates `profiles.participates_in_research` for the signed-in user.

### `NotificationPrefsStore`

No changes for V1.

## Push handling

The existing edge function `supabase/functions/send-push/index.ts` builds the APNs payload from columns it reads off the `notifications` row: `id`, `kind`, `memory_id`, `template_kind`. Two changes:

1. Extend its `NotificationRow` interface and the `kind` literal union to include `'research_published'` and add `research_entry_id: string | null`.
2. Add `research_entry_id: notification.research_entry_id` to the APNs body so the iOS delegate can deep-link.

`Lumoria App/views/notifications/Notification.swift` — extend `LumoriaNotification.Kind` enum with `.researchPublished` and provide `eyebrow` + `backgroundColor` for it. Existing notification-center cards keep working; research pushes also show up there.

`Lumoria App/services/PushNotificationService.swift` — `DeepLink` struct gains a `researchEntryId: UUID?` field. `ingestTappedPayload(_:)` reads the `research_entry_id` key from `userInfo`. The existing routing target (`MemoriesView` → `CollectionsView.route(_:)`) gains a research case that pushes onto the navigation stack to open `ResearchView` with the right entry pre-scrolled.

Foreground receipt: when `willPresent` fires for a `research_published` kind, post `Notification.Name.lumoriaResearchPublished` so any visible `ResearchView` reloads its store.

## Analytics

New events in `AnalyticsEvent.swift`:

- `researchEntryViewed(entryId: UUID, tag: String)` — fired once per entry per `ResearchView` appear.
- `researchEntryOpened(entryId: UUID, tag: String)` — CTA tap.
- `researchParticipationToggled(enabled: Bool, source: "settings" | "research_page")`.

## Localization

All new copy lands in `Lumoria App/Localizable.xcstrings`. Keys:

- `research.page.title` = "Research"
- `research.section.active` = "Active"
- `research.section.past` = "Past research"
- `research.card.cta.open` = "Open research"
- `research.card.cta.closed` = "Closed"
- `research.card.footer` = "Looking for at least %lld participants · Closes %@"
- `research.empty.title` = "No active research"
- `research.empty.body` = (existing copy retained)
- `research.toggle.title` = "Participate in research"
- `research.toggle.subtitle` = "Help shape Lumoria. Get notified when new studies open."

## Changelog

Per `feedback_changelog_mdx`: add an entry at `lumoria/src/content/changelog/2026-05-07-research-page.mdx` (JS-export frontmatter) summarizing: research initiatives publishable from Supabase, push notifications to participating users, opt-in toggle for non-early-adopters.

## Files touched

**New:**
- `supabase/migrations/20260521000000_research_entries.sql`
- `supabase/migrations/20260521000001_research_participation.sql`
- `supabase/migrations/20260521000002_research_notification_kind.sql`
- `Lumoria App/services/research/ResearchEntry.swift`
- `Lumoria App/services/research/ResearchStore.swift`
- `lumoria/src/content/changelog/2026-05-07-research-page.mdx`

**Modified:**
- `Lumoria App/views/settings/ResearchView.swift` (full rewrite — list, card, toggle)
- `Lumoria App/views/settings/SettingsView.swift` (gate change + new "Participate in research" row)
- `Lumoria App/views/settings/ProfileStore.swift` (new `participatesInResearch` field + setter)
- `Lumoria App/views/notifications/Notification.swift` (new `.researchPublished` kind)
- `Lumoria App/views/collections/CollectionsView.swift` (route research deep-link)
- `Lumoria App/services/PushNotificationService.swift` (new payload field + deep-link)
- `Lumoria App/services/analytics/AnalyticsEvent.swift` (3 new cases)
- `Lumoria App/Localizable.xcstrings`
- `supabase/functions/send-push/index.ts` (kind union + research_entry_id field)
- `supabase/migrations/20260516000000_early_adopter.sql` is **not** touched directly; instead, the new participation migration patches `handle_new_user()` and `claim_early_adopter_seat()` in place via `CREATE OR REPLACE`.

## Testing

- Unit: `ResearchStore.load()` happy path + error path (mock Supabase client).
- Unit: `ProfileStore.setParticipates(true/false)` upserts and updates published value.
- Unit: `ResearchTag.unknown` fallback when server sends an unrecognized tag string.
- Manual: Studio insert + `publish_research_entry()` → push lands on a test EA device → tap deep-links to entry.
- Manual: Toggle off in Settings → push does not arrive on next publish.
- Manual: Past-deadline entry renders in "Past research" disclosure with disabled CTA.

## Open questions for implementation phase

- Exact pg_net fan-out shape — per-recipient http_post vs. one call to send-push with a recipient list. Implementation plan picks based on existing `send-push` signature.
- Whether `ResearchView` should also live behind a tab when the user has many entries, or stay a Settings sub-screen forever. Stay sub-screen for V1; revisit when entry volume justifies it.
