# Memory Ticket Sort Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a per-memory sort sheet (3 fields × asc/desc) to `MemoryDetailView`, persisted to Supabase, with a real `event_date` column on tickets so sort-by-event-date is exact rather than parsed-from-localized-strings.

**Architecture:**
- Add an encrypted `event_date_enc` column on `public.tickets` (matches existing `MemoryDateCodec` pattern). Surface an optional `Date` on `Ticket` and write it from each funnel's canonical date field on create + update.
- Add unencrypted `sort_field text` + `sort_ascending bool` columns on `public.memories`. Surface as `Memory.sortField: MemorySortField` + `Memory.sortAscending: Bool`. Default `'date_added'` ascending (oldest-first).
- Surface `memory_tickets.added_at` (already in DB) on the embedded `MemoryTicketLink` and propagate as `Ticket.addedAtByMemory: [UUID: Date]`.
- Pure `MemorySortApplier` orders `[Ticket]` by `(field, ascending, memoryId)`. Nils bucket last regardless of direction.
- New `MemorySortSheet` (bottom sheet matching Figma 2028-143016) bound to memory's `(sortField, sortAscending)`. Triggered from a new "Sort…" item in the memory detail's ellipsis menu (Figma 1017-24964).

**Tech Stack:** Swift / SwiftUI · Supabase Postgres · Swift Testing (`import Testing`) · existing AES-GCM `EncryptionService` + `MemoryDateCodec`.

---

## File Structure

**Created**
- `supabase/migrations/20260512000000_ticket_event_date.sql` — adds `event_date_enc`.
- `supabase/migrations/20260512000001_memory_sort_prefs.sql` — adds `sort_field` + `sort_ascending`.
- `Lumoria App/views/collections/MemorySortField.swift` — sort enum + display labels.
- `Lumoria App/views/collections/MemorySortApplier.swift` — pure sort function.
- `Lumoria App/views/collections/MemorySortSheet.swift` — bottom sheet UI.
- `Lumoria AppTests/MemorySortApplierTests.swift` — pure-logic tests.
- `Lumoria AppTests/TicketEventDateCodecTests.swift` — round-trip codable test.

**Modified**
- `Lumoria App/views/tickets/Ticket.swift` — add `eventDate`, `addedAtByMemory`.
- `Lumoria App/views/tickets/TicketRow.swift` — surface `event_date_enc` + `added_at`.
- `Lumoria App/views/tickets/TicketsStore.swift` — pass eventDate through create/update; expose addedAt-by-memory.
- `Lumoria App/views/collections/Collection.swift` — add `sortField` + `sortAscending` to `Memory`, `MemoryRow`, `UpdateMemoryPayload`.
- `Lumoria App/views/collections/CollectionsStore.swift` — `updateSort(memoryId:field:ascending:)`.
- `Lumoria App/views/tickets/new/NewTicketFunnel.swift` — read `currentEventDate` per template; pass to create + buildUpdatedTicket.
- `Lumoria App/views/collections/CollectionDetailView.swift` — Sort menu item, sheet presentation, sorted tickets, animation.
- `Lumoria App/Localizable.xcstrings` — strings for sort sheet.

---

## Pre-flight

This plan touches DB schema and persisted models. Run on `main` once the previous merge is in. No worktree required for the migrations; UI work can be done on a feature branch.

Branch: `feat/memory-ticket-sort`.

---

### Task 1: Migration — `tickets.event_date_enc`

**Files:**
- Create: `supabase/migrations/20260512000000_ticket_event_date.sql`

- [ ] **Step 1: Write migration**

```sql
-- Adds an optional encrypted ISO-8601 event date for client-side sorting
-- in MemoryDetailView. Ciphertext shape matches `memories.start_date_enc`
-- (AES-GCM-256, base64) — see Lumoria App/services/security/MemoryDateCodec.swift.
alter table public.tickets
    add column event_date_enc text null;

comment on column public.tickets.event_date_enc is
    'AES-GCM-256 base64 ciphertext of the ISO-8601 event date (departure for journey templates, single date for venue templates). Optional. Used for client-side sort in MemoryDetailView.';
```

- [ ] **Step 2: Apply locally**

```bash
cd "/Users/bearista/Documents/lumoria/Lumoria App"
supabase db reset --local
```
Expected: migration applies cleanly; `\d public.tickets` shows `event_date_enc text` nullable.

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260512000000_ticket_event_date.sql
git commit -m "feat(db): add tickets.event_date_enc for sort"
```

---

### Task 2: Migration — `memories` sort prefs

**Files:**
- Create: `supabase/migrations/20260512000001_memory_sort_prefs.sql`

- [ ] **Step 1: Write migration**

```sql
-- Per-memory sort preference for MemoryDetailView. Plain columns (non-
-- sensitive metadata, like `color_family`). Defaults match the app-side
-- default: oldest-first by date the ticket was added to the memory.
alter table public.memories
    add column sort_field      text not null default 'date_added',
    add column sort_ascending  boolean not null default true;

-- Sort field is one of three known values; reject typos at the DB.
alter table public.memories
    add constraint memories_sort_field_check
    check (sort_field in ('date_added', 'event_date', 'date_created'));
```

- [ ] **Step 2: Apply locally**

```bash
cd "/Users/bearista/Documents/lumoria/Lumoria App"
supabase db reset --local
```
Expected: clean apply; existing memories rows backfilled to defaults.

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260512000001_memory_sort_prefs.sql
git commit -m "feat(db): add memory sort_field + sort_ascending"
```

---

### Task 3: `MemorySortField` enum

**Files:**
- Create: `Lumoria App/views/collections/MemorySortField.swift`

- [ ] **Step 1: Write enum**

```swift
//
//  MemorySortField.swift
//  Lumoria App
//
//  Per-memory sort preference. Raw values match the
//  `memories.sort_field` column constraint.
//

import Foundation

enum MemorySortField: String, CaseIterable, Identifiable, Codable {
    case dateAdded   = "date_added"
    case eventDate   = "event_date"
    case dateCreated = "date_created"

    var id: String { rawValue }

    /// Title shown in the sort sheet's radio list.
    var title: String {
        switch self {
        case .dateAdded:   return String(localized: "Date added to memory")
        case .eventDate:   return String(localized: "Date of the event")
        case .dateCreated: return String(localized: "Date the ticket was created")
        }
    }
}
```

- [ ] **Step 2: Add file to Xcode project**

Open `Lumoria App.xcodeproj`, drag `MemorySortField.swift` into `views/collections/` group, add to the `Lumoria App` target.

- [ ] **Step 3: Build to verify**

```bash
xcodebuild -scheme "Lumoria App" -destination 'platform=iOS Simulator,name=iPhone 15' build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/views/collections/MemorySortField.swift" "Lumoria App.xcodeproj/project.pbxproj"
git commit -m "feat(memory): add MemorySortField enum"
```

---

### Task 4: Extend `Memory` model + row + payloads with sort prefs

**Files:**
- Modify: `Lumoria App/views/collections/Collection.swift`

- [ ] **Step 1: Add fields to `Memory`**

In `Lumoria App/views/collections/Collection.swift`, locate the `struct Memory: Identifiable, Hashable` block (around line 17). Replace it with:

```swift
struct Memory: Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    var name: String
    var colorFamily: String
    var emoji: String?
    /// Optional span of the memory. Used for the Journey Wrap stats and the
    /// Map timeline's date rail. Falls back to the earliest / latest ticket
    /// date when nil.
    var startDate: Date?
    var endDate: Date?
    /// Per-memory sort preference for `MemoryDetailView`. Defaults to
    /// `.dateAdded` ascending (oldest added first) so the user's first-
    /// added tickets sit at the top.
    var sortField: MemorySortField
    var sortAscending: Bool
    let createdAt: Date
    let updatedAt: Date

    /// Matches a stored `color_family` to a `ColorOption` from the palette.
    var colorOption: ColorOption? {
        ColorOption.all.first { $0.family == colorFamily }
    }
}
```

- [ ] **Step 2: Extend `MemoryRow` decode**

Replace the `struct MemoryRow: Decodable` block (around line 41) with:

```swift
struct MemoryRow: Decodable {
    let id: UUID
    let userId: UUID
    let name: String
    let colorFamily: String
    let emojiEnc: String?
    let startDateEnc: String?
    let endDateEnc: String?
    let sortField: String?
    let sortAscending: Bool?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name
        case userId        = "user_id"
        case colorFamily   = "color_family"
        case emojiEnc      = "emoji_enc"
        case startDateEnc  = "start_date_enc"
        case endDateEnc    = "end_date_enc"
        case sortField     = "sort_field"
        case sortAscending = "sort_ascending"
        case createdAt     = "created_at"
        case updatedAt     = "updated_at"
    }

    func toMemory() throws -> Memory {
        let decryptedName  = try EncryptionService.decryptString(name)
        let decryptedEmoji = try emojiEnc.map { try EncryptionService.decryptString($0) }
        let decryptedStart = try startDateEnc.map { try MemoryDateCodec.decrypt($0) }
        let decryptedEnd   = try endDateEnc.map   { try MemoryDateCodec.decrypt($0) }

        // Treat unknown sort_field strings as the default. Optional from
        // the row so older rows that predate the column still decode.
        let resolvedField = sortField
            .flatMap(MemorySortField.init(rawValue:))
            ?? .dateAdded

        return Memory(
            id: id,
            userId: userId,
            name: decryptedName,
            colorFamily: colorFamily,
            emoji: decryptedEmoji,
            startDate: decryptedStart,
            endDate: decryptedEnd,
            sortField: resolvedField,
            sortAscending: sortAscending ?? true,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
```

- [ ] **Step 3: Extend `NewMemoryPayload` with defaults**

Replace the `struct NewMemoryPayload: Encodable` block (around line 111) with:

```swift
struct NewMemoryPayload: Encodable {
    let userId: UUID
    let name: String
    let colorFamily: String
    let emojiEnc: String?
    let startDateEnc: String?
    let endDateEnc: String?

    enum CodingKeys: String, CodingKey {
        case userId       = "user_id"
        case name
        case colorFamily  = "color_family"
        case emojiEnc     = "emoji_enc"
        case startDateEnc = "start_date_enc"
        case endDateEnc   = "end_date_enc"
    }

    static func make(
        userId: UUID,
        name: String,
        colorFamily: String,
        emoji: String?,
        startDate: Date?,
        endDate: Date?
    ) throws -> NewMemoryPayload {
        let encryptedName  = try EncryptionService.encryptString(name)
        let encryptedEmoji = try emoji.map { try EncryptionService.encryptString($0) }
        let encryptedStart = try startDate.map { try MemoryDateCodec.encrypt($0) }
        let encryptedEnd   = try endDate.map   { try MemoryDateCodec.encrypt($0) }
        return NewMemoryPayload(
            userId: userId,
            name: encryptedName,
            colorFamily: colorFamily,
            emojiEnc: encryptedEmoji,
            startDateEnc: encryptedStart,
            endDateEnc: encryptedEnd
        )
    }
}
```

(No new fields here — DB defaults handle initial values.)

- [ ] **Step 4: Add `UpdateMemorySortPayload`**

Append to `Collection.swift` after `UpdateMemoryPayload` (around line 197):

```swift
/// Payload for the dedicated sort-pref update path. Kept separate from
/// `UpdateMemoryPayload` so the sort sheet doesn't need to round-trip the
/// encrypted name / emoji / dates just to flip a flag.
struct UpdateMemorySortPayload: Encodable {
    let sortField: String
    let sortAscending: Bool

    enum CodingKeys: String, CodingKey {
        case sortField     = "sort_field"
        case sortAscending = "sort_ascending"
    }
}
```

- [ ] **Step 5: Build**

```bash
xcodebuild -scheme "Lumoria App" -destination 'platform=iOS Simulator,name=iPhone 15' build 2>&1 | tail -10
```
Expected: BUILD SUCCEEDED. (Compile errors will surface in `MemoriesStore` for missing init args — fixed in Task 5.)

If errors remain only inside `MemoriesStore`, that is expected; proceed to Task 5.

- [ ] **Step 6: Commit**

```bash
git add "Lumoria App/views/collections/Collection.swift"
git commit -m "feat(memory): add sort_field + sort_ascending to model"
```

---

### Task 5: `MemoriesStore.updateSort`

**Files:**
- Modify: `Lumoria App/views/collections/CollectionsStore.swift`

- [ ] **Step 1: Wire `Memory.init` callsites**

In `CollectionsStore.swift`, locate every place that constructs a `Memory` directly. The store updates an existing `Memory` value at lines ~181-189 (`update`) — that path mutates fields, not the initializer, so no change is needed for sort defaults there.

`MemoryRow.toMemory()` is already updated in Task 4. The DB defaults supply `sort_field='date_added'` and `sort_ascending=true` for new rows, so `create()` does not need new arguments.

- [ ] **Step 2: Add `updateSort`**

Append to `MemoriesStore` (after the existing `update(_:name:colorFamily:emoji:startDate:endDate:)` method, before `delete`):

```swift
    /// Persists a per-memory sort preference. Optimistic local update so
    /// the sheet feels instant; rolls back on Supabase failure.
    func updateSort(
        memoryId: UUID,
        field: MemorySortField,
        ascending: Bool
    ) async {
        guard let idx = memories.firstIndex(where: { $0.id == memoryId }) else { return }
        let prevField = memories[idx].sortField
        let prevAsc   = memories[idx].sortAscending

        memories[idx].sortField     = field
        memories[idx].sortAscending = ascending

        let payload = UpdateMemorySortPayload(
            sortField: field.rawValue,
            sortAscending: ascending
        )

        do {
            try await supabase
                .from("memories")
                .update(payload)
                .eq("id", value: memoryId.uuidString)
                .execute()
            errorMessage = nil
        } catch {
            // Roll back if the network failed.
            if let idx = memories.firstIndex(where: { $0.id == memoryId }) {
                memories[idx].sortField     = prevField
                memories[idx].sortAscending = prevAsc
            }
            errorMessage = String(localized: "Couldn’t save sort. \(error.localizedDescription)")
            print("[MemoriesStore] updateSort failed:", error)
            Analytics.track(.appError(
                domain: .memory,
                code: (error as NSError).code.description,
                viewContext: "MemoriesStore.updateSort"
            ))
        }
    }
```

- [ ] **Step 3: Build**

```bash
xcodebuild -scheme "Lumoria App" -destination 'platform=iOS Simulator,name=iPhone 15' build 2>&1 | tail -10
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/views/collections/CollectionsStore.swift"
git commit -m "feat(memory): MemoriesStore.updateSort"
```

---

### Task 6: Extend `Ticket` model with `eventDate` + `addedAtByMemory`

**Files:**
- Modify: `Lumoria App/views/tickets/Ticket.swift`

- [ ] **Step 1: Add fields**

In `Ticket.swift`, replace the `struct Ticket: Identifiable, Hashable { ... }` block (lines 286-339) with:

```swift
struct Ticket: Identifiable, Hashable {
    let id: UUID
    var createdAt: Date
    var updatedAt: Date
    var orientation: TicketOrientation
    var payload: TicketPayload
    var memoryIds: [UUID]
    /// Primary location — single venue, or origin for a trip.
    var originLocation: TicketLocation?
    /// Destination for a trip (plane/train). Nil for single-venue templates.
    var destinationLocation: TicketLocation?
    /// Identifier of the chosen style variant from `TicketStyleCatalog`.
    var styleId: String?
    /// Canonical event date for sort-by-event in `MemoryDetailView`.
    /// Plane/train: departure. Concert/transit: the single date field.
    /// Nil for tickets created before the column existed.
    var eventDate: Date?
    /// When this ticket was added to each memory (memory_tickets.added_at).
    /// Sourced per row from the embedded junction; missing keys mean the
    /// embedded query did not return the row (e.g. ticket not in memory).
    var addedAtByMemory: [UUID: Date]

    var kind: TicketTemplateKind { payload.kind }

    var resolvedStyle: TicketStyleVariant { kind.resolveStyle(id: styleId) }

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        orientation: TicketOrientation,
        payload: TicketPayload,
        memoryIds: [UUID] = [],
        originLocation: TicketLocation? = nil,
        destinationLocation: TicketLocation? = nil,
        styleId: String? = nil,
        eventDate: Date? = nil,
        addedAtByMemory: [UUID: Date] = [:]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.orientation = orientation
        self.payload = payload
        self.memoryIds = memoryIds
        self.originLocation = originLocation
        self.destinationLocation = destinationLocation
        self.styleId = styleId
        self.eventDate = eventDate
        self.addedAtByMemory = addedAtByMemory
    }

    static func == (lhs: Ticket, rhs: Ticket) -> Bool {
        lhs.id == rhs.id && lhs.updatedAt == rhs.updatedAt
    }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
```

- [ ] **Step 2: Build (will fail in TicketRow / TicketsStore)**

```bash
xcodebuild -scheme "Lumoria App" -destination 'platform=iOS Simulator,name=iPhone 15' build 2>&1 | tail -10
```
Expected: errors only in `TicketRow.swift` (toTicket missing args) and possibly `TicketsStore.swift`. Continue to Task 7.

- [ ] **Step 3: Commit**

```bash
git add "Lumoria App/views/tickets/Ticket.swift"
git commit -m "feat(ticket): add eventDate + addedAtByMemory fields"
```

---

### Task 7: Round-trip `event_date_enc` + `added_at` through `TicketRow`

**Files:**
- Modify: `Lumoria App/views/tickets/TicketRow.swift`

- [ ] **Step 1: Extend `TicketRow`**

Replace the `struct TicketRow: Decodable { ... }` block (lines 23-47) with:

```swift
struct TicketRow: Decodable {
    let id: UUID
    let userId: UUID
    let templateKind: String
    let orientation: String
    let payload: AnyJSON
    let locationPrimaryEnc: String?
    let locationSecondaryEnc: String?
    let styleId: String?
    let eventDateEnc: String?
    let createdAt: Date
    let updatedAt: Date
    let memoryTickets: [MemoryTicketLink]?

    enum CodingKeys: String, CodingKey {
        case id, payload, orientation
        case userId               = "user_id"
        case templateKind         = "template_kind"
        case locationPrimaryEnc   = "location_primary_enc"
        case locationSecondaryEnc = "location_secondary_enc"
        case styleId              = "style_id"
        case eventDateEnc         = "event_date_enc"
        case createdAt            = "created_at"
        case updatedAt            = "updated_at"
        case memoryTickets        = "memory_tickets"
    }
}
```

- [ ] **Step 2: Extend `MemoryTicketLink`**

Replace the `struct MemoryTicketLink: Decodable { ... }` block (lines 52-58) with:

```swift
/// Single row of the `memory_tickets` junction, embedded when reading a
/// ticket. Carries the per-membership timestamp so the detail view can
/// sort by "date added to memory".
struct MemoryTicketLink: Decodable {
    let memoryId: UUID
    let addedAt: Date

    enum CodingKeys: String, CodingKey {
        case memoryId = "memory_id"
        case addedAt  = "added_at"
    }
}
```

- [ ] **Step 3: Extend `NewTicketRow`**

Replace the `struct NewTicketRow: Encodable { ... }` block (lines 63-80) with:

```swift
struct NewTicketRow: Encodable {
    let userId: UUID
    let templateKind: String
    let orientation: String
    let payload: AnyJSON
    let locationPrimaryEnc: String?
    let locationSecondaryEnc: String?
    let styleId: String?
    let eventDateEnc: String?

    enum CodingKeys: String, CodingKey {
        case userId               = "user_id"
        case templateKind         = "template_kind"
        case locationPrimaryEnc   = "location_primary_enc"
        case locationSecondaryEnc = "location_secondary_enc"
        case styleId              = "style_id"
        case eventDateEnc         = "event_date_enc"
        case orientation, payload
    }
}
```

- [ ] **Step 4: Extend `TicketUpdateRow`**

Replace the `struct TicketUpdateRow: Encodable { ... }` block (lines 85-110) with:

```swift
struct TicketUpdateRow: Encodable {
    let templateKind: String
    let orientation: String
    let payload: AnyJSON
    let locationPrimaryEnc: String?
    let locationSecondaryEnc: String?
    let styleId: String?
    let eventDateEnc: String?

    enum CodingKeys: String, CodingKey {
        case templateKind         = "template_kind"
        case locationPrimaryEnc   = "location_primary_enc"
        case locationSecondaryEnc = "location_secondary_enc"
        case styleId              = "style_id"
        case eventDateEnc         = "event_date_enc"
        case orientation, payload
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(templateKind,         forKey: .templateKind)
        try c.encode(orientation,          forKey: .orientation)
        try c.encode(payload,              forKey: .payload)
        try c.encode(locationPrimaryEnc,   forKey: .locationPrimaryEnc)
        try c.encode(locationSecondaryEnc, forKey: .locationSecondaryEnc)
        try c.encode(styleId,              forKey: .styleId)
        try c.encode(eventDateEnc,         forKey: .eventDateEnc)
    }
}
```

- [ ] **Step 5: Update `toTicket()`**

Replace the `extension TicketRow { ... toTicket() ... }` block (lines 215-241) with:

```swift
extension TicketRow {

    func toTicket() throws -> Ticket {
        guard let kind = TicketTemplateKind(rawValue: templateKind) else {
            throw TicketRowError.unknownTemplateKind(templateKind)
        }
        guard let orient = TicketOrientation(rawValue: orientation) else {
            throw TicketRowError.unknownOrientation(orientation)
        }
        let payload = try TicketCodec.decodePayload(kind: kind, from: payload)
        let links   = memoryTickets ?? []
        let memoryIds = links.map(\.memoryId)
        let addedAtByMemory = Dictionary(
            uniqueKeysWithValues: links.map { ($0.memoryId, $0.addedAt) }
        )
        let origin      = try TicketLocation.decrypt(locationPrimaryEnc)
        let destination = try TicketLocation.decrypt(locationSecondaryEnc)
        let eventDate   = try eventDateEnc.map { try MemoryDateCodec.decrypt($0) }
        return Ticket(
            id: id,
            createdAt: createdAt,
            updatedAt: updatedAt,
            orientation: orient,
            payload: payload,
            memoryIds: memoryIds,
            originLocation: origin,
            destinationLocation: destination,
            styleId: styleId,
            eventDate: eventDate,
            addedAtByMemory: addedAtByMemory
        )
    }
}
```

- [ ] **Step 6: Build**

```bash
xcodebuild -scheme "Lumoria App" -destination 'platform=iOS Simulator,name=iPhone 15' build 2>&1 | tail -10
```
Expected: errors remain only in `TicketsStore.swift` create/update (missing eventDate arg) — fixed in Task 8.

- [ ] **Step 7: Commit**

```bash
git add "Lumoria App/views/tickets/TicketRow.swift"
git commit -m "feat(ticket): round-trip event_date_enc + added_at"
```

---

### Task 8: TDD — `MemoryDateCodec` round-trip for `event_date_enc`

**Files:**
- Create: `Lumoria AppTests/TicketEventDateCodecTests.swift`

The codec already exists; this test confirms the same envelope is round-tripped without surprises (date precision, ISO encoding) so the column behaves identically to the memories' start/end dates.

- [ ] **Step 1: Write failing test**

```swift
//
//  TicketEventDateCodecTests.swift
//

import Foundation
import Testing
@testable import Lumoria_App

@Suite("Ticket event_date_enc round-trip")
struct TicketEventDateCodecTests {

    @Test("round-trips an arbitrary date through MemoryDateCodec")
    func roundTrip() throws {
        // 2026-04-30 14:32:08 UTC — chosen so seconds don't divide evenly
        let original = Date(timeIntervalSince1970: 1_777_660_328)

        let cipher = try MemoryDateCodec.encrypt(original)
        let decoded = try MemoryDateCodec.decrypt(cipher)

        // ISO-8601 keeps second precision; equality on whole seconds.
        let originalSeconds = Int(original.timeIntervalSince1970)
        let decodedSeconds  = Int(decoded.timeIntervalSince1970)
        #expect(originalSeconds == decodedSeconds)
    }
}
```

- [ ] **Step 2: Add file to test target in Xcode**

Drag the new test file into `Lumoria AppTests` group, target = `Lumoria AppTests`.

- [ ] **Step 3: Run, verify pass**

```bash
xcodebuild -scheme "Lumoria App" -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:"Lumoria AppTests/TicketEventDateCodecTests" \
  test 2>&1 | tail -15
```
Expected: PASSED (the codec already exists; this is a regression guard).

- [ ] **Step 4: Commit**

```bash
git add "Lumoria AppTests/TicketEventDateCodecTests.swift" "Lumoria App.xcodeproj/project.pbxproj"
git commit -m "test(ticket): event_date codec round-trip"
```

---

### Task 9: Pass `eventDate` through `TicketsStore.create` + `update`

**Files:**
- Modify: `Lumoria App/views/tickets/TicketsStore.swift`

- [ ] **Step 1: Add `eventDate` arg to `create`**

Replace the `func create(...)` signature + body (lines 78-139) with:

```swift
    @discardableResult
    func create(
        payload: TicketPayload,
        orientation: TicketOrientation,
        memoryIds: [UUID] = [],
        originLocation: TicketLocation? = nil,
        destinationLocation: TicketLocation? = nil,
        styleId: String? = nil,
        eventDate: Date? = nil
    ) async -> Ticket? {

        let userId: UUID
        do {
            userId = try await supabase.auth.session.user.id
        } catch {
            errorMessage = String(localized: "You need to be signed in to save a ticket.")
            print("[TicketsStore] session fetch failed:", error)
            return nil
        }

        do {
            let json = try TicketCodec.encode(payload)
            let primaryEnc   = try originLocation.map { try TicketLocation.encrypt($0) }
            let secondaryEnc = try destinationLocation.map { try TicketLocation.encrypt($0) }
            let eventDateEnc = try eventDate.map { try MemoryDateCodec.encrypt($0) }
            let insert = NewTicketRow(
                userId: userId,
                templateKind: payload.kind.rawValue,
                orientation: orientation.rawValue,
                payload: json,
                locationPrimaryEnc: primaryEnc,
                locationSecondaryEnc: secondaryEnc,
                styleId: styleId,
                eventDateEnc: eventDateEnc
            )

            let row: TicketRow = try await supabase
                .from("tickets")
                .insert(insert)
                .select("*, memory_tickets(memory_id, added_at)")
                .single()
                .execute()
                .value

            var ticket = try row.toTicket()

            if !memoryIds.isEmpty {
                try await insertMemberships(
                    ticketId: ticket.id,
                    memoryIds: memoryIds
                )
                ticket.memoryIds = memoryIds
                // Best-effort local timestamp until next refetch — keeps
                // the new ticket sorting in the right bucket immediately
                // when "Date added" is selected.
                let now = Date()
                for id in memoryIds {
                    ticket.addedAtByMemory[id] = now
                }
            }

            tickets.insert(ticket, at: 0)
            errorMessage = nil
            StickerRenderService.shared.render(ticket)
            return ticket
        } catch {
            errorMessage = String(localized: "Couldn’t save ticket. \(error.localizedDescription)")
            print("[TicketsStore] create failed:", error)
            Analytics.track(.appError(domain: .ticket, code: (error as NSError).code.description, viewContext: "TicketsStore.create"))
            return nil
        }
    }
```

- [ ] **Step 2: Pass `eventDate` through `update`**

Replace the `func update(_ ticket: Ticket) async -> Bool { ... }` body (lines 146-182) with:

```swift
    @discardableResult
    func update(_ ticket: Ticket) async -> Bool {
        do {
            let json = try TicketCodec.encode(ticket.payload)
            let primaryEnc   = try ticket.originLocation.map { try TicketLocation.encrypt($0) }
            let secondaryEnc = try ticket.destinationLocation.map { try TicketLocation.encrypt($0) }
            let eventDateEnc = try ticket.eventDate.map { try MemoryDateCodec.encrypt($0) }
            let patch = TicketUpdateRow(
                templateKind: ticket.kind.rawValue,
                orientation: ticket.orientation.rawValue,
                payload: json,
                locationPrimaryEnc: primaryEnc,
                locationSecondaryEnc: secondaryEnc,
                styleId: ticket.styleId,
                eventDateEnc: eventDateEnc
            )

            let updated: TicketRow = try await supabase
                .from("tickets")
                .update(patch)
                .eq("id", value: ticket.id.uuidString)
                .select("*, memory_tickets(memory_id, added_at)")
                .single()
                .execute()
                .value

            let rebuilt = try updated.toTicket()
            if let idx = tickets.firstIndex(where: { $0.id == ticket.id }) {
                tickets[idx] = rebuilt
            }
            errorMessage = nil
            StickerRenderService.shared.render(rebuilt)
            return true
        } catch {
            errorMessage = String(localized: "Couldn’t save changes. \(error.localizedDescription)")
            print("[TicketsStore] update failed:", error)
            Analytics.track(.appError(domain: .ticket, code: (error as NSError).code.description, viewContext: "TicketsStore.update"))
            return false
        }
    }
```

- [ ] **Step 3: Update remaining embed selects**

Replace any remaining embed string `"*, memory_tickets(memory_id)"` in the file (load function around line 50, others around line 113 + line 164) with `"*, memory_tickets(memory_id, added_at)"`.

```bash
grep -n "memory_tickets(memory_id" "/Users/bearista/Documents/lumoria/Lumoria App/Lumoria App/views/tickets/TicketsStore.swift"
```
Expected: every match should now read `memory_tickets(memory_id, added_at)`.

- [ ] **Step 4: Build**

```bash
xcodebuild -scheme "Lumoria App" -destination 'platform=iOS Simulator,name=iPhone 15' build 2>&1 | tail -10
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add "Lumoria App/views/tickets/TicketsStore.swift"
git commit -m "feat(ticket): persist event_date and surface added_at"
```

---

### Task 10: Wire `eventDate` from each funnel form

**Files:**
- Modify: `Lumoria App/views/tickets/new/NewTicketFunnel.swift`

- [ ] **Step 1: Add `currentEventDate` helper**

Find a stable spot in `NewTicketFunnel` near other private helpers (after `resolveLocations()` around line 1388). Add:

```swift
    /// Canonical event date for the active template. Plane templates use
    /// `form.departureDate`; train templates use `trainForm.date`; concert
    /// uses `eventForm.date`; transit uses `undergroundForm.date`. Returns
    /// nil only if the funnel is in a bad state (no template).
    private var currentEventDate: Date? {
        switch template {
        case .express, .orient, .night, .post, .glow:
            return trainForm.date
        case .concert:
            return eventForm.date
        case .underground, .sign, .infoscreen, .grid:
            return undergroundForm.date
        case .afterglow, .studio, .heritage, .terminal, .prism:
            return form.departureDate
        case .none:
            return nil
        }
    }
```

- [ ] **Step 2: Pass into `store.create` (single-ticket path)**

In `persist(...)` at line 1251, replace the `let ticket = await store.create(...)` block with:

```swift
        let (origin, destination) = resolveLocations()
        let ticket = await store.create(
            payload: payload,
            orientation: orientation,
            originLocation: origin,
            destinationLocation: destination,
            styleId: selectedStyleId ?? template?.defaultStyle.id,
            eventDate: currentEventDate
        )
```

- [ ] **Step 3: Pass into the multi-leg transit path**

In `createUndergroundTickets(using:)` at line 1306, replace the `let ticket = await store.create(...)` block with:

```swift
            let ticket = await store.create(
                payload: wrapped,
                orientation: orientation,
                originLocation: pair?.origin,
                destinationLocation: pair?.destination,
                styleId: styleId,
                eventDate: undergroundForm.date
            )
```

(All legs share the `undergroundForm.date` — the journey day.)

- [ ] **Step 4: Pass through edit flow**

In `buildUpdatedTicket()` at line 1356, replace the returned `Ticket(...)` initializer with:

```swift
        return Ticket(
            id: original.id,
            createdAt: original.createdAt,
            updatedAt: Date(),
            orientation: orientation,
            payload: payload,
            memoryIds: original.memoryIds,
            originLocation: origin,
            destinationLocation: destination,
            styleId: selectedStyleId ?? template?.defaultStyle.id,
            eventDate: currentEventDate,
            addedAtByMemory: original.addedAtByMemory
        )
```

- [ ] **Step 5: Build**

```bash
xcodebuild -scheme "Lumoria App" -destination 'platform=iOS Simulator,name=iPhone 15' build 2>&1 | tail -10
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Commit**

```bash
git add "Lumoria App/views/tickets/new/NewTicketFunnel.swift"
git commit -m "feat(funnel): write eventDate from form date fields"
```

---

### Task 11: TDD — `MemorySortApplier` pure logic

**Files:**
- Create: `Lumoria App/views/collections/MemorySortApplier.swift`
- Create: `Lumoria AppTests/MemorySortApplierTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
//
//  MemorySortApplierTests.swift
//

import Foundation
import Testing
@testable import Lumoria_App

@Suite("MemorySortApplier")
@MainActor
struct MemorySortApplierTests {

    private let memoryId = UUID()

    private func makeTicket(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        eventDate: Date? = nil,
        addedAt: Date? = nil
    ) -> Ticket {
        Ticket(
            id: id,
            createdAt: createdAt,
            updatedAt: createdAt,
            orientation: .horizontal,
            payload: .afterglow(AfterglowTicket(
                airline: "X",
                flightNumber: "1",
                origin: "AAA", originCity: "A",
                destination: "BBB", destinationCity: "B",
                date: "1 Jan 2026",
                boardingTime: "08:00",
                gate: "1", seat: "1A",
                pnr: "ABCDEF"
            )),
            memoryIds: [memoryId],
            eventDate: eventDate,
            addedAtByMemory: addedAt.map { [memoryId: $0] } ?? [:]
        )
    }

    @Test("sorts by date added ascending — oldest first")
    func sortsByDateAddedAsc() {
        let day = Date(timeIntervalSince1970: 0)
        let a = makeTicket(addedAt: day)
        let b = makeTicket(addedAt: day.addingTimeInterval(60))
        let c = makeTicket(addedAt: day.addingTimeInterval(120))
        let result = MemorySortApplier.apply(
            [c, a, b],
            field: .dateAdded,
            ascending: true,
            memoryId: memoryId
        )
        #expect(result.map(\.id) == [a.id, b.id, c.id])
    }

    @Test("sorts by date added descending — newest first")
    func sortsByDateAddedDesc() {
        let day = Date(timeIntervalSince1970: 0)
        let a = makeTicket(addedAt: day)
        let b = makeTicket(addedAt: day.addingTimeInterval(60))
        let result = MemorySortApplier.apply(
            [a, b],
            field: .dateAdded,
            ascending: false,
            memoryId: memoryId
        )
        #expect(result.map(\.id) == [b.id, a.id])
    }

    @Test("sorts by event date ascending")
    func sortsByEventDateAsc() {
        let day = Date(timeIntervalSince1970: 0)
        let a = makeTicket(eventDate: day)
        let b = makeTicket(eventDate: day.addingTimeInterval(60))
        let result = MemorySortApplier.apply(
            [b, a],
            field: .eventDate,
            ascending: true,
            memoryId: memoryId
        )
        #expect(result.map(\.id) == [a.id, b.id])
    }

    @Test("sorts by created date ascending")
    func sortsByCreatedAsc() {
        let day = Date(timeIntervalSince1970: 0)
        let a = makeTicket(createdAt: day)
        let b = makeTicket(createdAt: day.addingTimeInterval(60))
        let result = MemorySortApplier.apply(
            [b, a],
            field: .dateCreated,
            ascending: true,
            memoryId: memoryId
        )
        #expect(result.map(\.id) == [a.id, b.id])
    }

    @Test("buckets nil event dates last regardless of direction")
    func bucketsNilEventDatesLast() {
        let day = Date(timeIntervalSince1970: 0)
        let dated = makeTicket(eventDate: day)
        let undated = makeTicket(eventDate: nil)
        let asc = MemorySortApplier.apply(
            [undated, dated],
            field: .eventDate,
            ascending: true,
            memoryId: memoryId
        )
        let desc = MemorySortApplier.apply(
            [undated, dated],
            field: .eventDate,
            ascending: false,
            memoryId: memoryId
        )
        #expect(asc.map(\.id) == [dated.id, undated.id])
        #expect(desc.map(\.id) == [dated.id, undated.id])
    }

    @Test("ties break by ticket id for determinism")
    func tiesBreakByTicketId() {
        let day = Date(timeIntervalSince1970: 0)
        let lowId  = UUID(uuid: (0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,1))
        let highId = UUID(uuid: (0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,2))
        let a = makeTicket(id: lowId,  eventDate: day)
        let b = makeTicket(id: highId, eventDate: day)
        let result = MemorySortApplier.apply(
            [b, a],
            field: .eventDate,
            ascending: true,
            memoryId: memoryId
        )
        #expect(result.map(\.id) == [lowId, highId])
    }
}
```

- [ ] **Step 2: Run, verify failure**

```bash
xcodebuild -scheme "Lumoria App" -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:"Lumoria AppTests/MemorySortApplierTests" \
  test 2>&1 | tail -15
```
Expected: BUILD FAILED — `MemorySortApplier` undefined.

- [ ] **Step 3: Write applier**

Create `Lumoria App/views/collections/MemorySortApplier.swift`:

```swift
//
//  MemorySortApplier.swift
//  Lumoria App
//
//  Pure sort over a memory's tickets. Nil dates always bucket last so a
//  lone undated ticket doesn't dominate the top of the list.
//

import Foundation

enum MemorySortApplier {

    static func apply(
        _ tickets: [Ticket],
        field: MemorySortField,
        ascending: Bool,
        memoryId: UUID
    ) -> [Ticket] {
        tickets.sorted { lhs, rhs in
            let l = key(for: lhs, field: field, memoryId: memoryId)
            let r = key(for: rhs, field: field, memoryId: memoryId)

            // Nil keys go last in either direction.
            switch (l, r) {
            case (nil, nil):
                return lhs.id.uuidString < rhs.id.uuidString
            case (nil, _):
                return false
            case (_, nil):
                return true
            case let (lDate?, rDate?):
                if lDate == rDate {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return ascending ? lDate < rDate : lDate > rDate
            }
        }
    }

    private static func key(
        for ticket: Ticket,
        field: MemorySortField,
        memoryId: UUID
    ) -> Date? {
        switch field {
        case .dateAdded:   return ticket.addedAtByMemory[memoryId]
        case .eventDate:   return ticket.eventDate
        case .dateCreated: return ticket.createdAt
        }
    }
}
```

- [ ] **Step 4: Add files to Xcode project**

Drag `MemorySortApplier.swift` into `views/collections/` (target `Lumoria App`); drag `MemorySortApplierTests.swift` into `Lumoria AppTests`.

- [ ] **Step 5: Run tests, verify pass**

```bash
xcodebuild -scheme "Lumoria App" -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:"Lumoria AppTests/MemorySortApplierTests" \
  test 2>&1 | tail -15
```
Expected: 6 tests passed.

- [ ] **Step 6: Commit**

```bash
git add "Lumoria App/views/collections/MemorySortApplier.swift" \
        "Lumoria AppTests/MemorySortApplierTests.swift" \
        "Lumoria App.xcodeproj/project.pbxproj"
git commit -m "feat(memory): MemorySortApplier with TDD"
```

---

### Task 12: `MemorySortSheet` UI

**Files:**
- Create: `Lumoria App/views/collections/MemorySortSheet.swift`

The sheet matches Figma node 2028-143016: title row, three radio rows, then a segmented Oldest / Newest control.

- [ ] **Step 1: Write the sheet**

```swift
//
//  MemorySortSheet.swift
//  Lumoria App
//
//  Bottom sheet for choosing how `MemoryDetailView` orders its tickets.
//  Three fields × oldest/newest direction. Persists per memory via
//  `MemoriesStore.updateSort`.
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=2028-143016
//

import SwiftUI

struct MemorySortSheet: View {

    let memoryId: UUID
    @Binding var field: MemorySortField
    @Binding var ascending: Bool
    let onChange: (_ field: MemorySortField, _ ascending: Bool) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Sort tickets")
                    .font(.title3.bold())
                    .foregroundStyle(Color.Text.primary)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.Text.secondary)
                }
                .accessibilityLabel("Close")
            }

            VStack(spacing: 0) {
                ForEach(MemorySortField.allCases) { option in
                    sortRow(option)
                    if option != MemorySortField.allCases.last {
                        Divider().opacity(0.4)
                    }
                }
            }

            Picker("Direction", selection: Binding(
                get: { ascending },
                set: { newValue in
                    ascending = newValue
                    onChange(field, newValue)
                }
            )) {
                Text("Oldest first").tag(true)
                Text("Newest first").tag(false)
            }
            .pickerStyle(.segmented)
        }
        .padding(24)
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func sortRow(_ option: MemorySortField) -> some View {
        Button {
            field = option
            onChange(option, ascending)
        } label: {
            HStack {
                Text(option.title)
                    .font(.body)
                    .foregroundStyle(Color.Text.primary)
                Spacer()
                if field == option {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    @Previewable @State var field: MemorySortField = .dateAdded
    @Previewable @State var ascending = true
    return MemorySortSheet(
        memoryId: UUID(),
        field: $field,
        ascending: $ascending
    ) { _, _ in }
}
```

- [ ] **Step 2: Add to Xcode**

Drag into `views/collections/` group, target `Lumoria App`.

- [ ] **Step 3: Build**

```bash
xcodebuild -scheme "Lumoria App" -destination 'platform=iOS Simulator,name=iPhone 15' build 2>&1 | tail -10
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/views/collections/MemorySortSheet.swift" "Lumoria App.xcodeproj/project.pbxproj"
git commit -m "feat(memory): MemorySortSheet"
```

---

### Task 13: Wire sort into `MemoryDetailView`

**Files:**
- Modify: `Lumoria App/views/collections/CollectionDetailView.swift`

- [ ] **Step 1: Add sheet state**

In `MemoryDetailView`, after the existing `@State private var showAddExistingTicket = false` line (around line 26), add:

```swift
    @State private var showSortSheet = false
```

- [ ] **Step 2: Add Sort menu item**

Replace the `private var menuItems: [LumoriaMenuItem]` block (lines 176-184) with:

```swift
    private var menuItems: [LumoriaMenuItem] {
        [
            .init(title: "Add existing ticket…") {
                showAddExistingTicket = true
            },
            .init(title: "Sort…") { showSortSheet = true },
            .init(title: "Edit") { showEdit = true },
            .init(title: "Delete", kind: .destructive) { showDeleteConfirm = true },
        ]
    }
```

- [ ] **Step 3: Apply sort in `contentCard`**

Replace the `let tickets = ticketsStore.tickets(in: memory.id)` line (around line 257) with:

```swift
        let tickets = MemorySortApplier.apply(
            ticketsStore.tickets(in: memory.id),
            field: currentMemory.sortField,
            ascending: currentMemory.sortAscending,
            memoryId: memory.id
        )
```

- [ ] **Step 4: Animate the re-order**

Wrap the `ticketsGrid(tickets)` call inside `contentCard` with an `.animation(.easeInOut(duration: 0.25), value: ...)`. Replace the existing `if tickets.isEmpty { ... } else { ticketsGrid(tickets).padding...}` block (around lines 260-266) with:

```swift
            if tickets.isEmpty {
                emptyBody
            } else {
                ticketsGrid(tickets)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .animation(
                        .easeInOut(duration: 0.25),
                        value: tickets.map(\.id)
                    )
            }
```

- [ ] **Step 5: Present the sheet**

Inside the `body` modifier chain — after `.sheet(isPresented: $showAddExistingTicket) { ... }` (around line 123) — add:

```swift
        .sheet(isPresented: $showSortSheet) {
            MemorySortSheet(
                memoryId: memory.id,
                field: Binding(
                    get: { currentMemory.sortField },
                    set: { _ in } // routed through onChange below
                ),
                ascending: Binding(
                    get: { currentMemory.sortAscending },
                    set: { _ in }
                )
            ) { field, ascending in
                Task {
                    await memoriesStore.updateSort(
                        memoryId: memory.id,
                        field: field,
                        ascending: ascending
                    )
                    Analytics.track(.memorySortChanged(
                        field: field.rawValue,
                        ascending: ascending,
                        memoryIdHash: AnalyticsIdentity.hashUUID(memory.id)
                    ))
                }
            }
        }
```

- [ ] **Step 6: Build**

```bash
xcodebuild -scheme "Lumoria App" -destination 'platform=iOS Simulator,name=iPhone 15' build 2>&1 | tail -10
```
Expected: BUILD FAILED — `Analytics.memorySortChanged` not yet defined. That is expected; fixed in Task 14.

- [ ] **Step 7: Commit**

```bash
git add "Lumoria App/views/collections/CollectionDetailView.swift"
git commit -m "feat(memory): wire sort sheet into detail view"
```

---

### Task 14: Add `memorySortChanged` analytics event

**Files:**
- Modify: `Lumoria App/services/analytics/Analytics.swift` (or wherever `Analytics.track` lives — discover with grep)

- [ ] **Step 1: Locate the event enum**

```bash
grep -rn "case memoryEdited\|memoryOpened\|memoryDeleted" "/Users/bearista/Documents/lumoria/Lumoria App/Lumoria App/" --include="*.swift" | head -5
```
Expected: identifies the enum file (likely `services/analytics/AnalyticsEvent.swift`).

- [ ] **Step 2: Add event case**

Open the file from step 1. Mirror the shape of `memoryEdited` (which already takes `memoryIdHash`). Add a new `case memorySortChanged(field: String, ascending: Bool, memoryIdHash: String)` in the same style as the existing memory cases. Wire its `name` and `properties` exactly the way neighbouring memory cases are wired. (Inline the new case next to `memoryEdited` so the file's grouping stays intact.)

- [ ] **Step 3: Build**

```bash
xcodebuild -scheme "Lumoria App" -destination 'platform=iOS Simulator,name=iPhone 15' build 2>&1 | tail -10
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Run all tests**

```bash
xcodebuild -scheme "Lumoria App" -destination 'platform=iOS Simulator,name=iPhone 15' test 2>&1 | tail -25
```
Expected: All tests pass. New tests from Tasks 8 and 11 included.

- [ ] **Step 5: Commit**

```bash
git add "Lumoria App/services/analytics/" "Lumoria AppTests/AnalyticsEventTests.swift"
git commit -m "feat(analytics): memorySortChanged event"
```

---

### Task 15: Manual test pass on simulator

This is a verification task — no code is written, but skipping it leaves UI bugs unflushed. Refer to `superpowers:verification-before-completion`.

- [ ] **Step 1: Boot the app**

```bash
xcodebuild -scheme "Lumoria App" -destination 'platform=iOS Simulator,name=iPhone 15' build
xcrun simctl launch booted com.lumoria.LumoriaApp
```

- [ ] **Step 2: Run the matrix**

For a memory with at least 4 tickets across template families (1× plane, 1× train, 1× concert, 1× transit):

| Field × direction | Expected |
|---|---|
| Date added · Oldest first | First-added at top |
| Date added · Newest first | Most-recently-added at top |
| Event date · Oldest first | Earliest journey/event at top, undated tickets at bottom |
| Event date · Newest first | Latest journey/event at top, undated tickets at bottom |
| Date created · Oldest first | First-created at top |
| Date created · Newest first | Most-recent at top |

Each combination should:
- Animate the re-order (no hard cut).
- Persist after backgrounding the app + relaunching.
- Persist across memories independently (memory A asc dateAdded, memory B desc eventDate).
- Stay correct after creating a new ticket inside the memory (it should slot in via current sort).

- [ ] **Step 3: Test the offline rollback**

Toggle the simulator to Airplane Mode in Network Link Conditioner, change the sort, confirm it visually flips, then verify the toast/error path triggers the rollback once Supabase rejects.

- [ ] **Step 4: Note any defects**

If a defect surfaces, file it in the task list and patch in a follow-up commit before merging.

- [ ] **Step 5: Commit any fix-ups**

```bash
git status
```
If patches were needed, commit each as `fix(memory): <one-line>`.

---

### Task 16: Changelog entry

The user's project memory (`feedback_changelog_mdx`) requires a `.mdx` entry under `lumoria/src/content/changelog/`. That directory lives in the marketing-site repo (not this app repo) — confirm with the user whether the entry belongs here or there before writing.

- [ ] **Step 1: Confirm changelog repo**

Ask the user: "Changelog mdx — does it go in this repo or the marketing-site repo?"

- [ ] **Step 2: Draft the entry**

Once confirmed, write `<repo>/lumoria/src/content/changelog/2026-04-30-memory-ticket-sort.mdx` with JS-export frontmatter (matching existing entries' format — read one first):

```mdx
export const frontmatter = {
  title: "Sort your memories",
  date: "2026-04-30",
  tags: ["memory", "tickets"],
};

You can now sort the tickets inside a memory by **date added**, **date of the event**, or **date created** — oldest first or newest first. The choice is saved per memory, so each trip stays in the order you want.
```

- [ ] **Step 3: Commit**

In whichever repo, `feat(changelog): memory ticket sort`.

---

## Self-Review

**1. Spec coverage**

| Spec item | Task |
|---|---|
| Sort menu item in MemoryDetailView contextual menu | Task 13 (step 2) |
| Bottom sheet with 3 sort fields | Task 12 |
| Asc/desc segmented inside the sheet | Task 12 |
| Default = Date Added · Ascending | Task 4 (Memory init) + Task 1 + Task 2 (DB defaults) |
| Persist per memory via Supabase | Task 2 + Task 5 |
| Real event_date (Path B chosen over string parsing) | Tasks 1, 6, 7, 9, 10 |
| Plane/train two-date question (use departureDate) | Task 10 step 1 (`currentEventDate`) |
| Re-order animation in detail view | Task 13 step 4 |
| Rollback on network failure | Task 5 step 2 |
| Tests | Tasks 8, 11 |
| Analytics event | Task 14 |
| Changelog | Task 16 |

**2. Placeholder scan** — none. Every code-changing step has the actual code.

**3. Type consistency**

- `MemorySortField` raw values (`date_added`, `event_date`, `date_created`) match the SQL CHECK constraint in Task 2.
- `Memory.sortField` / `sortAscending` field names match the column names via `CodingKeys` in Task 4 step 2.
- `Ticket.eventDate` / `addedAtByMemory` introduced in Task 6 are referenced consistently in Task 7 (decode), Task 9 (write), Task 10 (funnel), Task 11 (sort applier).
- `MemoriesStore.updateSort(memoryId:field:ascending:)` signature matches the call in Task 13 step 5.
- `MemorySortApplier.apply(_:field:ascending:memoryId:)` signature matches the test calls in Task 11 step 1 and the use in Task 13 step 3.
