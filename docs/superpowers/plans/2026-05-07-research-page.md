# Research Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn `ResearchView` from an empty stub into a remotely-published list of research initiatives, push-notify opted-in users, and let any user opt in/out via Settings (early adopters auto-on).

**Architecture:** Server side — new `research_entries` table read-gated by RLS; new `participates_in_research` bool on `profiles` (auto-`true` for early adopters via patched RPC + trigger); new `research_published` value in the `notifications.kind` CHECK constraint plus a `research_entry_id` payload column; a single `publish_research_entry()` RPC fans out one row per opted-in user. Client side — new `ResearchEntry` Codable + `ResearchStore`; `ProfileStore` extended with the participation flag; `LumoriaNotification.Kind` extended; `ResearchView` rewritten as a real list with a master toggle on top; `SettingsView` gets a new "Research" section.

**Tech Stack:** Swift 5.10 / SwiftUI on iOS, Supabase (Postgres + Edge Functions / Deno), `pg_net` for fan-out, APNs via the existing `send-push` function.

**Spec:** `docs/superpowers/specs/2026-05-07-research-page-design.md`

---

## File structure

**New (Postgres):**
- `supabase/migrations/20260521000000_research_entries.sql`
- `supabase/migrations/20260521000001_research_participation.sql`
- `supabase/migrations/20260521000002_research_notifications_kind.sql`
- `supabase/migrations/20260521000003_publish_research_entry_rpc.sql`

**New (Swift):**
- `Lumoria App/services/research/ResearchEntry.swift` — Codable model + `ResearchTag` enum
- `Lumoria App/services/research/ResearchStore.swift` — `@MainActor ObservableObject` for the active/past lists

**New (web):**
- `lumoria/src/content/changelog/2026-05-07-research-page.mdx`

**New (tests):**
- `Lumoria AppTests/ResearchEntryDecodeTests.swift`
- `Lumoria AppTests/ResearchStoreTests.swift`

**Modified:**
- `supabase/functions/send-push/index.ts` — extend `NotificationRow` interface and APNs body
- `Lumoria App/views/notifications/Notification.swift` — `.researchPublished` case
- `Lumoria App/services/PushNotificationService.swift` — `DeepLink` gains `researchEntryId`; `ingestTappedPayload` reads it; `willPresent` posts a notification name; analytics-kind switch handles `research_published`
- `Lumoria App/views/collections/CollectionsView.swift` — `route(_:)` handles `.researchPublished`
- `Lumoria App/views/settings/ProfileStore.swift` — `participatesInResearch` published property + `setParticipates`
- `Lumoria App/views/settings/ResearchView.swift` — full rewrite
- `Lumoria App/views/settings/SettingsView.swift` — new "Research" section
- `Lumoria App/Lumoria_AppApp.swift` — inject `ResearchStore` into the environment
- `Lumoria App/services/analytics/AnalyticsEvent.swift` — 3 new cases
- `Lumoria App/services/analytics/AnalyticsMappers.swift` — map the 3 cases
- `Lumoria App/Localizable.xcstrings` — new keys

---

## Conventions used below

- `psql` in tasks means: paste the migration body into Supabase Studio → SQL Editor and run it. Local devs may also use `supabase db push` if their stack is wired up. Either path is fine; the migration files are the source of truth either way.
- "App target" = the `Lumoria App` Xcode target. "Tests target" = `Lumoria AppTests`.
- Run iOS unit tests with `xcodebuild test -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 15" -only-testing:Lumoria_AppTests/<TestClass>` from the repo root, or via Xcode's Test navigator on a single test.
- Commits are atomic per task.

---

## Task 1: Create `research_entries` table + RLS

**Files:**
- Create: `supabase/migrations/20260521000000_research_entries.sql`

- [ ] **Step 1: Write the migration**

```sql
-- Research initiatives surfaced inside the iOS app's Research tab and
-- pushed to opted-in users on publish. Each row points at an external
-- form (Tally / Typeform / Calendly) — Lumoria itself does not collect
-- responses.

create table public.research_entries (
    id                   uuid         primary key default gen_random_uuid(),
    title                text         not null,
    description          text         not null,
    external_url         text         not null,
    tag                  text         not null,
    minimum_participants integer      not null check (minimum_participants > 0),
    deadline             date         not null,
    is_published         boolean      not null default false,
    created_at           timestamptz  not null default now(),
    published_at         timestamptz
);

comment on table public.research_entries is
  'Research initiatives surfaced in the iOS Research tab. Authored manually in Studio.';
comment on column public.research_entries.tag is
  'Curated lowercase enum: ux | pricing | onboarding | discovery | general. Display-only.';
comment on column public.research_entries.deadline is
  'Last day to participate. After this date the client treats the entry as Past.';

create index research_entries_published_deadline_idx
  on public.research_entries (deadline asc)
  where is_published = true;

alter table public.research_entries enable row level security;

drop policy if exists "research_entries_read_published" on public.research_entries;
create policy "research_entries_read_published" on public.research_entries
  for select
  to authenticated
  using (is_published = true);
-- writes via service role only (Studio SQL editor / publish RPC)
```

- [ ] **Step 2: Apply the migration**

Paste into Supabase Studio → SQL Editor → Run. Or `supabase db push` if local dev stack is wired up.

Expected: `ALTER TABLE`, `CREATE INDEX`, `CREATE POLICY` lines succeed with no errors.

- [ ] **Step 3: Smoke-check**

In Studio SQL editor, insert a draft and read it back:

```sql
insert into public.research_entries
    (title, description, external_url, tag, minimum_participants, deadline, is_published)
values
    ('Onboarding deep-dive', 'Help us shape the next onboarding flow.',
     'https://example.com/form', 'onboarding', 5, current_date + 14, false);

select count(*) from public.research_entries; -- 1
```

Expected: row inserted. RLS doesn't block the service-role console.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260521000000_research_entries.sql
git commit -m "feat(db): add research_entries table for remote research publishing"
```

---

## Task 2: Add `participates_in_research` to `profiles` + patch EA grant paths

**Files:**
- Create: `supabase/migrations/20260521000001_research_participation.sql`

- [ ] **Step 1: Write the migration**

The migration adds the column, backfills existing early adopters, and replaces `handle_new_user()` and `claim_early_adopter_seat()` so that whenever `grandfathered_at` is stamped, `participates_in_research` is also flipped to `true`. Bodies of the two functions are copied from `20260516000000_early_adopter.sql` and modified — the engineer must keep the rest of the body byte-identical.

```sql
-- One-flag opt-in for the Research feed and its push notifications.
-- Default false. Auto-true for new and existing early adopters.

alter table public.profiles
  add column participates_in_research boolean not null default false;

comment on column public.profiles.participates_in_research is
  'Master gate for Research entries visibility and research_published push delivery.';

-- Backfill: every existing early adopter is auto-opted-in.
update public.profiles
   set participates_in_research = true
 where grandfathered_at is not null;

-- ---------------------------------------------------------------------
-- Patch handle_new_user() so the auto-stamp from the waitlist also
-- flips the new participation flag in the same statement.
-- Body is otherwise identical to 20260516000000_early_adopter.sql.
-- ---------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_count integer;
begin
  insert into public.profiles (user_id) values (new.id);

  perform pg_advisory_xact_lock(hashtext('lumoria_grandfather_seat'));

  if exists (
    select 1 from public.waitlist_subscribers
     where supabase_user_id = new.id
  ) then
    select count(*) into v_count
      from public.profiles
     where grandfathered_at is not null;

    if v_count < 300 then
      update public.profiles
         set grandfathered_at = now(),
             participates_in_research = true
       where user_id = new.id;
    end if;
  end if;

  return new;
end;
$function$;

-- ---------------------------------------------------------------------
-- Patch claim_early_adopter_seat() the same way.
-- ---------------------------------------------------------------------
create or replace function public.claim_early_adopter_seat()
returns timestamptz
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_uid   uuid := auth.uid();
  v_taken integer;
  v_cap   constant integer := 300;
  v_stamp timestamptz;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  select grandfathered_at into v_stamp
    from public.profiles
   where user_id = v_uid;
  if v_stamp is not null then
    return v_stamp;
  end if;

  perform pg_advisory_xact_lock(hashtext('lumoria_grandfather_seat'));

  select count(*) into v_taken
    from public.profiles
   where grandfathered_at is not null;

  if v_taken >= v_cap then
    raise exception 'no_seats_remaining';
  end if;

  update public.profiles
     set grandfathered_at = now(),
         participates_in_research = true
   where user_id = v_uid
   returning grandfathered_at into v_stamp;

  return v_stamp;
end;
$function$;
```

- [ ] **Step 2: Apply the migration**

Paste into Studio SQL editor → Run. Expected: `ALTER TABLE`, two `CREATE OR REPLACE FUNCTION` statements succeed.

- [ ] **Step 3: Smoke-check**

```sql
-- Expect non-zero (every existing EA was backfilled).
select count(*)
  from public.profiles
 where participates_in_research = true
   and grandfathered_at is not null;

-- Expect equal — every EA participates.
select
  (select count(*) from public.profiles where grandfathered_at is not null) as eas,
  (select count(*) from public.profiles where grandfathered_at is not null and participates_in_research) as eas_opted_in;
```

Expected: the two counts in the second query are equal.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260521000001_research_participation.sql
git commit -m "feat(db): add participates_in_research flag, auto-on for early adopters"
```

---

## Task 3: Widen `notifications.kind` constraint + add `research_entry_id`

**Files:**
- Create: `supabase/migrations/20260521000002_research_notifications_kind.sql`

- [ ] **Step 1: Write the migration**

```sql
-- Push-routing kind for research entries. Same notifications table as
-- throwback / onboarding / news / link — the existing AFTER INSERT
-- trigger fans out to APNs via the send-push edge function.
--
-- Adds research_entry_id alongside the existing memory_id /
-- template_kind payload columns.

alter table public.notifications
  drop constraint if exists notifications_kind_check;

alter table public.notifications
  add constraint notifications_kind_check
    check (kind in ('throwback','onboarding','news','link','research_published'));

alter table public.notifications
  add column research_entry_id uuid
    references public.research_entries(id) on delete cascade;

comment on column public.notifications.research_entry_id is
  'Optional pointer to a research entry (for kind = research_published). Client deep-links to the Research page and scrolls to this id.';

create index if not exists notifications_research_entry_id_idx
  on public.notifications(research_entry_id)
  where research_entry_id is not null;
```

- [ ] **Step 2: Apply the migration**

Paste into Studio → Run. Expected: `ALTER TABLE` succeeds, both for the constraint swap and the new column.

- [ ] **Step 3: Smoke-check**

```sql
-- Should fail with check_violation:
do $$
begin
  insert into public.notifications (user_id, kind, title, message)
  values ('00000000-0000-0000-0000-000000000000', 'bogus', 'x', 'y');
exception when check_violation then
  raise notice 'check_violation as expected';
end $$;

-- Should succeed (constraint widened):
explain insert into public.notifications (user_id, kind, title, message)
values ('00000000-0000-0000-0000-000000000000', 'research_published', 'x', 'y');
```

Expected: first block prints `NOTICE: check_violation as expected`. Second `EXPLAIN` shows a plan (it does not actually insert, so the FK to `auth.users` doesn't fire).

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260521000002_research_notifications_kind.sql
git commit -m "feat(db): widen notifications.kind for research_published, add research_entry_id"
```

---

## Task 4: `publish_research_entry()` RPC

**Files:**
- Create: `supabase/migrations/20260521000003_publish_research_entry_rpc.sql`

- [ ] **Step 1: Write the migration**

```sql
-- Atomic publish + fan-out for research entries.
--
-- Idempotent: re-running on an already-published entry does nothing
-- (returns 0). On first publish, inserts one notifications row per
-- opted-in user. The existing notifications_fanout_push trigger
-- handles APNs delivery.

create or replace function public.publish_research_entry(p_entry_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    v_was_published boolean;
    v_entry         research_entries;
    v_inserted      integer := 0;
begin
    select is_published into v_was_published
      from research_entries
     where id = p_entry_id;

    if v_was_published is null then
        raise exception 'research entry % not found', p_entry_id;
    end if;

    if v_was_published then
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
$$;

revoke all on function public.publish_research_entry(uuid) from public, anon, authenticated;

comment on function public.publish_research_entry(uuid) is
  'Service-role RPC. Flips is_published, sets published_at, and fans out one notifications row per opted-in user.';
```

- [ ] **Step 2: Apply the migration**

Paste into Studio → Run.

- [ ] **Step 3: Smoke-check (without actually firing pushes)**

In Studio SQL editor, target a test draft entry (e.g. the one created in Task 1):

```sql
-- Pretend we have a test profile opted in:
update public.profiles
   set participates_in_research = true
 where user_id = '<your-test-uid>';

-- Capture the draft id:
select id from public.research_entries where is_published = false limit 1;

-- Publish it:
select public.publish_research_entry('<that-id>');
-- Returns the integer count of notifications inserted (>= 1 if any user opted in).

-- Verify state:
select is_published, published_at from public.research_entries where id = '<that-id>';
-- is_published = true, published_at non-null.

-- Verify a notification was created:
select kind, research_entry_id from public.notifications
 where research_entry_id = '<that-id>';

-- Idempotency:
select public.publish_research_entry('<that-id>');
-- Returns 0.
```

Expected: returns ≥ 1 first call, 0 second call.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260521000003_publish_research_entry_rpc.sql
git commit -m "feat(db): publish_research_entry RPC fans out to opted-in users"
```

---

## Task 5: Extend `send-push` edge function

**Files:**
- Modify: `supabase/functions/send-push/index.ts`

- [ ] **Step 1: Update the `NotificationRow` interface**

Find the existing interface near the top of the file:

```typescript
interface NotificationRow {
    id: string;
    user_id: string;
    kind: "throwback" | "onboarding" | "news" | "link";
    title: string;
    message: string;
    memory_id: string | null;
    template_kind: string | null;
}
```

Replace with:

```typescript
interface NotificationRow {
    id: string;
    user_id: string;
    kind: "throwback" | "onboarding" | "news" | "link" | "research_published";
    title: string;
    message: string;
    memory_id: string | null;
    template_kind: string | null;
    research_entry_id: string | null;
}
```

- [ ] **Step 2: Include `research_entry_id` in the APNs body**

In `sendOne(...)` find the `body` literal and add the field. The current shape:

```typescript
const body = {
    aps: { alert: { title: notification.title, body: notification.message },
           sound: "default", "thread-id": notification.kind },
    notification_id: notification.id,
    kind: notification.kind,
    memory_id: notification.memory_id,
    template_kind: notification.template_kind,
};
```

Becomes:

```typescript
const body = {
    aps: { alert: { title: notification.title, body: notification.message },
           sound: "default", "thread-id": notification.kind },
    notification_id: notification.id,
    kind: notification.kind,
    memory_id: notification.memory_id,
    template_kind: notification.template_kind,
    research_entry_id: notification.research_entry_id,
};
```

- [ ] **Step 3: Make sure the row-fetch SELECT includes the new column**

Search the file for the `from("notifications")` Postgrest call. If it uses `.select("*")` or `.select()` with no args, no change is needed (Supabase returns all columns). If it lists columns explicitly, append `research_entry_id` to that list.

- [ ] **Step 4: Deploy the edge function**

```bash
supabase functions deploy send-push
```

Expected: `Deployed function send-push` success line.

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/send-push/index.ts
git commit -m "feat(edge): send-push routes research_published kind with research_entry_id"
```

---

## Task 6: `ResearchEntry` model + `ResearchTag` enum

**Files:**
- Create: `Lumoria App/services/research/ResearchEntry.swift`
- Create: `Lumoria AppTests/ResearchEntryDecodeTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Lumoria AppTests/ResearchEntryDecodeTests.swift`:

```swift
import XCTest
@testable import Lumoria_App

final class ResearchEntryDecodeTests: XCTestCase {

    func test_decodes_known_tag() throws {
        let json = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "title": "Onboarding deep-dive",
          "description": "Help us shape the next onboarding flow.",
          "external_url": "https://example.com/form",
          "tag": "onboarding",
          "minimum_participants": 5,
          "deadline": "2026-06-01",
          "published_at": "2026-05-07T12:00:00Z"
        }
        """.data(using: .utf8)!

        let entry = try ResearchEntry.decoder.decode(ResearchEntry.self, from: json)

        XCTAssertEqual(entry.tag, .onboarding)
        XCTAssertEqual(entry.minimumParticipants, 5)
        XCTAssertEqual(entry.title, "Onboarding deep-dive")
    }

    func test_unknown_tag_falls_back() throws {
        let json = """
        {
          "id": "22222222-2222-2222-2222-222222222222",
          "title": "Mystery study",
          "description": "—",
          "external_url": "https://example.com/x",
          "tag": "growth-loops",
          "minimum_participants": 3,
          "deadline": "2026-06-15",
          "published_at": null
        }
        """.data(using: .utf8)!

        let entry = try ResearchEntry.decoder.decode(ResearchEntry.self, from: json)
        XCTAssertEqual(entry.tag, .unknown)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 15" -only-testing:Lumoria_AppTests/ResearchEntryDecodeTests`

Expected: FAIL — `Cannot find 'ResearchEntry' in scope`.

- [ ] **Step 3: Implement the model**

Create `Lumoria App/services/research/ResearchEntry.swift`:

```swift
//
//  ResearchEntry.swift
//  Lumoria App
//
//  Codable mirror of `public.research_entries`. Loaded by `ResearchStore`
//  and rendered by `ResearchView`. The external_url is opened verbatim
//  via UIApplication.open — never embedded in a WebView, so we don't have
//  to worry about cookies / consent for the third-party form host.
//

import Foundation

enum ResearchTag: String, Codable, CaseIterable, Hashable {
    case ux
    case pricing
    case onboarding
    case discovery
    case general
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ResearchTag(rawValue: raw) ?? .unknown
    }
}

struct ResearchEntry: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let title: String
    let description: String
    let externalURL: URL
    let tag: ResearchTag
    let minimumParticipants: Int
    let deadline: Date
    let publishedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case externalURL          = "external_url"
        case tag
        case minimumParticipants  = "minimum_participants"
        case deadline
        case publishedAt          = "published_at"
    }

    /// Shared decoder configured with snake_case ↔ camelCase via CodingKeys
    /// (already done above) and an ISO-8601 / `yyyy-MM-dd` date strategy
    /// that handles both the `deadline` (date) and `published_at`
    /// (timestamptz) columns.
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)

            // ISO 8601 with fractional seconds (timestamptz)
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = iso.date(from: raw) { return d }

            iso.formatOptions = [.withInternetDateTime]
            if let d = iso.date(from: raw) { return d }

            // Plain date (deadline column)
            let plain = DateFormatter()
            plain.calendar = Calendar(identifier: .gregorian)
            plain.locale = Locale(identifier: "en_US_POSIX")
            plain.timeZone = TimeZone(secondsFromGMT: 0)
            plain.dateFormat = "yyyy-MM-dd"
            if let d = plain.date(from: raw) { return d }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unrecognized date format: \(raw)"
            )
        }
        return d
    }()
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `xcodebuild test -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 15" -only-testing:Lumoria_AppTests/ResearchEntryDecodeTests`

Expected: PASS — both test cases.

- [ ] **Step 5: Commit**

```bash
git add "Lumoria App/services/research/ResearchEntry.swift" \
        "Lumoria AppTests/ResearchEntryDecodeTests.swift"
git commit -m "feat(research): add ResearchEntry Codable model + tag enum"
```

---

## Task 7: `ResearchStore` (load + active/past split)

**Files:**
- Create: `Lumoria App/services/research/ResearchStore.swift`
- Create: `Lumoria AppTests/ResearchStoreTests.swift`

- [ ] **Step 1: Write the failing test**

The store's main public surface besides `load()` is two computed lists. We test those — they're pure functions of `entries` + a clock, easy to assert without mocking Supabase.

Create `Lumoria AppTests/ResearchStoreTests.swift`:

```swift
import XCTest
@testable import Lumoria_App

@MainActor
final class ResearchStoreTests: XCTestCase {

    private func make(_ id: String, deadlineDaysFromNow: Int) -> ResearchEntry {
        let cal = Calendar(identifier: .gregorian)
        let deadline = cal.date(byAdding: .day, value: deadlineDaysFromNow, to: Date())!
        return ResearchEntry(
            id: UUID(uuidString: id)!,
            title: "Entry \(id)",
            description: "—",
            externalURL: URL(string: "https://example.com/\(id)")!,
            tag: .general,
            minimumParticipants: 1,
            deadline: deadline,
            publishedAt: Date()
        )
    }

    func test_active_includes_today_and_future_only() {
        let store = ResearchStore()
        store.replaceForTests(
            with: [
                make("11111111-1111-1111-1111-111111111111", deadlineDaysFromNow: -1),
                make("22222222-2222-2222-2222-222222222222", deadlineDaysFromNow:  0),
                make("33333333-3333-3333-3333-333333333333", deadlineDaysFromNow:  3),
            ]
        )

        let active = store.active(now: Date())
        XCTAssertEqual(active.map(\.id.uuidString.lowercased()),
                       ["22222222-2222-2222-2222-222222222222",
                        "33333333-3333-3333-3333-333333333333"])
    }

    func test_active_sorted_by_deadline_ascending() {
        let store = ResearchStore()
        store.replaceForTests(
            with: [
                make("33333333-3333-3333-3333-333333333333", deadlineDaysFromNow: 30),
                make("22222222-2222-2222-2222-222222222222", deadlineDaysFromNow:  3),
                make("11111111-1111-1111-1111-111111111111", deadlineDaysFromNow: 10),
            ]
        )

        let active = store.active(now: Date())
        XCTAssertEqual(active.map(\.title), ["Entry 22222222-2222-2222-2222-222222222222",
                                             "Entry 11111111-1111-1111-1111-111111111111",
                                             "Entry 33333333-3333-3333-3333-333333333333"])
    }

    func test_past_sorted_descending() {
        let store = ResearchStore()
        store.replaceForTests(
            with: [
                make("11111111-1111-1111-1111-111111111111", deadlineDaysFromNow: -10),
                make("22222222-2222-2222-2222-222222222222", deadlineDaysFromNow:  -2),
                make("33333333-3333-3333-3333-333333333333", deadlineDaysFromNow:   1),
            ]
        )

        let past = store.past(now: Date())
        XCTAssertEqual(past.map(\.id.uuidString.lowercased()),
                       ["22222222-2222-2222-2222-222222222222",
                        "11111111-1111-1111-1111-111111111111"])
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 15" -only-testing:Lumoria_AppTests/ResearchStoreTests`

Expected: FAIL — `Cannot find 'ResearchStore' in scope`.

- [ ] **Step 3: Implement the store**

Create `Lumoria App/services/research/ResearchStore.swift`:

```swift
//
//  ResearchStore.swift
//  Lumoria App
//
//  Holds the published research feed. The Active section shows entries
//  whose deadline is today or later; Past shows everything else. Loaded
//  on `.task` from the signed-in user's perspective — the
//  `research_entries_read_published` RLS policy already filters out
//  unpublished drafts.
//

import Combine
import Foundation
import Supabase
import SwiftUI

@MainActor
final class ResearchStore: ObservableObject {

    @Published private(set) var entries: [ResearchEntry] = []
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    nonisolated init() {}

    // MARK: - Load

    func load() async {
        guard supabase.auth.currentUser != nil else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let raw: Data = try await supabase
                .from("research_entries")
                .select()
                .order("deadline", ascending: true)
                .execute()
                .data

            entries = try ResearchEntry.decoder.decode([ResearchEntry].self, from: raw)
            errorMessage = nil
        } catch is CancellationError {
        } catch let error as URLError where error.code == .cancelled {
        } catch {
            errorMessage = String(localized: "Couldn't load research. \(error.localizedDescription)")
            print("[ResearchStore] load failed:", error)
            Analytics.track(.appError(domain: .notification, code: (error as NSError).code.description, viewContext: "ResearchStore.load"))
        }
    }

    // MARK: - Derived lists

    /// Active = deadline >= today, sorted ASC.
    func active(now: Date = Date()) -> [ResearchEntry] {
        let today = Calendar.current.startOfDay(for: now)
        return entries
            .filter { Calendar.current.startOfDay(for: $0.deadline) >= today }
            .sorted { $0.deadline < $1.deadline }
    }

    /// Past = deadline < today, sorted DESC.
    func past(now: Date = Date()) -> [ResearchEntry] {
        let today = Calendar.current.startOfDay(for: now)
        return entries
            .filter { Calendar.current.startOfDay(for: $0.deadline) < today }
            .sorted { $0.deadline > $1.deadline }
    }

    /// Used by the deep-link path to highlight the entry tapped from a push.
    func entry(id: UUID) -> ResearchEntry? {
        entries.first { $0.id == id }
    }

    // MARK: - Test seam

    func replaceForTests(with entries: [ResearchEntry]) {
        self.entries = entries
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `xcodebuild test -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 15" -only-testing:Lumoria_AppTests/ResearchStoreTests`

Expected: PASS — all three tests.

- [ ] **Step 5: Inject the store at the app root**

Open `Lumoria App/Lumoria_AppApp.swift`. Find the existing `@StateObject` declarations (e.g. `@StateObject var ticketsStore`, `@StateObject var entitlement`, etc.) and add:

```swift
@StateObject private var researchStore = ResearchStore()
```

In the same file, find where stores are injected into the environment via `.environmentObject(...)` chains. Add:

```swift
.environmentObject(researchStore)
```

right next to the other store injections.

- [ ] **Step 6: Commit**

```bash
git add "Lumoria App/services/research/ResearchStore.swift" \
        "Lumoria AppTests/ResearchStoreTests.swift" \
        "Lumoria App/Lumoria_AppApp.swift"
git commit -m "feat(research): add ResearchStore with active/past split and tests"
```

---

## Task 8: Extend `ProfileStore` with `participatesInResearch`

**Files:**
- Modify: `Lumoria App/views/settings/ProfileStore.swift`

- [ ] **Step 1: Add the published property + storage key**

Open `Lumoria App/views/settings/ProfileStore.swift`. After the `@Published private(set) var joinedDate: Date? = nil` line, add:

```swift
    /// Master toggle for the Research feed and its push notifications.
    /// Auto-true for early adopters via SQL trigger; default-false
    /// otherwise. Mirrored to @AppStorage("research.participates") for
    /// instant UI in `SettingsView` and `ResearchView`.
    @Published private(set) var participatesInResearch: Bool = false
```

Above `// MARK: - Load`, add:

```swift
    enum Keys {
        static let participatesInResearch = "research.participates"
    }
```

- [ ] **Step 2: Read the column on load**

Inside `load()`, after `joinedDate = user?.createdAt`, add a Supabase fetch:

```swift
        // Research participation flag — independent of auth metadata,
        // lives in `public.profiles`.
        if let userId = user?.id {
            struct ProfileFlags: Codable {
                let participatesInResearch: Bool
                enum CodingKeys: String, CodingKey {
                    case participatesInResearch = "participates_in_research"
                }
            }
            do {
                let rows: [ProfileFlags] = try await supabase
                    .from("profiles")
                    .select("participates_in_research")
                    .eq("user_id", value: userId)
                    .limit(1)
                    .execute()
                    .value
                let value = rows.first?.participatesInResearch ?? false
                participatesInResearch = value
                UserDefaults.standard.set(value, forKey: Keys.participatesInResearch)
            } catch is CancellationError {
            } catch let error as URLError where error.code == .cancelled {
            } catch {
                print("[ProfileStore] research flag load failed:", error)
            }
        }
```

- [ ] **Step 3: Add the setter**

At the bottom of the class, add:

```swift
    /// Flips the user's research participation flag locally and on the
    /// server. Optimistic — updates the published value + AppStorage
    /// before the round-trip so the toggle animation doesn't lag.
    func setParticipates(_ on: Bool) async {
        guard let userId = supabase.auth.currentUser?.id else { return }

        participatesInResearch = on
        UserDefaults.standard.set(on, forKey: Keys.participatesInResearch)

        do {
            try await supabase
                .from("profiles")
                .update(["participates_in_research": on])
                .eq("user_id", value: userId)
                .execute()
        } catch {
            print("[ProfileStore] research flag save failed:", error)
            Analytics.track(.appError(domain: .notification, code: (error as NSError).code.description, viewContext: "ProfileStore.setParticipates"))
        }
    }
```

- [ ] **Step 4: Build the app target**

Run from Xcode: ⌘B on the `Lumoria App` scheme.

Expected: build succeeds, no compiler errors.

- [ ] **Step 5: Commit**

```bash
git add "Lumoria App/views/settings/ProfileStore.swift"
git commit -m "feat(profile): expose participates_in_research on ProfileStore"
```

---

## Task 9: Add `.researchPublished` to `LumoriaNotification.Kind`

**Files:**
- Modify: `Lumoria App/views/notifications/Notification.swift`

- [ ] **Step 1: Extend the enum**

Open `Lumoria App/views/notifications/Notification.swift`. The existing enum:

```swift
    enum Kind: String, Hashable {
        case throwback
        case onboarding
        case news
        case link

        var eyebrow: String {
            switch self {
            case .throwback:  return "THROWBACK"
            case .onboarding: return "GET STARTED"
            case .news:       return "BRAND NEW"
            case .link:       return "INVITE A FRIEND"
            }
        }

        var backgroundColor: Color {
            switch self {
            case .throwback:  return Color(hex: "FFF6D1")
            case .onboarding: return Color(hex: "F8F1FF")
            case .news:       return Color(hex: "FFF0F7")
            case .link:       return Color(hex: "EBF7FF")
            }
        }
    }
```

Replace the body with:

```swift
    enum Kind: String, Hashable {
        case throwback
        case onboarding
        case news
        case link
        case researchPublished = "research_published"

        var eyebrow: String {
            switch self {
            case .throwback:         return "THROWBACK"
            case .onboarding:        return "GET STARTED"
            case .news:              return "BRAND NEW"
            case .link:              return "INVITE A FRIEND"
            case .researchPublished: return "RESEARCH"
            }
        }

        var backgroundColor: Color {
            switch self {
            case .throwback:         return Color(hex: "FFF6D1")
            case .onboarding:        return Color(hex: "F8F1FF")
            case .news:              return Color(hex: "FFF0F7")
            case .link:              return Color(hex: "EBF7FF")
            case .researchPublished: return Color(hex: "EAF2FF")
            }
        }
    }
```

- [ ] **Step 2: Add the optional research-entry payload**

Below the existing `var memoryId: UUID? = nil` and `var templateKind: TicketTemplateKind? = nil`, add:

```swift
    var researchEntryId: UUID? = nil
```

In the `init(...)` parameter list (after `templateKind`), add:

```swift
        researchEntryId: UUID? = nil
```

And inside the init body:

```swift
        self.researchEntryId = researchEntryId
```

- [ ] **Step 3: Build the app target**

Run from Xcode: ⌘B. Some sites construct `LumoriaNotification` (the `NotificationCard` previews, `NotificationsStore.toNotification`, `CollectionsView.routePush`) — they should still compile because the new param has a default value. If a switch-exhaustiveness error pops anywhere on `LumoriaNotification.Kind`, fix it by adding the new case.

Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/views/notifications/Notification.swift"
git commit -m "feat(notifications): add researchPublished kind + researchEntryId payload"
```

---

## Task 10: Push deep-link plumbing in `PushNotificationService`

**Files:**
- Modify: `Lumoria App/services/PushNotificationService.swift`

- [ ] **Step 1: Add a `Notification.Name` for the foreground signal**

At the very bottom of the file (after the `LumoriaAppDelegate` class), add:

```swift
extension Notification.Name {
    /// Posted from `willPresent` when a research_published push arrives
    /// while the app is foregrounded. ResearchView observes this and
    /// reloads its store so the new entry appears immediately.
    static let lumoriaResearchPublished = Notification.Name("lumoriaResearchPublished")
}
```

- [ ] **Step 2: Extend `DeepLink`**

Find the `struct DeepLink: Equatable` declaration (around line 165) and add a field:

```swift
    struct DeepLink: Equatable {
        let notificationId: UUID?
        let kind: LumoriaNotification.Kind
        let memoryId: UUID?
        let templateKind: TicketTemplateKind?
        let researchEntryId: UUID?
    }
```

- [ ] **Step 3: Read the new field in `ingestTappedPayload`**

Inside `ingestTappedPayload(_:)`, after the existing `templateKind` parse, add:

```swift
        let researchEntryId = (userInfo["research_entry_id"] as? String)
            .flatMap(UUID.init(uuidString:))
```

And update the `pendingDeepLink = DeepLink(...)` literal to include the new arg:

```swift
        pendingDeepLink = DeepLink(
            notificationId: notificationId,
            kind: kind,
            memoryId: memoryId,
            templateKind: templateKind,
            researchEntryId: researchEntryId
        )
```

- [ ] **Step 4: Map the kind for analytics**

Find the two switch statements that build `kindProp: NotificationKindProp`. Each currently maps `"throwback"`, `"onboarding"`, `"news"`, `"link"`. There is no analytics enum case for research yet — for V1, route research pushes to `.news`:

```swift
        let kindProp: NotificationKindProp = {
            switch kindRaw {
            case "throwback":          return .throwback
            case "onboarding":         return .onboarding
            case "news":               return .news
            case "link":               return .link
            case "research_published": return .news  // V1: bucket as news; add a dedicated prop later if needed
            default:                   return .news
            }
        }()
```

Apply this change to both `willPresent` and `didReceive`.

- [ ] **Step 5: Post the foreground signal**

Inside `willPresent`, in the existing `Task { @MainActor in ... }` block, after `Analytics.track(.pushReceived(...))`, add:

```swift
            if kindRaw == "research_published" {
                NotificationCenter.default.post(name: .lumoriaResearchPublished, object: nil)
            }
```

- [ ] **Step 6: Build the app target**

⌘B. Expected: build succeeds. If `CollectionsView.routePush` constructs a `DeepLink` literal explicitly somewhere (it does — around line 363), Xcode will complain about the missing arg — Task 11 fixes that. If you want the build green between tasks, add `researchEntryId: nil` to that one site now.

- [ ] **Step 7: Commit**

```bash
git add "Lumoria App/services/PushNotificationService.swift"
git commit -m "feat(push): research_published deep-link payload + foreground signal"
```

---

## Task 11: Route research push to Settings tab + scroll target

**Files:**
- Modify: `Lumoria App/views/collections/CollectionsView.swift`
- Modify: `Lumoria App/ContentView.swift`
- Modify: `Lumoria App/views/settings/SettingsView.swift`

The routing pattern in this codebase is: `ContentView` holds `@State private var selectedTab: Int`, and other routers (`widgetRouter.pendingMemoryId`, `onboardingCoordinator.showWelcome`, etc.) flip the tab via `.onChange(of:)`. We mirror that pattern: `PushNotificationService.pendingDeepLink` already exists and is observable; `ContentView` will switch to the Settings tab when a research deep-link arrives, `SettingsView` will then auto-push `ResearchView`, and `ResearchView` reads the entry id to scroll to.

- [ ] **Step 1: `CollectionsView.route(_:)` — research case**

Find the `route(_:)` method (around line 290). Replace its switch with:

```swift
    private func route(_ notification: LumoriaNotification) {
        switch notification.kind {
        case .throwback:
            if let id = notification.memoryId,
               let memory = store.memories.first(where: { $0.id == id }) {
                navigationPath.append(memory)
            }
        case .onboarding:
            presentNewTicketOrPaywall()
        case .news:
            activeTemplateKind = notification.templateKind ?? .express
        case .link:
            presentNewMemoryOrPaywall()
        case .researchPublished:
            // No-op here — ContentView watches the same DeepLink and
            // switches to the Settings tab; SettingsView auto-pushes
            // ResearchView with the entry id.
            break
        }
    }
```

- [ ] **Step 2: `CollectionsView.routePush(_:)` — pass the new field**

Find `routePush(_:)` (around line 362). Replace the temp construction with:

```swift
    private func routePush(_ link: PushNotificationService.DeepLink) {
        let temp = LumoriaNotification(
            id: link.notificationId ?? UUID(),
            kind: link.kind,
            title: "",
            message: "",
            createdAt: Date(),
            isRead: true,
            memoryId: link.memoryId,
            templateKind: link.templateKind,
            researchEntryId: link.researchEntryId
        )
        Task { await notificationsStore.load() }
        route(temp)
    }
```

- [ ] **Step 3: `ContentView` — switch to Settings tab on research push**

Open `Lumoria App/ContentView.swift`. Inject the push service near the other `@EnvironmentObject` declarations:

```swift
    @EnvironmentObject private var pushService: PushNotificationService
```

(If it's already there under a different name, reuse that.)

After the existing `.onChange(of: widgetRouter.pendingMemoryId)` block (around line 180), add:

```swift
        .onChange(of: pushService.pendingDeepLink) { _, link in
            guard let link, link.kind == .researchPublished else { return }
            selectedTab = 2 // Settings
        }
```

The Settings tab index is `2` (per the existing `Tab(...value: 2)` for SettingsView at line 60).

- [ ] **Step 4: `Lumoria_AppApp.swift` — make sure `pushService` is in env**

`PushNotificationService.shared` exists, but it must be exposed as an `@EnvironmentObject` for `ContentView` to read. Search the app file for an `@StateObject` of `PushNotificationService` or an `.environmentObject(PushNotificationService.shared)` chain. If neither exists, add:

```swift
@StateObject private var pushService = PushNotificationService.shared
// …
.environmentObject(pushService)
```

near the other store injections.

- [ ] **Step 5: `SettingsView` — auto-push `ResearchView` on deep-link arrival**

Open `Lumoria App/views/settings/SettingsView.swift`. Find the existing `NavigationStack` (or `NavigationView`). At the SettingsView's root, add:

```swift
    @EnvironmentObject private var pushService: PushNotificationService
    @State private var researchDeepLinkPath: [UUID] = []
```

Wrap (or extend) the existing settings list inside a `NavigationStack(path: $researchDeepLinkPath)`. The Research disclosure row from Task 13 already uses a plain `NavigationLink`; this step adds programmatic push for the deep-link path.

Add the value-based destination at the bottom of the stack body:

```swift
        .navigationDestination(for: UUID.self) { entryId in
            ResearchView(pendingEntryId: entryId)
        }
        .onChange(of: pushService.pendingDeepLink) { _, link in
            guard let link,
                  link.kind == .researchPublished,
                  let entryId = link.researchEntryId
            else { return }
            researchDeepLinkPath = [entryId]
            // Clear the deep link so a second tap on the same push
            // triggers the same flow again.
            pushService.pendingDeepLink = nil
        }
```

If the existing settings tree uses `NavigationLink { ResearchView() }` (string-based, not value-based), it can stay — `navigationDestination(for: UUID.self)` only intercepts the programmatic push from `researchDeepLinkPath`.

- [ ] **Step 6: Build the app target**

⌘B. Expected: build succeeds. If a switch-exhaustiveness warning fires elsewhere on `LumoriaNotification.Kind`, add a sensible default for the new case.

- [ ] **Step 7: Commit**

```bash
git add "Lumoria App/views/collections/CollectionsView.swift" \
        "Lumoria App/ContentView.swift" \
        "Lumoria App/views/settings/SettingsView.swift" \
        "Lumoria App/Lumoria_AppApp.swift"
git commit -m "feat(routing): research_published push switches to Settings + pushes ResearchView"
```

---

## Task 12: Rewrite `ResearchView`

**Files:**
- Modify: `Lumoria App/views/settings/ResearchView.swift`

This is the largest UI task. We add: top participation card, Active section, Past disclosure, ResearchEntry card, deep-link scroll, foreground reload signal.

- [ ] **Step 1: Replace the file**

Open `Lumoria App/views/settings/ResearchView.swift` and replace its entire contents with:

```swift
//
//  ResearchView.swift
//  Lumoria App
//
//  Live list of research initiatives. Top of the page hosts the master
//  "Participate in research" toggle. Below it: an Active section sorted
//  by deadline ASC, then a Past disclosure with closed entries.
//

import SwiftUI

struct ResearchView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var researchStore: ResearchStore
    @EnvironmentObject private var profileStore: ProfileStore

    /// Optional id forwarded from a push tap. When set on appear, we
    /// scroll the active list to that entry. Cleared after the scroll.
    var pendingEntryId: UUID? = nil

    @State private var pastExpanded: Bool = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Research")
                        .font(.largeTitle.bold())
                        .foregroundStyle(Color.Text.primary)

                    participationCard

                    if researchStore.active().isEmpty && researchStore.past().isEmpty {
                        emptyState
                    } else {
                        activeSection(proxy: proxy)
                        if !researchStore.past().isEmpty {
                            pastSection
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color.Background.default.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack {
                    LumoriaIconButton(systemImage: "arrow.left") { dismiss() }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
            .task {
                await researchStore.load()
                if let target = pendingEntryId {
                    // Wait one runloop so the SwiftUI ids resolve before scrolling.
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    withAnimation { proxy.scrollTo(target, anchor: .top) }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .lumoriaResearchPublished)) { _ in
                Task { await researchStore.load() }
            }
            .onAppear {
                for entry in researchStore.active() {
                    Analytics.track(.researchEntryViewed(entryId: entry.id, tag: entry.tag.rawValue))
                }
            }
        }
    }

    // MARK: - Participation card

    private var participationCard: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Participate in research")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.Text.primary)

                Text("Help shape Lumoria. Get notified when new studies open.")
                    .font(.subheadline)
                    .foregroundStyle(Color.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("", isOn: Binding(
                get: { profileStore.participatesInResearch },
                set: { newValue in
                    Analytics.track(.researchParticipationToggled(enabled: newValue, source: "research_page"))
                    Task { await profileStore.setParticipates(newValue) }
                }
            ))
            .labelsHidden()
            .tint(Color("Colors/Green/500"))
            .sensoryFeedback(.impact(weight: .light), trigger: profileStore.participatesInResearch)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.Background.elevated)
        )
    }

    // MARK: - Active section

    @ViewBuilder
    private func activeSection(proxy: ScrollViewProxy) -> some View {
        let active = researchStore.active()
        if !active.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Active")
                    .font(.title3.bold())
                    .foregroundStyle(Color.Text.primary)

                VStack(spacing: 12) {
                    ForEach(active) { entry in
                        ResearchEntryCard(entry: entry, isClosed: false)
                            .id(entry.id)
                    }
                }
            }
        }
    }

    // MARK: - Past section

    private var pastSection: some View {
        DisclosureGroup(isExpanded: $pastExpanded) {
            VStack(spacing: 12) {
                ForEach(researchStore.past()) { entry in
                    ResearchEntryCard(entry: entry, isClosed: true)
                        .id(entry.id)
                }
            }
            .padding(.top, 12)
        } label: {
            Text("Past research")
                .font(.title3.bold())
                .foregroundStyle(Color.Text.primary)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(Color.Text.tertiary)
                .padding(.top, 24)

            Text("No active research")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.Text.primary)

            Text("Surveys and interview invites land here when the team is collecting feedback. Quiet for now.")
                .font(.body)
                .foregroundStyle(Color.Text.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.Background.elevated)
        )
    }
}

// MARK: - ResearchEntryCard

private struct ResearchEntryCard: View {
    let entry: ResearchEntry
    let isClosed: Bool

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(entry.tag.rawValue.uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(Color.Text.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(Color.Background.elevated.opacity(0.6))
                    )
                Spacer()
            }

            Text(entry.title)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.Text.primary)

            Text(entry.description)
                .font(.subheadline)
                .foregroundStyle(Color.Text.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Text(footerText)
                .font(.footnote)
                .foregroundStyle(Color.Text.tertiary)

            if isClosed {
                Text("Closed")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.Text.tertiary)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.Background.elevated)
                    )
            } else {
                Button {
                    Analytics.track(.researchEntryOpened(entryId: entry.id, tag: entry.tag.rawValue))
                    openURL(entry.externalURL)
                } label: {
                    Text("Open research")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.Text.primary)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.Background.elevated)
                .opacity(isClosed ? 0.6 : 1)
        )
    }

    private var footerText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let deadline = formatter.string(from: entry.deadline)
        return "Looking for at least \(entry.minimumParticipants) participants · Closes \(deadline)"
    }
}

#if DEBUG
#Preview {
    NavigationStack { ResearchView() }
        .environmentObject(ResearchStore())
        .environmentObject(ProfileStore())
}
#endif
```

- [ ] **Step 2: Build the app target**

⌘B. Expected: build succeeds. (If `Color.Background.default` / `Color.Text.primary` / `LumoriaIconButton` are not found, search the project for the existing equivalents — they are defined in the design-system extension files.)

- [ ] **Step 3: Manual smoke (visual)**

Run on a simulator. Sign in as a test user. Navigate Settings → Research. Expected: top toggle card visible, empty-state below if no rows.

In Studio insert a draft + publish for the test user and reopen the page. Expected: card shows up under Active.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/views/settings/ResearchView.swift"
git commit -m "feat(research): live list with active/past sections and master toggle"
```

---

## Task 13: Settings — new "Research" section

**Files:**
- Modify: `Lumoria App/views/settings/SettingsView.swift`

- [ ] **Step 1: Find the existing Research row**

Open `Lumoria App/views/settings/SettingsView.swift`. Search for `.isEarlyAdopter` (line ~60) — that's the existing gate around the Research disclosure row.

The current shape (paraphrased):

```swift
if entitlement.isEarlyAdopter {
    NavigationLink {
        ResearchView()
    } label: {
        // existing row label
    }
}
```

- [ ] **Step 2: Replace the gate and add the master toggle**

Replace that `if entitlement.isEarlyAdopter { ... }` block with a Section that always renders the master toggle and conditionally renders the disclosure row:

```swift
Section {
    HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
            Text("Participate in research")
                .font(.body)
                .foregroundStyle(Color.Text.primary)
            Text("Help shape Lumoria. Get notified when new studies open.")
                .font(.subheadline)
                .foregroundStyle(Color.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Toggle("", isOn: Binding(
            get: { profileStore.participatesInResearch },
            set: { newValue in
                Analytics.track(.researchParticipationToggled(enabled: newValue, source: "settings"))
                Task { await profileStore.setParticipates(newValue) }
            }
        ))
        .labelsHidden()
        .tint(Color("Colors/Green/500"))
    }
    .padding(.vertical, 4)

    if entitlement.isEarlyAdopter || profileStore.participatesInResearch {
        NavigationLink {
            ResearchView()
        } label: {
            Label("Research", systemImage: "doc.text.magnifyingglass")
                .foregroundStyle(Color.Text.primary)
        }
    }
} header: {
    Text("Research")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Color.Text.secondary)
}
```

If the existing settings file uses a different cell layout (custom `LumoriaSettingsRow`, etc.), match its style — the contract is "always-visible toggle row + conditionally-visible disclosure row inside one section".

- [ ] **Step 3: Confirm `profileStore` is in scope**

Look near the top of `SettingsView` for `@EnvironmentObject private var profileStore: ProfileStore`. If it's not there, add it. The store is already injected in `Lumoria_AppApp.swift`.

- [ ] **Step 4: Build the app target**

⌘B. Expected: build succeeds.

- [ ] **Step 5: Manual smoke**

Run on a simulator with a non-EA test account. Settings → Research section visible at the top toggle row, no disclosure. Flip toggle on → disclosure appears, opens the live ResearchView. Toggle off → disclosure disappears.

Sign in as an EA test account. Same Settings tab. Toggle is on by default; disclosure is visible from the start.

- [ ] **Step 6: Commit**

```bash
git add "Lumoria App/views/settings/SettingsView.swift"
git commit -m "feat(settings): add Research section with master toggle"
```

---

## Task 14: Analytics events

**Files:**
- Modify: `Lumoria App/services/analytics/AnalyticsEvent.swift`
- Modify: `Lumoria App/services/analytics/AnalyticsMappers.swift`

- [ ] **Step 1: Add the cases to the enum**

Open `Lumoria App/services/analytics/AnalyticsEvent.swift`. Find the `// MARK: — Retention` (or the section closest to "research" semantically — if there isn't one, add a new MARK at the bottom of the enum):

```swift
    // MARK: — Research

    case researchEntryViewed(entryId: UUID, tag: String)
    case researchEntryOpened(entryId: UUID, tag: String)
    case researchParticipationToggled(enabled: Bool, source: String)
```

- [ ] **Step 2: Map them in `AnalyticsMappers.swift`**

Open `Lumoria App/services/analytics/AnalyticsMappers.swift`. Find the giant switch on `AnalyticsEvent`. Add three cases that match the existing mapping style — the engineer should look at `case .pushReceived` and adapt. Concretely:

```swift
case .researchEntryViewed(let entryId, let tag):
    return AnalyticsPayload(
        name: "research_entry_viewed",
        properties: [
            "entry_id": entryId.uuidString,
            "tag":      tag,
        ]
    )

case .researchEntryOpened(let entryId, let tag):
    return AnalyticsPayload(
        name: "research_entry_opened",
        properties: [
            "entry_id": entryId.uuidString,
            "tag":      tag,
        ]
    )

case .researchParticipationToggled(let enabled, let source):
    return AnalyticsPayload(
        name: "research_participation_toggled",
        properties: [
            "enabled": enabled,
            "source":  source,
        ]
    )
```

Adjust the wrapping struct/syntax (`AnalyticsPayload`, `track(name:properties:)`, etc.) to match what the rest of the file uses — the existing file is the source of truth.

- [ ] **Step 3: Build the app target**

⌘B. Expected: build succeeds, all `Analytics.track(.research…)` calls in earlier tasks now resolve.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/services/analytics/AnalyticsEvent.swift" \
        "Lumoria App/services/analytics/AnalyticsMappers.swift"
git commit -m "feat(analytics): research entry viewed/opened + participation toggled"
```

---

## Task 15: Localization keys

**Files:**
- Modify: `Lumoria App/Localizable.xcstrings`

- [ ] **Step 1: Add keys**

Open `Lumoria App/Localizable.xcstrings` (Xcode renders it as a String Catalog). Add the following keys with their English strings:

| Key | English |
|---|---|
| `research.page.title` | `Research` |
| `research.section.active` | `Active` |
| `research.section.past` | `Past research` |
| `research.card.cta.open` | `Open research` |
| `research.card.cta.closed` | `Closed` |
| `research.empty.title` | `No active research` |
| `research.empty.body` | `Surveys and interview invites land here when the team is collecting feedback. Quiet for now.` |
| `research.toggle.title` | `Participate in research` |
| `research.toggle.subtitle` | `Help shape Lumoria. Get notified when new studies open.` |

Note: most copy in Task 12 / 13 is currently inlined as raw `String`s. The intention here is to register the keys so future localization work can reference them; runtime fallback to the inline text is fine for V1.

- [ ] **Step 2: Build the app target**

⌘B. Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add "Lumoria App/Localizable.xcstrings"
git commit -m "i18n(research): register research page string keys"
```

---

## Task 16: Changelog entry

**Files:**
- Create: `lumoria/src/content/changelog/2026-05-07-research-page.mdx`

- [ ] **Step 1: Create the changelog file**

Memory `feedback_changelog_mdx` says every shipped change adds a `.mdx` file with **JS-export frontmatter** (not YAML). Look at an existing entry under `lumoria/src/content/changelog/` to mirror the exact frontmatter shape, then write:

```mdx
export const frontmatter = {
  title: "Research initiatives, in your pocket",
  date: "2026-05-07",
  tag: "Feature",
};

We can now publish research initiatives directly into Lumoria. Early adopters are auto-enrolled and notified when a new study opens; everyone else can opt in via Settings → Research → "Participate in research". Each entry shows the topic, a short brief, the deadline, and a button that hands you off to the form.
```

If your existing changelog entries use a different frontmatter key set, mirror those instead — this body is just the prose.

- [ ] **Step 2: Commit**

```bash
git add lumoria/src/content/changelog/2026-05-07-research-page.mdx
git commit -m "docs(changelog): research initiatives are now publishable from Supabase"
```

---

## Task 17: End-to-end manual smoke

This is the verification gate — no code, just steps. Run all of these on a TestFlight (or sandbox) build with two test accounts: one EA, one regular.

- [ ] **Step 1: Eligibility default**

- Sign in as the EA account on a clean install. Open Settings.
- Expected: "Research" section visible. "Participate in research" toggle ON. Disclosure row visible. Tap it → live ResearchView shows the toggle ON inside the page.
- Sign in as the regular account on a clean install. Open Settings.
- Expected: "Research" section visible. Toggle OFF. No disclosure row. Toggle on → disclosure appears.

- [ ] **Step 2: Publish flow**

- In Studio: insert a draft entry (`is_published = false`), then `select publish_research_entry('<id>')`.
- Expected: RPC returns ≥ 2 (one notifications row per opted-in test account).
- Both test devices receive an APNs push titled "New research opening" with the entry's title as the body.

- [ ] **Step 3: Tap deep-link**

- Tap the push on the EA device.
- Expected: app opens, navigates to Settings tab, pushes ResearchView, scrolls to the new entry.

- [ ] **Step 4: Open the form**

- Tap "Open research" on the card.
- Expected: Safari opens the `external_url`. Analytics fires `research_entry_opened`.

- [ ] **Step 5: Past behavior**

- Update the entry's `deadline` to yesterday in Studio.
- Pull-to-refresh ResearchView (or kill + reopen the app).
- Expected: entry moved into Past research disclosure. Card dimmed; `Closed` badge in place of CTA.

- [ ] **Step 6: Opt-out**

- On the regular account, flip "Participate in research" off.
- Publish another entry in Studio.
- Expected: that account does NOT receive a push. Open ResearchView — disclosure no longer appears in Settings (toggle off hid it).

- [ ] **Step 7: Idempotency guard**

- In Studio: `select public.publish_research_entry('<same-id>');` again.
- Expected: returns `0`. No duplicate notifications inserted (verify with `select count(*) from notifications where research_entry_id = '<id>';`).

When all 7 pass, the feature is ready to ship.

---

## Self-review trace

| Spec section | Implementing task(s) |
|---|---|
| `research_entries` table + RLS | 1 |
| `participates_in_research` column + EA backfill + grant-path patches | 2 |
| `notifications.kind` widening + `research_entry_id` column | 3 |
| `publish_research_entry()` RPC | 4 |
| `send-push` edge function | 5 |
| `ResearchEntry` / `ResearchTag` Codable | 6 |
| `ResearchStore` | 7 |
| `ProfileStore.participatesInResearch` | 8 |
| `LumoriaNotification.Kind.researchPublished` | 9 |
| `PushNotificationService` deep-link | 10 |
| `CollectionsView` routing | 11 |
| `ResearchView` rewrite (toggle + Active + Past + card) | 12 |
| `SettingsView` Research section | 13 |
| Analytics (3 events + mappers) | 14 |
| Localization keys | 15 |
| Changelog entry | 16 |
| Manual smoke (EA, regular, opt-out, idempotency) | 17 |
