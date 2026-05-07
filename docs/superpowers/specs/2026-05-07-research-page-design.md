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

```sql
alter table public.profiles
  add column participates_in_research boolean not null default false;

-- backfill: every existing early adopter auto-on
update public.profiles
   set participates_in_research = true
 where is_early_adopter = true;
```

Whatever path currently flips `is_early_adopter = true` (RPC, trigger, or website-signup migration) must also set `participates_in_research = true` in the same statement. Implementation step: locate that path during the implementation plan and patch it. User can flip the toggle off freely afterwards — we do not re-assert auto-on after the initial grant.

### Notification kind: `research_published`

Migration file: `supabase/migrations/20260521000002_research_notification_kind.sql`.

```sql
alter table public.notification_prefs
  add column research_published boolean not null default true;
```

`public.notification_allowed(p_user_id uuid, p_kind text)` is extended so that:

```sql
when p_kind = 'research_published' then
  coalesce(
    (select participates_in_research from profiles where id = p_user_id),
    false
  )
  and coalesce(
    (select research_published from notification_prefs where user_id = p_user_id),
    true  -- default-on if no prefs row
  )
```

Parameter names are renamed to avoid the column-vs-arg collision Postgres would otherwise hit. If the existing `notification_allowed` signature already uses `user_id` / `kind`, rename consistently in the same migration.

This means the master `participates_in_research` flag is the hard gate; the `research_published` notification toggle is a soft gate users can flip independently inside Notifications settings.

## Publish flow

Bear publishes an entry in two steps:

1. Insert a row in `research_entries` via Supabase Studio with `is_published = false` (drafting).
2. Run `select publish_research_entry('<uuid>')`.

The RPC:

```sql
create or replace function public.publish_research_entry(entry_id uuid)
returns void
language plpgsql
security definer
as $$
declare
  entry research_entries;
begin
  update research_entries
     set is_published = true,
         published_at = now()
   where id = entry_id
   returning * into entry;

  if not found then
    raise exception 'research entry % not found', entry_id;
  end if;

  -- Fan out push notifications to eligible users.
  -- Implementation: pg_net.http_post to the existing send-push edge function
  -- per recipient (or batched), passing kind = 'research_published' and
  -- payload { entry_id, title, deadline }. The edge function honours
  -- notification_allowed() server-side as it already does today.
end;
$$;
```

Permissions: callable only by service role — never expose to `anon` or `authenticated`. Bear invokes from Studio's SQL editor.

The fan-out detail (per-row HTTP vs. batched) is deferred to the implementation plan — the contract here is "one push per eligible user, fired synchronously on publish, tagged `research_published`".

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

There are two distinct controls. Keep them straight:

| Control | What it gates | Default | Where it lives |
|---|---|---|---|
| `participates_in_research` (master) | Visibility of the Research row + push eligibility | `false` (auto-`true` for EAs) | Settings root row + mirrored toggle inside `ResearchView` top card |
| `notification_prefs.research_published` (soft) | Push delivery only | `true` | `NotificationsView` only |

### Settings list (`SettingsView.swift`)

Two changes:

1. **New row "Participate in research"** under a new "Research" section visible to **every** signed-in user (EA or not). It hosts the master toggle. Title: "Participate in research". Subtitle: "Help shape Lumoria. Get notified when new studies open." Bound to `profiles.participates_in_research`.

2. **The existing "Research" disclosure row** that opens `ResearchView` is reparented under the same section, but conditionally rendered only when:

   ```swift
   profile.isEarlyAdopter || profile.participatesInResearch
   ```

   (So an EA who toggles off can still re-enter the Research page to flip it back on via the in-page card; non-EAs who opted in see the row.)

Result: a single "Research" section in Settings with always-visible master toggle on top and the disclosure row appearing/disappearing beneath it based on the gate.

### NotificationsView

New section `"Research"` under existing Memories section, with one toggle:

- **"Research updates"** — bound to `NotificationPrefsStore.Keys.researchPublished`. Subtitle: `When a new study opens.`

Section is rendered only when `participatesInResearch == true` (no point exposing the soft gate when the hard gate is off).

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

Folded into `ProfileStore` to avoid a third store object: extend `ProfileStore` with a `participatesInResearch: Bool` published property, mirrored to `@AppStorage("research.participates")` for instant UI, and an `setParticipates(_ on: Bool) async` method that upserts `profiles.participates_in_research`.

### `NotificationPrefsStore`

Add `researchPublished` field and key, mirroring the existing four. Update `Row` Codable struct, `apply()`, `save()`, and `pushLocalToStorage()`.

## Push handling

`PushNotificationService` already routes by kind. Add:

- New case in the kind enum: `.researchPublished`.
- Tap handler: pull `entry_id` from payload → set a deep-link target (e.g. `AppState.pendingDeepLink = .research(entryId:)`) → app navigates to `ResearchView` and scrolls to that entry on next appear.
- Foreground receipt: post a `Notification.Name(.researchEntryPublished)` so a visible `ResearchView` reloads.

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
- `notifications.section.research` = "Research"
- `notifications.research.title` = "Research updates"
- `notifications.research.subtitle` = "When a new study opens."

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
- `Lumoria App/views/settings/NotificationsView.swift` (new "Research" section)
- `Lumoria App/views/settings/NotificationPrefsStore.swift` (new field + key)
- `Lumoria App/views/settings/ProfileStore.swift` (new `participatesInResearch` field + setter)
- `Lumoria App/services/PushNotificationService.swift` (new kind + deep-link)
- `Lumoria App/services/analytics/AnalyticsEvent.swift` (3 new cases)
- `Lumoria App/Localizable.xcstrings`
- Wherever `is_early_adopter` is granted on the server (RPC / trigger): mirror to `participates_in_research`.

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
