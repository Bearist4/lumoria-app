# Memory Edit Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the existing `EditCollectionView` sheet with an inline edit mode in `MemoryDetailView`. Users tap "Edit" in the contextual menu to enter; the header swaps to tappable emoji + inline-editable name, the ticket grid swaps to a draggable list of compact `TicketEntryRow`s, the top bar swaps to a color-picker bucket button (left) + green Done button (right). A new color-picker bottom sheet matches Figma 2028-143737.

**Architecture:**
- One DB migration: `memory_tickets.display_order int null`. The existing `memories.sort_field` CHECK constraint relaxes to also allow `'manual'`.
- App layer gains `MemorySortField.manual`. `Ticket.displayOrderByMemory: [UUID: Int]` mirrors the new junction column. `MemorySortApplier` handles `.manual` by sorting on the per-memory order; nils bucket last.
- New components: `LumoriaCategoryTag` (rounded pill, category-tinted bg) and `TicketEntryRow` (72pt row with tag + title + drag handle).
- New `MemoryColorPickerSheet` — `floatingBottomSheet` content with the 11 `Colors/<family>/50` swatches, Reset + Done.
- New `MemoryEditModeView` (or in-line state in `MemoryDetailView`) — buffered edits for emoji/name/color/order; the green Done button commits via existing store APIs and a new `MemoriesStore.reorderTickets`.
- Drag-to-reorder uses SwiftUI `List` + `.onMove` with `EditMode.constant(.active)`. Custom row chrome via `listRowBackground` / `listRowSeparator(.hidden)` / `listRowInsets`.
- Old `EditCollectionView` stays in the repo, just unwired from the contextual menu.

**Tech Stack:** Swift / SwiftUI · Supabase Postgres · Swift Testing · existing `MemoryDateCodec`, `EncryptionService`, `floatingBottomSheet`.

---

## File Structure

**Created**
- `supabase/migrations/20260513000000_memory_tickets_display_order.sql` — new column + relaxed CHECK constraint.
- `Lumoria App/components/LumoriaCategoryTag.swift` — rounded pill.
- `Lumoria App/components/TicketEntryRow.swift` — compact row.
- `Lumoria App/views/collections/MemoryColorPickerSheet.swift` — color bottom sheet.
- `Lumoria App/views/collections/MemoryEditMode.swift` — edit-mode container view + view-state.
- `Lumoria AppTests/MemorySortApplierManualTests.swift` — manual-sort coverage.

**Modified**
- `Lumoria App/views/collections/MemorySortField.swift` — add `.manual` case (no UI surfacing in the sort sheet).
- `Lumoria App/views/collections/MemorySortApplier.swift` — handle `.manual`.
- `Lumoria App/views/tickets/Ticket.swift` — add `displayOrderByMemory: [UUID: Int]`.
- `Lumoria App/views/tickets/TicketRow.swift` — `MemoryTicketLink` decodes `display_order`; `toTicket` populates the new dict.
- `Lumoria App/views/collections/CollectionsStore.swift` — `reorderTickets(in:ordered:)` plus an `updateSort` shortcut to set `.manual`.
- `Lumoria App/views/collections/CollectionDetailView.swift` — adds `isEditing` state and switches to `MemoryEditMode` when active; "Edit" menu item flips state instead of presenting `EditCollectionView`.
- `Lumoria App/components/TicketCategoryStyle.swift` — adds compact `pillLabel` property.

---

## Pre-flight

Branch off `main`: `feat/memory-edit-mode`. Migration is additive — running it on the linked Supabase project is safe; defer apply per the user's preference.

---

### Task 1: Migration — `memory_tickets.display_order` + manual sort field

**Files:**
- Create: `supabase/migrations/20260513000000_memory_tickets_display_order.sql`

- [ ] **Step 1: Write migration**

```sql
-- Per-memory manual order. Null = no manual order (membership predates
-- a manual reorder; client falls back to whatever sort_field selects).
alter table public.memory_tickets
    add column display_order integer null;

-- Allow 'manual' as a sort_field value. The check constraint was
-- introduced in 20260512000001_memory_sort_prefs.sql; replace it.
alter table public.memories
    drop constraint memories_sort_field_check;

alter table public.memories
    add constraint memories_sort_field_check
    check (sort_field in ('date_added', 'event_date', 'date_created', 'manual'));

-- Lookup index for the client's "load tickets in memory" query.
create index if not exists memory_tickets_memory_id_display_order_idx
    on public.memory_tickets (memory_id, display_order);
```

- [ ] **Step 2: Commit**

```bash
git add supabase/migrations/20260513000000_memory_tickets_display_order.sql
git commit -m "feat(db): memory_tickets.display_order + manual sort"
```

---

### Task 2: `MemorySortField.manual`

**Files:**
- Modify: `Lumoria App/views/collections/MemorySortField.swift`

- [ ] **Step 1: Add the case**

Replace the enum with:

```swift
enum MemorySortField: String, CaseIterable, Identifiable, Codable {
    case dateCreated = "date_created"
    case dateAdded   = "date_added"
    case eventDate   = "event_date"
    case manual      = "manual"

    var id: String { rawValue }

    /// Cases that surface in the sort sheet. `.manual` is set
    /// implicitly when the user reorders tickets, so we hide it from
    /// the picker — the sheet keeps offering only date-based sorts.
    static var pickerOptions: [MemorySortField] {
        [.dateCreated, .dateAdded, .eventDate]
    }

    /// Title shown in the sort sheet's row.
    var title: String {
        switch self {
        case .dateCreated: return String(localized: "Ticket creation")
        case .dateAdded:   return String(localized: "Added to this memory")
        case .eventDate:   return String(localized: "Event")
        case .manual:      return String(localized: "Manual")
        }
    }

    var subtitle: String? {
        switch self {
        case .eventDate: return String(localized: "The date displayed on the ticket")
        default:         return nil
        }
    }
}
```

- [ ] **Step 2: Update `MemorySortSheet` row enumeration**

Open `Lumoria App/views/collections/MemorySortSheet.swift`. Find:

```swift
ForEach(Array(MemorySortField.allCases.enumerated()), id: \.element.id) { index, option in
```

Replace with:

```swift
ForEach(Array(MemorySortField.pickerOptions.enumerated()), id: \.element.id) { index, option in
```

And replace `MemorySortField.allCases.count - 1` with `MemorySortField.pickerOptions.count - 1` in the divider check.

- [ ] **Step 3: Build**

```bash
xcodebuild -scheme "Lumoria App" -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1' build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/views/collections/MemorySortField.swift" "Lumoria App/views/collections/MemorySortSheet.swift"
git commit -m "feat(memory): MemorySortField.manual + hide from picker"
```

---

### Task 3: Surface `display_order` on `Ticket`

**Files:**
- Modify: `Lumoria App/views/tickets/Ticket.swift`
- Modify: `Lumoria App/views/tickets/TicketRow.swift`

- [ ] **Step 1: Add field to `Ticket`**

In `Ticket.swift`, after the `addedAtByMemory` declaration, add:

```swift
    /// Manual sort position per memory (memory_tickets.display_order).
    /// Nil-by-key when the membership predates a reorder; sort applier
    /// buckets those last when sort_field == .manual.
    var displayOrderByMemory: [UUID: Int]
```

Update the initializer parameter list to include `displayOrderByMemory: [UUID: Int] = [:]` (after `addedAtByMemory`) and assign `self.displayOrderByMemory = displayOrderByMemory` in the body.

- [ ] **Step 2: Add field to `MemoryTicketLink` + `toTicket`**

In `TicketRow.swift`, replace the `MemoryTicketLink` block with:

```swift
struct MemoryTicketLink: Decodable {
    let memoryId: UUID
    let addedAt: Date
    let displayOrder: Int?

    enum CodingKeys: String, CodingKey {
        case memoryId     = "memory_id"
        case addedAt      = "added_at"
        case displayOrder = "display_order"
    }
}
```

In `toTicket()`, after building `addedAtByMemory`, add:

```swift
        let displayOrderByMemory = Dictionary(
            uniqueKeysWithValues: links.compactMap { link -> (UUID, Int)? in
                guard let order = link.displayOrder else { return nil }
                return (link.memoryId, order)
            }
        )
```

And pass it to the `Ticket(...)` call: `displayOrderByMemory: displayOrderByMemory`.

- [ ] **Step 3: Update embed selects**

In `TicketsStore.swift`, replace every occurrence of `"*, memory_tickets(memory_id, added_at)"` with `"*, memory_tickets(memory_id, added_at, display_order)"`.

```bash
grep -n "memory_tickets(memory_id" "/Users/bearista/Documents/lumoria/Lumoria App/Lumoria App/views/tickets/TicketsStore.swift"
```
Expected: every match should now read `memory_tickets(memory_id, added_at, display_order)`.

- [ ] **Step 4: Build**

```bash
xcodebuild -scheme "Lumoria App" -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1' build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add "Lumoria App/views/tickets/Ticket.swift" "Lumoria App/views/tickets/TicketRow.swift" "Lumoria App/views/tickets/TicketsStore.swift"
git commit -m "feat(ticket): surface memory_tickets.display_order"
```

---

### Task 4: Sort applier handles `.manual`

**Files:**
- Modify: `Lumoria App/views/collections/MemorySortApplier.swift`

- [ ] **Step 1: Extend the key lookup**

In `key(for:field:memoryId:)`, change the return type to `Date?` is incompatible with `Int?`. Generalise: introduce a `Comparable` neutral key. Simplest path — overload `apply` for the manual case so the existing date-based `key(...)` keeps working.

Replace the entire enum body with:

```swift
enum MemorySortApplier {

    static func apply(
        _ tickets: [Ticket],
        field: MemorySortField,
        ascending: Bool,
        memoryId: UUID
    ) -> [Ticket] {
        switch field {
        case .manual:
            return manual(tickets, ascending: ascending, memoryId: memoryId)
        case .dateAdded, .eventDate, .dateCreated:
            return byDate(tickets, field: field, ascending: ascending, memoryId: memoryId)
        }
    }

    // MARK: - Date-keyed sort

    private static func byDate(
        _ tickets: [Ticket],
        field: MemorySortField,
        ascending: Bool,
        memoryId: UUID
    ) -> [Ticket] {
        tickets.sorted { lhs, rhs in
            let l = dateKey(for: lhs, field: field, memoryId: memoryId)
            let r = dateKey(for: rhs, field: field, memoryId: memoryId)
            switch (l, r) {
            case (nil, nil):
                return lhs.id.uuidString < rhs.id.uuidString
            case (nil, _): return false
            case (_, nil): return true
            case let (lDate?, rDate?):
                if lDate == rDate {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return ascending ? lDate < rDate : lDate > rDate
            }
        }
    }

    private static func dateKey(
        for ticket: Ticket,
        field: MemorySortField,
        memoryId: UUID
    ) -> Date? {
        switch field {
        case .dateAdded:   return ticket.addedAtByMemory[memoryId]
        case .eventDate:   return ticket.eventDate
        case .dateCreated: return ticket.createdAt
        case .manual:      return nil // unreachable — handled above
        }
    }

    // MARK: - Manual sort

    private static func manual(
        _ tickets: [Ticket],
        ascending: Bool,
        memoryId: UUID
    ) -> [Ticket] {
        tickets.sorted { lhs, rhs in
            let l = lhs.displayOrderByMemory[memoryId]
            let r = rhs.displayOrderByMemory[memoryId]
            switch (l, r) {
            case (nil, nil):
                return lhs.id.uuidString < rhs.id.uuidString
            case (nil, _): return false
            case (_, nil): return true
            case let (lOrder?, rOrder?):
                if lOrder == rOrder {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return ascending ? lOrder < rOrder : lOrder > rOrder
            }
        }
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild -scheme "Lumoria App" -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1' build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add "Lumoria App/views/collections/MemorySortApplier.swift"
git commit -m "feat(memory): MemorySortApplier handles .manual"
```

---

### Task 5: TDD — manual-sort tests

**Files:**
- Create: `Lumoria AppTests/MemorySortApplierManualTests.swift`

- [ ] **Step 1: Write tests**

```swift
//
//  MemorySortApplierManualTests.swift
//

import Foundation
import Testing
@testable import Lumoria_App

@Suite("MemorySortApplier — manual")
@MainActor
struct MemorySortApplierManualTests {

    private let memoryId = UUID()

    private func makeTicket(id: UUID = UUID(), order: Int? = nil) -> Ticket {
        Ticket(
            id: id,
            createdAt: Date(),
            updatedAt: Date(),
            orientation: .horizontal,
            payload: .afterglow(AfterglowTicket(
                airline: "X",
                flightNumber: "1",
                origin: "AAA", originCity: "A",
                destination: "BBB", destinationCity: "B",
                date: "1 Jan 2026",
                gate: "1",
                seat: "1A",
                boardingTime: "08:00"
            )),
            memoryIds: [memoryId],
            displayOrderByMemory: order.map { [memoryId: $0] } ?? [:]
        )
    }

    @Test("manual ascending — orders by displayOrder")
    func manualAsc() {
        let a = makeTicket(order: 0)
        let b = makeTicket(order: 1)
        let c = makeTicket(order: 2)
        let result = MemorySortApplier.apply(
            [c, a, b],
            field: .manual,
            ascending: true,
            memoryId: memoryId
        )
        #expect(result.map(\.id) == [a.id, b.id, c.id])
    }

    @Test("manual buckets nil orders last regardless of direction")
    func manualBucketsNilLast() {
        let ordered = makeTicket(order: 0)
        let unordered = makeTicket(order: nil)
        let asc = MemorySortApplier.apply(
            [unordered, ordered],
            field: .manual,
            ascending: true,
            memoryId: memoryId
        )
        let desc = MemorySortApplier.apply(
            [unordered, ordered],
            field: .manual,
            ascending: false,
            memoryId: memoryId
        )
        #expect(asc.map(\.id) == [ordered.id, unordered.id])
        #expect(desc.map(\.id) == [ordered.id, unordered.id])
    }
}
```

- [ ] **Step 2: Run tests**

```bash
xcodebuild -scheme "Lumoria App" -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1' \
  -only-testing:"Lumoria AppTests/MemorySortApplierManualTests" \
  test 2>&1 | tail -10
```
Expected: 2 / 2 passed.

- [ ] **Step 3: Commit**

```bash
git add "Lumoria AppTests/MemorySortApplierManualTests.swift"
git commit -m "test(memory): manual sort applier coverage"
```

---

### Task 6: `MemoriesStore.reorderTickets`

**Files:**
- Modify: `Lumoria App/views/collections/CollectionsStore.swift`

- [ ] **Step 1: Add the method**

Append after the existing `updateSort` method:

```swift
    /// Persists a manual order for tickets in a memory. Each ticket
    /// gets a 0-based `display_order` matching its index in `ordered`.
    /// Also flips `sort_field` to `.manual` so the new arrangement is
    /// what the detail view shows by default.
    func reorderTickets(
        in memoryId: UUID,
        ordered ticketIds: [UUID]
    ) async {
        let rows = ticketIds.enumerated().map { index, ticketId in
            ReorderRow(
                memoryId: memoryId,
                ticketId: ticketId,
                displayOrder: index
            )
        }

        do {
            // Postgres `update` doesn't natively support bulk position
            // updates; iterate over each row.
            for row in rows {
                try await supabase
                    .from("memory_tickets")
                    .update(["display_order": row.displayOrder])
                    .eq("memory_id", value: row.memoryId.uuidString)
                    .eq("ticket_id", value: row.ticketId.uuidString)
                    .execute()
            }

            // Flip sort_field to manual locally + remotely. updateSort
            // already does the optimistic + rollback dance.
            await updateSort(memoryId: memoryId, field: .manual, ascending: true)

            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Couldn’t save the new order. \(error.localizedDescription)")
            print("[MemoriesStore] reorderTickets failed:", error)
            Analytics.track(.appError(
                domain: .memory,
                code: (error as NSError).code.description,
                viewContext: "MemoriesStore.reorderTickets"
            ))
        }
    }

    private struct ReorderRow {
        let memoryId: UUID
        let ticketId: UUID
        let displayOrder: Int
    }
```

- [ ] **Step 2: Build**

```bash
xcodebuild -scheme "Lumoria App" -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1' build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add "Lumoria App/views/collections/CollectionsStore.swift"
git commit -m "feat(memory): MemoriesStore.reorderTickets"
```

---

### Task 7: Compact `pillLabel` on `TicketCategoryStyle`

**Files:**
- Modify: `Lumoria App/components/TicketCategoryStyle.swift`

- [ ] **Step 1: Add property**

Append inside the enum, after `displayName`:

```swift
    /// Short, single-word label used in tight surfaces like the
    /// `TicketEntryRow` pill. For categories without a shorter form
    /// it falls back to `displayName`.
    var pillLabel: String {
        switch self {
        case .publicTransit: return String(localized: "Transport")
        case .food:          return String(localized: "Food")
        case .movie:         return String(localized: "Movie")
        case .garden:        return String(localized: "Park")
        default:             return displayName
        }
    }
```

- [ ] **Step 2: Commit**

```bash
git add "Lumoria App/components/TicketCategoryStyle.swift"
git commit -m "feat(category): compact pillLabel"
```

---

### Task 8: `LumoriaCategoryTag` component

**Files:**
- Create: `Lumoria App/components/LumoriaCategoryTag.swift`

- [ ] **Step 1: Write the view**

```swift
//
//  LumoriaCategoryTag.swift
//  Lumoria App
//
//  Rounded category pill used inside `TicketEntryRow` and anywhere a
//  ticket needs a quick visual category badge.
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=2027-142068
//

import SwiftUI

struct LumoriaCategoryTag: View {

    let category: TicketCategoryStyle

    var body: some View {
        Text(category.pillLabel)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(category.onColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(category.backgroundColor)
            )
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        LumoriaCategoryTag(category: .plane)
        LumoriaCategoryTag(category: .train)
        LumoriaCategoryTag(category: .publicTransit)
        LumoriaCategoryTag(category: .concert)
    }
    .padding()
    .background(Color.Background.default)
}
```

- [ ] **Step 2: Commit**

```bash
git add "Lumoria App/components/LumoriaCategoryTag.swift"
git commit -m "feat(component): LumoriaCategoryTag"
```

---

### Task 9: `TicketEntryRow` component

**Files:**
- Create: `Lumoria App/components/TicketEntryRow.swift`

- [ ] **Step 1: Write the row**

```swift
//
//  TicketEntryRow.swift
//  Lumoria App
//
//  72pt compact row used by the memory edit-mode list. Shows category
//  pill, a single-line title (city → city / station → station / artist),
//  and a drag handle on the right. Pure visual — drag wiring lives on
//  the parent List/onMove.
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=2027-142068
//

import SwiftUI

struct TicketEntryRow: View {

    let ticket: Ticket

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            LumoriaCategoryTag(category: ticket.kind.categoryStyle)
            title
            Spacer(minLength: 8)
            handle
        }
        .padding(.horizontal, 16)
        .frame(height: 72)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.Text.primary.opacity(0.05))
        )
    }

    @ViewBuilder
    private var title: some View {
        Text(ticket.entryTitle)
            .font(.headline)
            .foregroundStyle(Color.Text.primary)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    private var handle: some View {
        ZStack {
            Circle()
                .fill(Color.Text.primary.opacity(0.05))
                .frame(width: 40, height: 40)
            Image(systemName: "line.3.horizontal")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.Text.primary)
        }
    }
}

// MARK: - Title resolver

extension Ticket {
    /// Single line shown in the edit-mode row. Plane/train/transit use
    /// the location pair (city/city or station/station). Concert shows
    /// the artist. Falls back to a generic label.
    fileprivate var entryTitle: String {
        switch kind.categoryStyle {
        case .plane, .train:
            return cityToCity ?? String(localized: "Trip")
        case .publicTransit:
            return stationToStation ?? String(localized: "Trip")
        case .concert:
            return concertHeadline ?? String(localized: "Concert")
        default:
            return originLocation?.name ?? String(localized: "Ticket")
        }
    }

    private var cityToCity: String? {
        guard
            let from = originLocation?.city ?? originLocation?.name,
            let to   = destinationLocation?.city ?? destinationLocation?.name
        else { return nil }
        return "\(from) " + String(localized: "to") + " \(to)"
    }

    private var stationToStation: String? {
        guard
            let from = originLocation?.name,
            let to   = destinationLocation?.name
        else { return nil }
        return "\(from) " + String(localized: "to") + " \(to)"
    }

    private var concertHeadline: String? {
        if case .concert(let payload) = self.payload {
            let trimmed = payload.artist.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }
}
```

- [ ] **Step 2: Verify `ConcertTicket` has an `artist` field**

```bash
grep -n "var artist" "/Users/bearista/Documents/lumoria/Lumoria App/Lumoria App/templates/concert/concert/ConcertTicket.swift"
```
Expected: a `var artist: String` line. If the field is named differently (e.g. `headliner`), update the `concertHeadline` accessor in `Ticket.swift` to match.

- [ ] **Step 3: Build**

```bash
xcodebuild -scheme "Lumoria App" -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1' build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/components/TicketEntryRow.swift"
git commit -m "feat(component): TicketEntryRow"
```

---

### Task 10: `MemoryColorPickerSheet`

**Files:**
- Create: `Lumoria App/views/collections/MemoryColorPickerSheet.swift`

- [ ] **Step 1: Write the sheet**

```swift
//
//  MemoryColorPickerSheet.swift
//  Lumoria App
//
//  Floating bottom-sheet for picking a memory's color family. 11
//  swatches in a 3-column flexible grid using the existing palette
//  tokens. Reset reverts to the initial color (no specific default
//  here — there's no system-wide "default" color), Done commits.
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=2028-143737
//

import SwiftUI

struct MemoryColorPickerSheet: View {

    let initialColor: ColorOption
    let onCommit: (ColorOption) -> Void
    let onDismiss: () -> Void

    @State private var selection: ColorOption

    private static let columns = [
        GridItem(.adaptive(minimum: 80, maximum: 80), spacing: 8)
    ]

    init(
        initialColor: ColorOption,
        onCommit: @escaping (ColorOption) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.initialColor = initialColor
        self.onCommit = onCommit
        self.onDismiss = onDismiss
        _selection = State(initialValue: initialColor)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Color")
                .font(.title2.bold())
                .foregroundStyle(Color.Text.primary)

            LazyVGrid(columns: Self.columns, spacing: 8) {
                ForEach(ColorOption.all) { option in
                    swatch(option)
                }
            }

            HStack(spacing: 12) {
                Button("Reset") { selection = initialColor }
                    .buttonStyle(LumoriaButtonStyle(hierarchy: .secondary, size: .large))

                Button("Done") {
                    onCommit(selection)
                    onDismiss()
                }
                .buttonStyle(LumoriaButtonStyle(hierarchy: .primary, size: .large))
            }
        }
        .padding(24)
    }

    private func swatch(_ option: ColorOption) -> some View {
        let isSelected = selection.family == option.family
        return Button {
            selection = option
        } label: {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(option.swatchColor)
                .frame(width: 80, height: 80)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            isSelected ? Color.Text.primary : Color.Border.default,
                            lineWidth: isSelected ? 3 : 1
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.name)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    MemoryColorPickerSheet(
        initialColor: ColorOption.all.first(where: { $0.family == "Orange" })
            ?? ColorOption.all[0],
        onCommit: { _ in },
        onDismiss: { }
    )
}
```

- [ ] **Step 2: Verify `ColorOption.swatchColor` exists**

```bash
grep -n "swatchColor\|var name" "/Users/bearista/Documents/lumoria/Lumoria App/Lumoria App/components/"*.swift | head -10
```
Expected: a `swatchColor` accessor (used by `EditCollectionView`).

- [ ] **Step 3: Build**

```bash
xcodebuild -scheme "Lumoria App" -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1' build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/views/collections/MemoryColorPickerSheet.swift"
git commit -m "feat(memory): MemoryColorPickerSheet"
```

---

### Task 11: `MemoryEditMode` — buffered edits + UI

**Files:**
- Create: `Lumoria App/views/collections/MemoryEditMode.swift`

- [ ] **Step 1: Build the view**

```swift
//
//  MemoryEditMode.swift
//  Lumoria App
//
//  Inline edit mode for `MemoryDetailView`. Shows a tappable emoji card
//  + inline-editable name card + draggable list of `TicketEntryRow`s.
//  Top-bar buttons: color picker (opens `MemoryColorPickerSheet`) and
//  green Done (commits buffered edits via the stores and exits).
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=2028-142207
//

import SwiftUI

struct MemoryEditMode: View {

    let memory: Memory
    let tickets: [Ticket]
    let onExit: () -> Void

    @EnvironmentObject private var memoriesStore: MemoriesStore
    @EnvironmentObject private var ticketsStore: TicketsStore

    // Buffered draft state.
    @State private var emoji: String?
    @State private var name: String
    @State private var colorFamily: String
    @State private var orderedTicketIds: [UUID]

    @State private var showColorPicker = false
    @FocusState private var emojiFieldFocused: Bool

    init(memory: Memory, tickets: [Ticket], onExit: @escaping () -> Void) {
        self.memory = memory
        self.tickets = tickets
        self.onExit = onExit
        _emoji = State(initialValue: memory.emoji)
        _name = State(initialValue: memory.name)
        _colorFamily = State(initialValue: memory.colorFamily)
        _orderedTicketIds = State(
            initialValue: tickets.map(\.id)
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            tintBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        emojiCard
                        nameCard
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
                .frame(maxHeight: 320)

                ticketsList
            }
        }
        .floatingBottomSheet(isPresented: $showColorPicker) {
            MemoryColorPickerSheet(
                initialColor: ColorOption.all.first(where: { $0.family == colorFamily })
                    ?? memory.colorOption
                    ?? ColorOption.all[0],
                onCommit: { option in colorFamily = option.family },
                onDismiss: { showColorPicker = false }
            )
        }
    }

    // MARK: - Background

    private var tintBackground: Color {
        Color("Colors/\(colorFamily)/50")
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 8) {
            Button {
                showColorPicker = true
            } label: {
                Image(systemName: "paintbrush.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.Text.primary)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Color.Background.default))
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Button {
                Task { await commit() }
            } label: {
                Image(systemName: "checkmark")
                    .font(.body.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Color("Colors/Green/500")))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Header cards

    private var emojiCard: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                emojiFieldFocused = true
            } label: {
                ZStack {
                    if let emoji, !emoji.isEmpty {
                        Text(emoji)
                            .font(.system(size: 36))
                    } else {
                        Text("🙂")
                            .font(.system(size: 36))
                            .opacity(0.3)
                    }
                }
                .frame(width: 96, height: 96)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.Text.primary.opacity(0.05))
                )
            }
            .buttonStyle(.plain)

            // Hidden text field that owns the emoji keyboard.
            EmojiTextField(text: Binding(
                get: { emoji ?? "" },
                set: { emoji = $0.isEmpty ? nil : String($0.last!) }
            ), isFocused: $emojiFieldFocused)
            .frame(width: 1, height: 1)
            .opacity(0.01)

            Image(systemName: "pencil")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.Text.primary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.Background.default))
                .offset(x: 12, y: -12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var nameCard: some View {
        TextField("Name", text: $name)
            .font(.title.bold())
            .foregroundStyle(Color.Text.primary)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.Text.primary.opacity(0.05))
            )
    }

    // MARK: - Tickets list

    private var ticketsList: some View {
        List {
            ForEach(orderedTickets) { ticket in
                TicketEntryRow(ticket: ticket)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 0, trailing: 16))
            }
            .onMove { source, dest in
                orderedTicketIds.move(fromOffsets: source, toOffset: dest)
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(.active))
        .scrollContentBackground(.hidden)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 32,
                topTrailingRadius: 32,
                style: .continuous
            )
            .fill(Color.Background.default)
        )
    }

    private var orderedTickets: [Ticket] {
        let byId = Dictionary(uniqueKeysWithValues: tickets.map { ($0.id, $0) })
        return orderedTicketIds.compactMap { byId[$0] }
    }

    // MARK: - Commit

    private func commit() async {
        // Persist text changes if anything moved.
        if name != memory.name
            || emoji != memory.emoji
            || colorFamily != memory.colorFamily {
            await memoriesStore.update(
                memory,
                name: name,
                colorFamily: colorFamily,
                emoji: emoji,
                startDate: memory.startDate,
                endDate: memory.endDate
            )
        }

        // Persist new order if it changed.
        let originalOrder = tickets.map(\.id)
        if originalOrder != orderedTicketIds {
            await memoriesStore.reorderTickets(
                in: memory.id,
                ordered: orderedTicketIds
            )
            await ticketsStore.load()
        }

        onExit()
    }
}

// MARK: - Emoji-only TextField (UIKit bridge)

private struct EmojiTextField: UIViewRepresentable {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.delegate = context.coordinator
        tf.text = text
        tf.tintColor = .clear
        tf.borderStyle = .none
        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.text = text
        if isFocused, !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !isFocused, uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text, isFocused: $isFocused) }

    final class Coordinator: NSObject, UITextFieldDelegate, UITextInputTraits {
        @Binding var text: String
        @FocusState.Binding var isFocused: Bool

        // Force the emoji keyboard to appear. iOS picks the keyboard based
        // on the text field's primary input mode; "emoji" is a reserved
        // language identifier that pins it.
        var keyboardType: UIKeyboardType { .default }

        init(text: Binding<String>, isFocused: FocusState<Bool>.Binding) {
            _text = text
            _isFocused = isFocused
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            // Accept only single emoji glyphs.
            if string.isEmpty { text = ""; return true }
            guard let scalar = string.unicodeScalars.first,
                  scalar.properties.isEmojiPresentation else { return false }
            text = string
            isFocused = false
            return false
        }
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild -scheme "Lumoria App" -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1' build 2>&1 | tail -10
```
Expected: BUILD SUCCEEDED. If `Color("Colors/Green/500")` is missing, fall back to `Color.green` with a TODO.

- [ ] **Step 3: Commit**

```bash
git add "Lumoria App/views/collections/MemoryEditMode.swift"
git commit -m "feat(memory): MemoryEditMode buffered editor"
```

---

### Task 12: Wire edit mode into `MemoryDetailView`

**Files:**
- Modify: `Lumoria App/views/collections/CollectionDetailView.swift`

- [ ] **Step 1: Add edit-mode state**

After the existing `@State private var showAddExistingTicket = false` line, add:

```swift
    @State private var isEditing = false
```

Remove the `@State private var showEdit = false` line (it drove the now-unused sheet).

- [ ] **Step 2: Replace the contextual menu's Edit handler**

In `menuItems`, replace:

```swift
            .init(title: "Edit") { showEdit = true },
```

with:

```swift
            .init(title: "Edit") { isEditing = true },
```

- [ ] **Step 3: Drop the EditCollectionView sheet**

Remove the `.sheet(isPresented: $showEdit, onDismiss: { previewColorFamily = nil }) { ... }` block from the body modifier chain.

- [ ] **Step 4: Branch on `isEditing` at the top of `body`**

Wrap the existing `body` content. Replace the current body with:

```swift
    var body: some View {
        Group {
            if isEditing {
                MemoryEditMode(
                    memory: currentMemory,
                    tickets: ticketsStore.tickets(in: memory.id),
                    onExit: { isEditing = false }
                )
            } else {
                readingModeBody
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(
            onboardingCoordinator.shouldHideTabBar ? .hidden : .visible,
            for: .tabBar
        )
        .onAppear {
            Analytics.track(.memoryOpened(
                source: .memory,
                ticketCount: ticketsStore.tickets(in: memory.id).count,
                memoryIdHash: AnalyticsIdentity.hashUUID(memory.id)
            ))
            if onboardingCoordinator.currentStep == .memoryCreated {
                Task { await onboardingCoordinator.advance(from: .memoryCreated) }
            }
        }
        .onboardingOverlay(
            step: .enterMemory,
            coordinator: onboardingCoordinator,
            anchorID: "memoryDetail.plus",
            tip: OnboardingTipCopy(
                title: "Create your first ticket",
                body: "Let's fill this memory with your first ticket. Tap the + button to start.",
                leadingEmoji: "😀"
            )
        )
        .navigationDestination(for: Ticket.self) { ticket in
            TicketDetailView(ticket: ticket)
        }
        .fullScreenCover(isPresented: $showNewTicket) {
            NewTicketFunnelView()
                .environmentObject(ticketsStore)
                .environmentObject(memoriesStore)
                .environmentObject(onboardingCoordinator)
        }
        .sheet(isPresented: $showAddExistingTicket) {
            AddExistingTicketSheet(memoryId: memory.id)
                .environmentObject(ticketsStore)
        }
        .alert(
            "Delete this memory?",
            isPresented: $showDeleteConfirm
        ) {
            Button("Delete memory", role: .destructive) {
                Task {
                    await memoriesStore.delete(currentMemory)
                    dismiss()
                }
            }
            Button("Keep memory", role: .cancel) { }
        } message: {
            Text("Tickets stay in your gallery. Can’t be undone.")
        }
        .fullScreenCover(isPresented: $showMap) {
            MemoryMapView(
                memory: currentMemory,
                tickets: ticketsStore.tickets(in: memory.id)
            )
        }
    }

    /// Existing reading-mode UI (header, content card, ticket grid).
    /// Lifted from `body` so the edit-mode swap is a clean if/else.
    @ViewBuilder
    private var readingModeBody: some View {
        ZStack(alignment: .top) {
            Color.Background.default
                .ignoresSafeArea()

            tintBackground
                .frame(height: 420)
                .frame(maxWidth: .infinity, alignment: .top)
                .ignoresSafeArea(edges: [.top, .horizontal])
                .animation(.easeInOut(duration: 0.35), value: activeColorFamily)

            StickyBlurHeader(
                maxBlurRadius: 8,
                fadeExtension: 56,
                tintOpacityTop: 0,
                tintOpacityMiddle: 0
            ) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
            } content: {
                VStack(alignment: .leading, spacing: 0) {
                    title
                        .padding(.horizontal, 24)
                        .padding(.top, 64)
                        .padding(.bottom, 64)

                    contentCard
                }
            }
        }
    }
```

The original `body` had an extra `.sheet` for `showEdit`; you removed that in Step 3. Confirm with `git diff` that no other references to `showEdit` or `previewColorFamily` remain.

- [ ] **Step 5: Drop unused state**

Remove `@State private var previewColorFamily: String?` and the `colorFamily(for:)` references that fed it. The `activeColorFamily` simplifies to:

```swift
    private var activeColorFamily: String {
        currentMemory.colorFamily
    }
```

- [ ] **Step 6: Build**

```bash
xcodebuild -scheme "Lumoria App" -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1' build 2>&1 | tail -10
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 7: Commit**

```bash
git add "Lumoria App/views/collections/CollectionDetailView.swift"
git commit -m "feat(memory): inline edit mode in detail view"
```

---

### Task 13: Manual simulator QA

This is a verification task — no code is written. Refer to `superpowers:verification-before-completion`.

- [ ] **Step 1: Boot the app** and open a memory with at least 4 tickets across templates.

- [ ] **Step 2: Run the matrix**

| Action | Expected |
|---|---|
| Tap ⋯ → Edit | View swaps; top bar shows bucket + green ✓; emoji + name cards appear; ticket grid swaps to compact rows |
| Tap emoji card | Emoji keyboard appears; pick → emoji updates locally |
| Tap name card | Cursor enters; type → name updates locally |
| Tap bucket icon | Color sheet appears; pick → header tint changes; Done dismisses |
| Drag a row | Other rows shift; release commits new order locally (Done writes to DB) |
| Tap ✓ | Returns to reading mode; changes persisted |
| Re-open memory | Header + grid reflect saved state; sort field is now `manual` if order changed |
| Pick a date sort in the sort sheet | Manual order is replaced; future opens use the chosen date sort |

- [ ] **Step 3: Note any defects** and patch as small follow-ups.

---

### Task 14: Changelog entry

Same caveat as the previous plan — confirm with the user where the marketing-site changelog mdx lives before writing.

- [ ] **Step 1: Confirm repo path with user**.
- [ ] **Step 2: Draft entry** following the existing JS-export frontmatter format.
- [ ] **Step 3: Commit** in whichever repo.

---

## Self-Review

**1. Spec coverage**

| Spec item | Task |
|---|---|
| Edit menu item enters edit mode | Task 12 (step 2) |
| Tappable emoji card | Task 11 (emojiCard + EmojiTextField) |
| Inline-editable name | Task 11 (nameCard) |
| Color picker bottom sheet | Task 10 |
| Ticket entry rows | Tasks 8, 9 |
| Drag-to-reorder | Task 11 (List + .onMove) |
| Manual order persistence | Tasks 1, 3, 4, 6 |
| Top-bar swaps to bucket + ✓ | Task 11 (topBar) |
| EditCollectionView unlinked, not deleted | Task 12 (step 2) |

**2. Placeholder scan** — none. Every code-changing step has the actual code.

**3. Type consistency**

- `MemorySortField.manual` raw value `"manual"` matches the SQL CHECK.
- `MemorySortField.pickerOptions` referenced in Task 2 step 2.
- `Ticket.displayOrderByMemory: [UUID: Int]` referenced in Tasks 4, 5, 9, 11.
- `MemoriesStore.reorderTickets(in:ordered:)` signature matches the call in Task 11 step 1 (commit method).
- `LumoriaCategoryTag(category:)` signature matches the call in Task 9 step 1.
- `TicketCategoryStyle.pillLabel` referenced in Task 8 step 1.
