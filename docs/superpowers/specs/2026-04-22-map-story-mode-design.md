# Map Story Mode — Design Spec

**Date:** 2026-04-22  
**Status:** Approved for implementation planning

---

## Overview

Transform the map view from a static pin browser into a narrative experience: the user steps through their tickets and journey anchors chronologically, ending on a shareable wrap screen. The feature is scoped to one memory at a time.

---

## Goals

- Make the map feel like a story the user can retell (to themselves, a friend, or on social)
- Give the journey a natural beginning, middle, and end
- Produce a shareable artifact without requiring a separate export flow

---

## Data Model Changes

### 1. Memory — date range

Add optional start and end dates to the `Memory` model:

```swift
var startDate: Date?
var endDate: Date?
```

Used in the Journey Wrap stats. Falls back to the earliest/latest ticket date if not set.

### 2. JourneyAnchor

A new model attached to a Memory representing a user-defined location that is not backed by a ticket (e.g. "Home – Paris", a hotel, a connecting city):

```swift
struct JourneyAnchor: Identifiable, Codable {
    var id: UUID
    var name: String
    var latitude: Double     // CLLocationCoordinate2D is not Codable; store raw values
    var longitude: Double
    var date: Date           // positions it in the chronological sequence
    var kind: AnchorKind     // .start | .end | .waypoint

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
```

A Memory has `[JourneyAnchor]`. Anchors are sorted by `date` when building the story sequence. There is no hard limit on anchor count, but the expected common case is one start + one end.

### 3. Segment distance

No new stored field. Distance per leg is computed on-demand using the Haversine formula between a stop's departure coordinate and the next stop's arrival coordinate. Total journey distance = sum of all leg distances across tickets + anchor-to-anchor gaps.

---

## Story Sequence

The ordered list of stops displayed in the film strip and on the map is built by merging and sorting:

- `JourneyAnchor` items from the memory
- Ticket origin/destination location pairs (each ticket contributes up to 2 stops)

Sorting key: `date`. Anchors use their explicit `date`; ticket origin locations use the ticket's date; ticket destination locations use the ticket's date as well (same day assumed for V1 — multi-day leg splitting is out of scope).

---

## UI — Story Mode

The map opens directly into Story Mode. No separate activation step.

### Film strip (bottom of screen)

- Horizontal scrollable strip pinned to the bottom of the map, above the safe area
- Each stop is a tile: 36pt rounded square
  - **Ticket stop:** category background color + category icon (matches existing `TicketMapPin` style)
  - **Anchor stop:** neutral dark background + house SF Symbol (`.start`/`.end`) or custom label icon (`.waypoint`)
- Tiles are connected by a thin horizontal rule between them
- **Active tile:** full opacity, white border ring, subtle glow
- **Past tiles:** full opacity, no ring
- **Future tiles:** dimmed to ~40% opacity
- Tapping any tile navigates directly to that stop (non-linear navigation allowed)

### Map state

- All pins are visible at all times (same teardrop style as today)
- A dotted polyline connects all stops in sequence order, drawn beneath pins
- Camera animates (`.animate`) to frame the active stop with a comfortable zoom level
- A floating mini card appears above the active pin: ticket title or anchor name + date in small subtitle text; dismissed automatically when the user taps a different stop

### Navigation

- No separate prev/next buttons — the film strip is the primary navigation control
- Tapping the last tile in the strip transitions to Journey Wrap
- Back button (top-left) dismisses the map as today

---

## UI — Journey Wrap

Reached by tapping the last tile in the film strip. Not accessible before reaching the last stop — there is no skip-ahead button.

### Layout (full-screen view; map snapshot top half, scrollable stats bottom half)

**Map area (top half):**
- Static `MKMapSnapshotter` render of the full route: all pins + dotted polyline
- Memory title overlaid top-center (semi-transparent pill)
- Map is not interactive in this state

**Stats strip:**
- 3-column grid: Stops · Countries · Distance
  - Stops = total tile count (anchors + ticket locations)
  - Countries = unique `countryCode` values across all ticket locations + anchors
  - Distance = Haversine sum across all legs, displayed in km (always km, no locale switching for V1)
- Date range row below grid: `"Apr 3 – Apr 12 · 10 days"` using `Memory.startDate`/`endDate`, falling back to min/max ticket dates

**Share action:**
- Primary button: "Share journey"
- Tap → renders the map snapshot + stats strip into a `UIImage` → `UIActivityViewController`
- No custom share sheet for V1; system share sheet is sufficient

---

## Out of Scope (V1)

- Auto-play / cinematic mode (user always drives navigation)
- Distance in miles / locale-aware unit switching
- Custom icons for `.waypoint` anchors
- Editing anchors from within the map view (anchors are created/edited in Memory settings)
- Video export

---

## Open Questions

- Where in the Memory editing UI do journey anchors get created and edited? (Not part of this spec — deferred to a Memory settings spec.)
- Should the dotted polyline be visible when the map first opens, before the user starts navigating? Tentatively yes — gives immediate context.
