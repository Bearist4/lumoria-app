# Social Media Export Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unlock the "Social Media" destination in `ExportSheet` so users can save a ticket image pre-composed for 5 social formats (Square, Story, Facebook, Instagram, X) to their camera roll in one tap.

**Architecture:** New Phase C `SocialView` inside `ExportSheet`, grid of `SocialFormatTile`s, each tile driving a dedicated `*RenderView` for the format. Render views mirror the existing `IMShareRenderView` pattern — SwiftUI composition, watermark + background baked in, rendered via `ImageRenderer`, saved via `UIImageWriteToSavedPhotosAlbum`. No toggles, no share-sheet integrations. Spec: `docs/superpowers/specs/2026-04-20-social-export-design.md`.

**Tech Stack:** SwiftUI, ImageRenderer, UIImageWriteToSavedPhotosAlbum, Swift Testing (@Suite/@Test/#expect), Amplitude analytics via existing `Analytics.track`.

---

## File Structure

```
Lumoria App/views/tickets/new/
├── ExportSheet.swift                    (modify)
└── social/                              (new dir)
    ├── SocialFormat.swift               (enum + canvas specs + analytics map)
    ├── SocialView.swift                 (Phase C grid screen)
    ├── SocialFormatTile.swift           (grid card: thumbnail + label)
    └── renders/
        ├── SquareRenderView.swift       (1080×1080)
        ├── StoryRenderView.swift        (1080×1920, hero + supplementary)
        ├── FacebookRenderView.swift     (1080×1359, hero + detail crop)
        ├── InstagramRenderView.swift    (1080×1350, hero + detail crop)
        └── XRenderView.swift            (720×1280)

Lumoria App/services/analytics/
└── AnalyticsProperty.swift              (modify: 5 new destination cases)

Lumoria AppTests/
└── AnalyticsEventTests.swift            (modify: coverage for new cases)
```

Responsibilities:

- `SocialFormat.swift` — single source of truth: canvas size, section grouping, analytics destination, display title, platform icon asset name. No SwiftUI.
- `SocialView.swift` — owns `isSaving: SocialFormat?`, `toastMessage: String?`; renders grid by section; dispatches render+save; calls back to `ExportSheet` on dismiss-requested.
- `SocialFormatTile.swift` — presentation-only tile with thumbnail (scaled render view) + platform label + loading overlay.
- `renders/*.swift` — each view takes `Ticket`, renders at native canvas size, handles both orientations, bakes watermark + background. No environment toggles. Reused for both thumbnails and final `ImageRenderer` output.

## Figma reference (source of truth during implementation)

| Format | Vertical ticket | Horizontal ticket | Size |
|---|---|---|---|
| Square | `1107:25828` | `1774:85646` | 1080×1080 |
| Story | `1107:25832` | `1774:85649` | 1080×1920 |
| Facebook | `1107:25827` | `1774:85647` | 1080×1359 |
| Instagram | `1107:25830` | `1774:85648` | 1080×1350 |
| X | `1107:25829` | `1774:85645` | 720×1280 |

File key: `09xVBFOsdBBcmbA0Iql3qv`. Sheet: `1109:31332`.

When a render-view task runs, the implementer MUST pull `get_design_context` on the two frames for that format to read the exact hero position, supplementary ticket positions/rotations/scales, and watermark placement. The tasks below include the exact tool call.

---

## Task 1: `SocialFormat` enum with tests

**Files:**
- Create: `Lumoria App/views/tickets/new/social/SocialFormat.swift`
- Modify: `Lumoria App/services/analytics/AnalyticsProperty.swift` (add 5 cases)
- Test: `Lumoria AppTests/SocialFormatTests.swift` (new)

- [ ] **Step 1: Add the 5 new `ExportDestinationProp` cases**

Edit `Lumoria App/services/analytics/AnalyticsProperty.swift` lines 25-28. Replace:

```swift
enum ExportDestinationProp: String, CaseIterable {
    case camera_roll, whatsapp, messenger, discord
    case instagram, twitter, threads, snapchat, facebook
}
```

with:

```swift
enum ExportDestinationProp: String, CaseIterable {
    case camera_roll, whatsapp, messenger, discord
    case instagram, twitter, threads, snapchat, facebook
    case social_square, social_story, social_facebook, social_instagram, social_x
}
```

- [ ] **Step 2: Write the failing test for `SocialFormat` metadata**

Create `Lumoria AppTests/SocialFormatTests.swift`:

```swift
import Foundation
import Testing
@testable import Lumoria_App

@Suite("SocialFormat")
struct SocialFormatTests {

    @Test("all cases have unique canvas sizes")
    func uniqueCanvasSizes() {
        let sizes = SocialFormat.allCases.map { $0.canvasSize }
        #expect(Set(sizes.map { "\($0.width)x\($0.height)" }).count == sizes.count)
    }

    @Test("canvas sizes match Figma frames")
    func canvasSizes() {
        #expect(SocialFormat.square.canvasSize    == CGSize(width: 1080, height: 1080))
        #expect(SocialFormat.story.canvasSize     == CGSize(width: 1080, height: 1920))
        #expect(SocialFormat.facebook.canvasSize  == CGSize(width: 1080, height: 1359))
        #expect(SocialFormat.instagram.canvasSize == CGSize(width: 1080, height: 1350))
        #expect(SocialFormat.x.canvasSize         == CGSize(width:  720, height: 1280))
    }

    @Test("section grouping matches Figma sheet")
    func sections() {
        #expect(SocialFormat.square.section    == .defaultFormats)
        #expect(SocialFormat.story.section     == .defaultFormats)
        #expect(SocialFormat.facebook.section  == .vertical)
        #expect(SocialFormat.instagram.section == .vertical)
        #expect(SocialFormat.x.section         == .vertical)
    }

    @Test("analytics destinations are distinct per format")
    func analyticsDestinations() {
        #expect(SocialFormat.square.analyticsDestination    == .social_square)
        #expect(SocialFormat.story.analyticsDestination     == .social_story)
        #expect(SocialFormat.facebook.analyticsDestination  == .social_facebook)
        #expect(SocialFormat.instagram.analyticsDestination == .social_instagram)
        #expect(SocialFormat.x.analyticsDestination         == .social_x)
    }
}
```

- [ ] **Step 3: Run test — expect FAIL (SocialFormat undefined)**

Run: `xcodebuild test -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 16 Pro" -only-testing:"Lumoria AppTests/SocialFormatTests" 2>&1 | tail -40`

Expected: compile error "cannot find type 'SocialFormat' in scope".

- [ ] **Step 4: Implement `SocialFormat`**

Create `Lumoria App/views/tickets/new/social/SocialFormat.swift`:

```swift
//
//  SocialFormat.swift
//  Lumoria App
//
//  Single source of truth for every export format in the Social Media
//  destination. Encodes canvas size (matches the Figma frame), which
//  grid section the tile sits in, its analytics destination, and the
//  platform icon asset name.
//
//  Figma frame index: see
//  docs/superpowers/specs/2026-04-20-social-export-design.md.
//

import Foundation
import SwiftUI

enum SocialFormat: String, CaseIterable, Identifiable {
    case square
    case story
    case facebook
    case instagram
    case x

    var id: String { rawValue }

    enum Section {
        case defaultFormats
        case vertical
    }

    var section: Section {
        switch self {
        case .square, .story:                  return .defaultFormats
        case .facebook, .instagram, .x:        return .vertical
        }
    }

    var canvasSize: CGSize {
        switch self {
        case .square:    return CGSize(width: 1080, height: 1080)
        case .story:     return CGSize(width: 1080, height: 1920)
        case .facebook:  return CGSize(width: 1080, height: 1359)
        case .instagram: return CGSize(width: 1080, height: 1350)
        case .x:         return CGSize(width:  720, height: 1280)
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .square:    return "Square"
        case .story:     return "Story"
        case .facebook:  return "Facebook"
        case .instagram: return "Instagram"
        case .x:         return "X"
        }
    }

    /// Asset catalog path for the small platform logo shown beside the
    /// label in the grid tile. Reuses the export/social brand icons
    /// already used by the destinations card in Phase A.
    var platformIconAssetName: String? {
        switch self {
        case .square, .story:   return nil            // no platform logo
        case .facebook:         return "export/social/Facebook"
        case .instagram:        return "export/social/IG"
        case .x:                return "export/social/X"
        }
    }

    var analyticsDestination: ExportDestinationProp {
        switch self {
        case .square:    return .social_square
        case .story:     return .social_story
        case .facebook:  return .social_facebook
        case .instagram: return .social_instagram
        case .x:         return .social_x
        }
    }
}
```

- [ ] **Step 5: Run tests — expect PASS**

Run: `xcodebuild test -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 16 Pro" -only-testing:"Lumoria AppTests/SocialFormatTests" 2>&1 | tail -20`

Expected: "Test Suite 'SocialFormatTests' passed" with 4 tests.

- [ ] **Step 6: Extend `AnalyticsEventTests` with round-trip coverage for a new case**

Append to `Lumoria AppTests/AnalyticsEventTests.swift` inside the existing `@Suite("AnalyticsEvent") struct AnalyticsEventTests`:

```swift
    @Test("ticketExported for social formats emits social_ destination keys")
    func ticketExportedSocialShape() {
        let event = AnalyticsEvent.ticketExported(
            destination: .social_story,
            resolution: nil, crop: nil, format: nil,
            includeBackground: nil, includeWatermark: nil,
            durationMs: 240
        )
        #expect(event.name == "Ticket Exported")
        let props = event.properties
        #expect(props["export_destination"] as? String == "social_story")
        #expect(props["duration_ms"] as? Int == 240)
        #expect(props["export_resolution"] == nil)
        #expect(props["export_format"] == nil)
    }
```

- [ ] **Step 7: Run full analytics + social-format suites — expect PASS**

Run: `xcodebuild test -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 16 Pro" -only-testing:"Lumoria AppTests/SocialFormatTests" -only-testing:"Lumoria AppTests/AnalyticsEventTests" 2>&1 | tail -20`

Expected: all tests pass.

- [ ] **Step 8: Commit**

```bash
git add "Lumoria App/views/tickets/new/social/SocialFormat.swift" \
        "Lumoria App/services/analytics/AnalyticsProperty.swift" \
        "Lumoria AppTests/SocialFormatTests.swift" \
        "Lumoria AppTests/AnalyticsEventTests.swift"
git commit -m "feat(social-export): SocialFormat enum + analytics destinations"
```

---

## Task 2: `SquareRenderView` (simplest — single ticket centered)

**Files:**
- Create: `Lumoria App/views/tickets/new/social/renders/SquareRenderView.swift`

**Before starting:** Pull the two Figma frames to confirm composition.

```
mcp__plugin_figma_figma__get_design_context(
    nodeId: "1107:25828",  // vertical ticket
    fileKey: "09xVBFOsdBBcmbA0Iql3qv"
)
mcp__plugin_figma_figma__get_design_context(
    nodeId: "1774:85646",  // horizontal ticket
    fileKey: "09xVBFOsdBBcmbA0Iql3qv"
)
```

Confirm: white background, single ticket centered, watermark baked in (horizontal: "Made with" pill inside ticket, vertical: "Made with" pill standalone bottom or inside ticket).

- [ ] **Step 1: Create the render view**

Create `Lumoria App/views/tickets/new/social/renders/SquareRenderView.swift`:

```swift
//
//  SquareRenderView.swift
//  Lumoria App
//
//  Off-screen composition for the Square (1080×1080) social export.
//  Ticket sits centered on a white canvas. Watermark is whatever the
//  ticket template already renders via `MadeWithLumoria`.
//
//  Figma:
//    Vertical ticket:   node 1107:25828
//    Horizontal ticket: node 1774:85646
//
//  Never shown in the interactive UI — used as the body handed to
//  `ImageRenderer`, and (at reduced size) as the source for the
//  tile thumbnail in `SocialFormatTile`.
//

import SwiftUI

struct SquareRenderView: View {

    let ticket: Ticket

    // Canvas matches Figma frame 1:1.
    private let canvas = CGSize(width: 1080, height: 1080)

    // Ticket occupies this fraction of the shorter canvas side. Gives
    // breathing room on all sides and matches the Figma inset.
    private let ticketBoundRatio: CGFloat = 0.82

    private var ticketAspect: CGFloat {
        ticket.orientation == .horizontal ? 455.0 / 260.0 : 260.0 / 455.0
    }

    private var ticketSize: CGSize {
        let shorter = min(canvas.width, canvas.height) * ticketBoundRatio
        switch ticket.orientation {
        case .horizontal:
            return CGSize(width: shorter, height: shorter / ticketAspect)
        case .vertical:
            return CGSize(width: shorter * ticketAspect, height: shorter)
        }
    }

    var body: some View {
        ZStack {
            Color.white

            TicketPreview(ticket: ticket)
                .aspectRatio(ticketAspect, contentMode: .fit)
                .frame(width: ticketSize.width, height: ticketSize.height)
                .environment(\.ticketFillsNotchCutouts, false)
                .shadow(color: Color.black.opacity(0.12), radius: 32, x: 0, y: 16)
        }
        .frame(width: canvas.width, height: canvas.height)
    }
}

// MARK: - Preview

private var previewHorizontal: Ticket {
    TicketsStore.sampleTickets.first { $0.orientation == .horizontal }
        ?? TicketsStore.sampleTickets[0]
}

private var previewVertical: Ticket {
    TicketsStore.sampleTickets.first { $0.orientation == .vertical }
        ?? TicketsStore.sampleTickets[0]
}

#Preview("Square — horizontal") {
    SquareRenderView(ticket: previewHorizontal)
        .scaleEffect(0.3)
        .frame(width: 324, height: 324)
}

#Preview("Square — vertical") {
    SquareRenderView(ticket: previewVertical)
        .scaleEffect(0.3)
        .frame(width: 324, height: 324)
}
```

- [ ] **Step 2: Build — expect success**

Run: `xcodebuild build -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 16 Pro" 2>&1 | tail -15`

Expected: "BUILD SUCCEEDED".

- [ ] **Step 3: Visually verify previews in Xcode**

Open `SquareRenderView.swift` in Xcode, open the canvas, run both previews. Confirm:
- White background fills the frame.
- Ticket is centered.
- Watermark ("Made with" pill) is visible inside or at the ticket's edge (template-dependent).
- Horizontal ticket is wider than tall; vertical ticket is taller than wide — neither is rotated or clipped.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/views/tickets/new/social/renders/SquareRenderView.swift"
git commit -m "feat(social-export): SquareRenderView 1080x1080"
```

---

## Task 3: `XRenderView` (simple vertical — single ticket centered)

**Files:**
- Create: `Lumoria App/views/tickets/new/social/renders/XRenderView.swift`

**Before starting:** Pull Figma.

```
mcp__plugin_figma_figma__get_design_context(nodeId: "1107:25829", fileKey: "09xVBFOsdBBcmbA0Iql3qv")
mcp__plugin_figma_figma__get_design_context(nodeId: "1774:85645", fileKey: "09xVBFOsdBBcmbA0Iql3qv")
```

Confirm: 720×1280, white bg, single hero ticket centered, watermark baked in.

- [ ] **Step 1: Create the render view**

Create `Lumoria App/views/tickets/new/social/renders/XRenderView.swift`:

```swift
//
//  XRenderView.swift
//  Lumoria App
//
//  Off-screen composition for the X / Twitter (720×1280) social export.
//  Ticket centered on a white canvas — vertical canvas gives vertical
//  tickets room to breathe and a narrow hero for horizontal tickets.
//
//  Figma:
//    Vertical ticket:   node 1107:25829
//    Horizontal ticket: node 1774:85645
//

import SwiftUI

struct XRenderView: View {

    let ticket: Ticket

    private let canvas = CGSize(width: 720, height: 1280)

    // Vertical tickets get more of the canvas (taller hero), horizontal
    // tickets stay narrower since they're already wide.
    private var ticketBoundRatio: CGFloat {
        ticket.orientation == .vertical ? 0.82 : 0.88
    }

    private var ticketAspect: CGFloat {
        ticket.orientation == .horizontal ? 455.0 / 260.0 : 260.0 / 455.0
    }

    private var ticketSize: CGSize {
        switch ticket.orientation {
        case .horizontal:
            let w = canvas.width * ticketBoundRatio
            return CGSize(width: w, height: w / ticketAspect)
        case .vertical:
            let h = canvas.height * 0.62
            return CGSize(width: h * ticketAspect, height: h)
        }
    }

    var body: some View {
        ZStack {
            Color.white

            TicketPreview(ticket: ticket)
                .aspectRatio(ticketAspect, contentMode: .fit)
                .frame(width: ticketSize.width, height: ticketSize.height)
                .environment(\.ticketFillsNotchCutouts, false)
                .shadow(color: Color.black.opacity(0.12), radius: 32, x: 0, y: 16)
        }
        .frame(width: canvas.width, height: canvas.height)
    }
}

// MARK: - Preview

private var previewHorizontal: Ticket {
    TicketsStore.sampleTickets.first { $0.orientation == .horizontal }
        ?? TicketsStore.sampleTickets[0]
}

private var previewVertical: Ticket {
    TicketsStore.sampleTickets.first { $0.orientation == .vertical }
        ?? TicketsStore.sampleTickets[0]
}

#Preview("X — horizontal") {
    XRenderView(ticket: previewHorizontal)
        .scaleEffect(0.25)
        .frame(width: 180, height: 320)
}

#Preview("X — vertical") {
    XRenderView(ticket: previewVertical)
        .scaleEffect(0.25)
        .frame(width: 180, height: 320)
}
```

- [ ] **Step 2: Build — expect success**

Run: `xcodebuild build -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 16 Pro" 2>&1 | tail -10`

Expected: "BUILD SUCCEEDED".

- [ ] **Step 3: Visually verify previews**

Confirm in Xcode canvas: vertical ticket fills most of the canvas height, horizontal ticket is wide but centered with generous top/bottom margins.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/views/tickets/new/social/renders/XRenderView.swift"
git commit -m "feat(social-export): XRenderView 720x1280"
```

---

## Task 4: `StoryRenderView` (1080×1920 — hero + 2 supplementary)

**Files:**
- Create: `Lumoria App/views/tickets/new/social/renders/StoryRenderView.swift`

**Before starting:** Pull Figma — this frame has the most layered composition.

```
mcp__plugin_figma_figma__get_design_context(nodeId: "1107:25832", fileKey: "09xVBFOsdBBcmbA0Iql3qv")
mcp__plugin_figma_figma__get_design_context(nodeId: "1774:85649", fileKey: "09xVBFOsdBBcmbA0Iql3qv")
```

Read out: hero ticket position + size (top portion), the two supplementary mini tickets at the bottom (one cropped-detail view, one rotated isometric), and the `Made with Lumoria` wordmark placement. Note the exact y-offsets and rotation angles from the Figma `x`, `y`, `rotation` properties.

- [ ] **Step 1: Create the render view with the hero + placeholders for supplementary**

Create `Lumoria App/views/tickets/new/social/renders/StoryRenderView.swift`:

```swift
//
//  StoryRenderView.swift
//  Lumoria App
//
//  Off-screen composition for the Story (1080×1920) social export.
//  Matches Figma frames 1107:25832 (vertical ticket) and 1774:85649
//  (horizontal ticket).
//
//  Layout:
//    - White canvas.
//    - Hero ticket in the upper ~55% of the frame.
//    - Two supplementary compositions in the lower ~35%:
//        · cropped bottom-slice of the same ticket (shows perforation +
//          "Made with" pill detail)
//        · rotated isometric mini-ticket (decorative, ~12° tilt)
//    - Watermark is embedded in the hero ticket's own template.
//
//  Coordinates come from Figma; adjust during visual review.
//

import SwiftUI

struct StoryRenderView: View {

    let ticket: Ticket

    private let canvas = CGSize(width: 1080, height: 1920)

    private var ticketAspect: CGFloat {
        ticket.orientation == .horizontal ? 455.0 / 260.0 : 260.0 / 455.0
    }

    // Hero ticket — upper half.
    private var heroSize: CGSize {
        let maxHeight = canvas.height * 0.55
        let maxWidth  = canvas.width * 0.82
        switch ticket.orientation {
        case .horizontal:
            let w = min(maxWidth, maxHeight * ticketAspect)
            return CGSize(width: w, height: w / ticketAspect)
        case .vertical:
            let h = maxHeight
            return CGSize(width: h * ticketAspect, height: h)
        }
    }
    private let heroTopInset: CGFloat = 140   // from Figma top

    // Supplementary — cropped detail + rotated mini.
    private let detailSize  = CGSize(width: 520, height: 300)
    private let rotatedSize = CGSize(width: 440, height: 260)
    private let supplementaryTop: CGFloat = 1320
    private let rotatedAngle: Double = -12

    var body: some View {
        ZStack(alignment: .top) {
            Color.white

            // Hero
            TicketPreview(ticket: ticket)
                .aspectRatio(ticketAspect, contentMode: .fit)
                .frame(width: heroSize.width, height: heroSize.height)
                .environment(\.ticketFillsNotchCutouts, false)
                .shadow(color: Color.black.opacity(0.12), radius: 40, x: 0, y: 20)
                .position(x: canvas.width / 2,
                          y: heroTopInset + heroSize.height / 2)

            // Supplementary: cropped detail (bottom slice of the same ticket).
            TicketPreview(ticket: ticket)
                .aspectRatio(ticketAspect, contentMode: .fit)
                .frame(width: detailSize.width * 1.6,   // oversize so we can crop
                       height: detailSize.height * 1.6)
                .offset(y: detailSize.height * 0.55)    // push so the bottom is visible
                .frame(width: detailSize.width, height: detailSize.height, alignment: .top)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 8)
                .position(x: canvas.width * 0.34,
                          y: supplementaryTop + detailSize.height / 2)

            // Supplementary: rotated isometric mini.
            TicketPreview(ticket: ticket)
                .aspectRatio(ticketAspect, contentMode: .fit)
                .frame(width: rotatedSize.width, height: rotatedSize.height)
                .rotationEffect(.degrees(rotatedAngle))
                .shadow(color: Color.black.opacity(0.12), radius: 20, x: 0, y: 10)
                .position(x: canvas.width * 0.72,
                          y: supplementaryTop + rotatedSize.height / 2 + 20)
        }
        .frame(width: canvas.width, height: canvas.height)
        .clipped()
    }
}

// MARK: - Preview

private var previewHorizontal: Ticket {
    TicketsStore.sampleTickets.first { $0.orientation == .horizontal }
        ?? TicketsStore.sampleTickets[0]
}

private var previewVertical: Ticket {
    TicketsStore.sampleTickets.first { $0.orientation == .vertical }
        ?? TicketsStore.sampleTickets[0]
}

#Preview("Story — horizontal") {
    StoryRenderView(ticket: previewHorizontal)
        .scaleEffect(0.2)
        .frame(width: 216, height: 384)
}

#Preview("Story — vertical") {
    StoryRenderView(ticket: previewVertical)
        .scaleEffect(0.2)
        .frame(width: 216, height: 384)
}
```

- [ ] **Step 2: Build — expect success**

Run: `xcodebuild build -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 16 Pro" 2>&1 | tail -10`

- [ ] **Step 3: Visually verify against Figma**

Open both previews in Xcode. Compare side-by-side with the Figma frame screenshots (`get_screenshot` on `1107:25832` and `1774:85649`). Adjust `heroTopInset`, `supplementaryTop`, `rotatedAngle`, and the two supplementary x-positions until they visually match.

If the cropped-detail approach (oversizing + clipping to show the bottom) doesn't reproduce the Figma intent cleanly, fall back to: render a full TicketPreview at a small scale and let the rounded-rect clip handle the framing. Either is acceptable as long as it reads visually as "Made with Lumoria" focus.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/views/tickets/new/social/renders/StoryRenderView.swift"
git commit -m "feat(social-export): StoryRenderView 1080x1920 with supplementary"
```

---

## Task 5: `FacebookRenderView` (1080×1359 — hero + detail crop)

**Files:**
- Create: `Lumoria App/views/tickets/new/social/renders/FacebookRenderView.swift`

**Before starting:** Pull Figma.

```
mcp__plugin_figma_figma__get_design_context(nodeId: "1107:25827", fileKey: "09xVBFOsdBBcmbA0Iql3qv")
mcp__plugin_figma_figma__get_design_context(nodeId: "1774:85647", fileKey: "09xVBFOsdBBcmbA0Iql3qv")
```

Composition: hero ticket upper half, cropped detail view lower half showing the bottom of the ticket (airline / ticket number / perforation / `Made with` pill area blown up).

- [ ] **Step 1: Create the render view**

Create `Lumoria App/views/tickets/new/social/renders/FacebookRenderView.swift`:

```swift
//
//  FacebookRenderView.swift
//  Lumoria App
//
//  Off-screen composition for the Facebook vertical feed (1080×1359)
//  social export. Matches Figma frames 1107:25827 (vertical ticket)
//  and 1774:85647 (horizontal ticket).
//
//  Layout:
//    - White canvas.
//    - Hero ticket in the upper ~58%.
//    - Full-width cropped detail band in the lower ~42% — shows the
//      bottom half of the same ticket, blown up, cropped to an inset
//      rounded rectangle so the watermark + airline row are readable.
//

import SwiftUI

struct FacebookRenderView: View {

    let ticket: Ticket

    private let canvas = CGSize(width: 1080, height: 1359)

    private var ticketAspect: CGFloat {
        ticket.orientation == .horizontal ? 455.0 / 260.0 : 260.0 / 455.0
    }

    private var heroSize: CGSize {
        let maxHeight = canvas.height * 0.48
        let maxWidth  = canvas.width * 0.78
        switch ticket.orientation {
        case .horizontal:
            let w = min(maxWidth, maxHeight * ticketAspect)
            return CGSize(width: w, height: w / ticketAspect)
        case .vertical:
            let h = maxHeight
            return CGSize(width: h * ticketAspect, height: h)
        }
    }
    private let heroTopInset: CGFloat = 80

    // Detail band spans full width, flush bottom.
    private let detailHeight: CGFloat = 440
    private let detailSideInset: CGFloat = 40

    var body: some View {
        ZStack(alignment: .top) {
            Color.white

            // Hero
            TicketPreview(ticket: ticket)
                .aspectRatio(ticketAspect, contentMode: .fit)
                .frame(width: heroSize.width, height: heroSize.height)
                .environment(\.ticketFillsNotchCutouts, false)
                .shadow(color: Color.black.opacity(0.12), radius: 32, x: 0, y: 16)
                .position(x: canvas.width / 2,
                          y: heroTopInset + heroSize.height / 2)

            // Detail band (cropped bottom slice).
            TicketPreview(ticket: ticket)
                .aspectRatio(ticketAspect, contentMode: .fit)
                .frame(width: (canvas.width - detailSideInset * 2) * 1.6,
                       height: detailHeight * 1.6)
                .offset(y: detailHeight * 0.55)
                .frame(width: canvas.width - detailSideInset * 2,
                       height: detailHeight, alignment: .top)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 10)
                .position(x: canvas.width / 2,
                          y: canvas.height - detailHeight / 2 - 80)
        }
        .frame(width: canvas.width, height: canvas.height)
        .clipped()
    }
}

// MARK: - Preview

private var previewHorizontal: Ticket {
    TicketsStore.sampleTickets.first { $0.orientation == .horizontal }
        ?? TicketsStore.sampleTickets[0]
}

private var previewVertical: Ticket {
    TicketsStore.sampleTickets.first { $0.orientation == .vertical }
        ?? TicketsStore.sampleTickets[0]
}

#Preview("Facebook — horizontal") {
    FacebookRenderView(ticket: previewHorizontal)
        .scaleEffect(0.24)
        .frame(width: 259, height: 326)
}

#Preview("Facebook — vertical") {
    FacebookRenderView(ticket: previewVertical)
        .scaleEffect(0.24)
        .frame(width: 259, height: 326)
}
```

- [ ] **Step 2: Build — expect success**

Run: `xcodebuild build -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 16 Pro" 2>&1 | tail -10`

- [ ] **Step 3: Visually verify against Figma**

Compare previews with Figma screenshots for 1107:25827 and 1774:85647. Tweak `heroTopInset`, `detailHeight`, and `detailSideInset` until the composition matches.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/views/tickets/new/social/renders/FacebookRenderView.swift"
git commit -m "feat(social-export): FacebookRenderView 1080x1359"
```

---

## Task 6: `InstagramRenderView` (1080×1350 — near-clone of Facebook)

**Files:**
- Create: `Lumoria App/views/tickets/new/social/renders/InstagramRenderView.swift`

**Before starting:** Pull Figma.

```
mcp__plugin_figma_figma__get_design_context(nodeId: "1107:25830", fileKey: "09xVBFOsdBBcmbA0Iql3qv")
mcp__plugin_figma_figma__get_design_context(nodeId: "1774:85648", fileKey: "09xVBFOsdBBcmbA0Iql3qv")
```

Composition is near-identical to Facebook (4:5 aspect ratio with 9px height difference), so the layout math is the same. Use slightly different corner radius / inset if Figma deviates.

- [ ] **Step 1: Create the render view**

Create `Lumoria App/views/tickets/new/social/renders/InstagramRenderView.swift`:

```swift
//
//  InstagramRenderView.swift
//  Lumoria App
//
//  Off-screen composition for the Instagram vertical feed (1080×1350)
//  social export. Matches Figma frames 1107:25830 (vertical ticket)
//  and 1774:85648 (horizontal ticket).
//
//  Layout follows the same hero+detail pattern as Facebook — canvas is
//  just 9px shorter (4:5 IG vs 1080×1359 FB), so the math is identical
//  up to the canvas height.
//

import SwiftUI

struct InstagramRenderView: View {

    let ticket: Ticket

    private let canvas = CGSize(width: 1080, height: 1350)

    private var ticketAspect: CGFloat {
        ticket.orientation == .horizontal ? 455.0 / 260.0 : 260.0 / 455.0
    }

    private var heroSize: CGSize {
        let maxHeight = canvas.height * 0.48
        let maxWidth  = canvas.width * 0.78
        switch ticket.orientation {
        case .horizontal:
            let w = min(maxWidth, maxHeight * ticketAspect)
            return CGSize(width: w, height: w / ticketAspect)
        case .vertical:
            let h = maxHeight
            return CGSize(width: h * ticketAspect, height: h)
        }
    }
    private let heroTopInset: CGFloat = 80

    private let detailHeight: CGFloat = 440
    private let detailSideInset: CGFloat = 40

    var body: some View {
        ZStack(alignment: .top) {
            Color.white

            TicketPreview(ticket: ticket)
                .aspectRatio(ticketAspect, contentMode: .fit)
                .frame(width: heroSize.width, height: heroSize.height)
                .environment(\.ticketFillsNotchCutouts, false)
                .shadow(color: Color.black.opacity(0.12), radius: 32, x: 0, y: 16)
                .position(x: canvas.width / 2,
                          y: heroTopInset + heroSize.height / 2)

            TicketPreview(ticket: ticket)
                .aspectRatio(ticketAspect, contentMode: .fit)
                .frame(width: (canvas.width - detailSideInset * 2) * 1.6,
                       height: detailHeight * 1.6)
                .offset(y: detailHeight * 0.55)
                .frame(width: canvas.width - detailSideInset * 2,
                       height: detailHeight, alignment: .top)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 10)
                .position(x: canvas.width / 2,
                          y: canvas.height - detailHeight / 2 - 80)
        }
        .frame(width: canvas.width, height: canvas.height)
        .clipped()
    }
}

// MARK: - Preview

private var previewHorizontal: Ticket {
    TicketsStore.sampleTickets.first { $0.orientation == .horizontal }
        ?? TicketsStore.sampleTickets[0]
}

private var previewVertical: Ticket {
    TicketsStore.sampleTickets.first { $0.orientation == .vertical }
        ?? TicketsStore.sampleTickets[0]
}

#Preview("Instagram — horizontal") {
    InstagramRenderView(ticket: previewHorizontal)
        .scaleEffect(0.24)
        .frame(width: 259, height: 324)
}

#Preview("Instagram — vertical") {
    InstagramRenderView(ticket: previewVertical)
        .scaleEffect(0.24)
        .frame(width: 259, height: 324)
}
```

- [ ] **Step 2: Build — expect success**

Run: `xcodebuild build -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 16 Pro" 2>&1 | tail -10`

- [ ] **Step 3: Visually verify against Figma**

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/views/tickets/new/social/renders/InstagramRenderView.swift"
git commit -m "feat(social-export): InstagramRenderView 1080x1350"
```

---

## Task 7: `SocialFormatTile` grid card

**Files:**
- Create: `Lumoria App/views/tickets/new/social/SocialFormatTile.swift`

- [ ] **Step 1: Create the tile view**

Create `Lumoria App/views/tickets/new/social/SocialFormatTile.swift`:

```swift
//
//  SocialFormatTile.swift
//  Lumoria App
//
//  Grid card used in `SocialView`. Shows a scaled-down render of the
//  ticket inside the target format's canvas, plus the platform label
//  (and icon, if any). Tap triggers the save flow in the parent view.
//  A loading overlay is shown while the parent is rendering this
//  format to a UIImage.
//

import SwiftUI

struct SocialFormatTile: View {

    let format: SocialFormat
    let ticket: Ticket
    let isLoading: Bool
    let action: () -> Void

    // Inner tile width (host 2-col grid places them at ~199pt each; this
    // is the preview box inside).
    private let previewHeight: CGFloat = 298
    private let previewCorner: CGFloat = 14

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                preview
                label
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.Background.elevated)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    @ViewBuilder
    private var preview: some View {
        // Scale the native canvas so the previewHeight is the longer
        // side inside the tile. The render view is the source of truth;
        // no separate thumbnail layout.
        let scale = previewHeight / format.canvasSize.height
        let previewWidth = format.canvasSize.width * scale

        ZStack {
            RoundedRectangle(cornerRadius: previewCorner, style: .continuous)
                .fill(Color.white)

            renderView
                .frame(width: format.canvasSize.width,
                       height: format.canvasSize.height)
                .scaleEffect(scale, anchor: .center)
                .frame(width: previewWidth, height: previewHeight)
        }
        .frame(width: previewWidth, height: previewHeight)
        .clipShape(RoundedRectangle(cornerRadius: previewCorner, style: .continuous))
        .overlay {
            if isLoading {
                ZStack {
                    Color.black.opacity(0.35)
                    ProgressView()
                        .tint(.white)
                        .controlSize(.large)
                }
                .clipShape(RoundedRectangle(cornerRadius: previewCorner, style: .continuous))
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }

    @ViewBuilder
    private var renderView: some View {
        switch format {
        case .square:    SquareRenderView(ticket: ticket)
        case .story:     StoryRenderView(ticket: ticket)
        case .facebook:  FacebookRenderView(ticket: ticket)
        case .instagram: InstagramRenderView(ticket: ticket)
        case .x:         XRenderView(ticket: ticket)
        }
    }

    @ViewBuilder
    private var label: some View {
        if let iconName = format.platformIconAssetName {
            HStack(spacing: 12) {
                Image(iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                Text(format.title)
                    .font(.headline)
                    .foregroundStyle(Color.Text.primary)
            }
        } else {
            Text(format.title)
                .font(.headline)
                .foregroundStyle(Color.Text.primary)
        }
    }
}

// MARK: - Preview

private var previewTicket: Ticket {
    TicketsStore.sampleTickets[0]
}

#Preview("All formats") {
    ScrollView {
        LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 10) {
            ForEach(SocialFormat.allCases) { format in
                SocialFormatTile(
                    format: format,
                    ticket: previewTicket,
                    isLoading: false,
                    action: {}
                )
            }
        }
        .padding(16)
    }
    .background(Color.Background.default)
}

#Preview("Loading state") {
    SocialFormatTile(
        format: .story,
        ticket: previewTicket,
        isLoading: true,
        action: {}
    )
    .frame(width: 199)
    .padding()
    .background(Color.Background.default)
}
```

- [ ] **Step 2: Build — expect success**

Run: `xcodebuild build -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 16 Pro" 2>&1 | tail -10`

- [ ] **Step 3: Visually verify previews**

Open the "All formats" preview. Confirm a 5-tile grid appears, each showing a miniature of its format's canvas with the ticket laid out correctly. Check the "Loading state" preview: the tile has a dark overlay + centered spinner.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/views/tickets/new/social/SocialFormatTile.swift"
git commit -m "feat(social-export): SocialFormatTile preview grid card"
```

---

## Task 8: `SocialView` (Phase C grid screen)

**Files:**
- Create: `Lumoria App/views/tickets/new/social/SocialView.swift`

**Before starting:** Pull Figma sheet design for exact grid layout, spacing, typography.

```
mcp__plugin_figma_figma__get_design_context(nodeId: "1109:31332", fileKey: "09xVBFOsdBBcmbA0Iql3qv")
```

- [ ] **Step 1: Create `SocialView`**

Create `Lumoria App/views/tickets/new/social/SocialView.swift`:

```swift
//
//  SocialView.swift
//  Lumoria App
//
//  Phase C of `ExportSheet`: grid of social format tiles. Tap a tile
//  to render the ticket for that format and save it to the photo
//  library. The sheet dismisses ~1.2s after a successful save.
//
//  Figma: 1109:31332
//

import SwiftUI
import UIKit

struct SocialView: View {

    let ticket: Ticket
    let onBack: () -> Void
    let onExported: () -> Void

    @State private var saving: SocialFormat? = nil
    @State private var toastMessage: String? = nil

    private let columns = [GridItem(.flexible(), spacing: 10),
                           GridItem(.flexible(), spacing: 10)]

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Social Media")
                        .font(.largeTitle.bold())
                        .foregroundStyle(Color.Text.primary)
                        .padding(.top, 8)

                    section(
                        title: "Default formats",
                        formats: SocialFormat.allCases.filter { $0.section == .defaultFormats }
                    )

                    section(
                        title: "Vertical",
                        formats: SocialFormat.allCases.filter { $0.section == .vertical }
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .lumoriaToast($toastMessage)
    }

    private var toolbar: some View {
        HStack {
            LumoriaIconButton(systemImage: "chevron.left", action: onBack)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func section(title: LocalizedStringKey, formats: [SocialFormat]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(Color.Text.primary)
                .padding(.top, 4)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(formats) { format in
                    SocialFormatTile(
                        format: format,
                        ticket: ticket,
                        isLoading: saving == format,
                        action: { Task { await save(format) } }
                    )
                }
            }
        }
    }

    @MainActor
    private func save(_ format: SocialFormat) async {
        guard saving == nil else { return }
        saving = format
        defer { saving = nil }

        Analytics.track(.exportDestinationSelected(destination: format.analyticsDestination))

        let start = Date()
        let renderer = ImageRenderer(content: renderView(for: format))
        renderer.scale = UIScreen.main.scale
        renderer.isOpaque = true

        guard let image = renderer.uiImage else {
            toastMessage = String(localized: "Couldn't render ticket.")
            Analytics.track(.ticketExportFailed(
                destination: format.analyticsDestination,
                errorType: "render_failed"
            ))
            return
        }

        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)

        let durationMs = Int(Date().timeIntervalSince(start) * 1000)
        Analytics.track(.ticketExported(
            destination: format.analyticsDestination,
            resolution: nil, crop: nil, format: .png,
            includeBackground: nil, includeWatermark: nil,
            durationMs: durationMs
        ))
        Analytics.updateUserProperties([
            "last_export_destination": format.analyticsDestination.rawValue
        ])

        toastMessage = String(localized: "Saved to Camera roll")
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        onExported()
    }

    @ViewBuilder
    private func renderView(for format: SocialFormat) -> some View {
        switch format {
        case .square:    SquareRenderView(ticket: ticket)
        case .story:     StoryRenderView(ticket: ticket)
        case .facebook:  FacebookRenderView(ticket: ticket)
        case .instagram: InstagramRenderView(ticket: ticket)
        case .x:         XRenderView(ticket: ticket)
        }
    }
}

// MARK: - Preview

private var previewTicket: Ticket {
    TicketsStore.sampleTickets[0]
}

#Preview("Social view") {
    SocialView(
        ticket: previewTicket,
        onBack: {},
        onExported: {}
    )
    .background(Color.Background.default)
}
```

- [ ] **Step 2: Build — expect success**

Run: `xcodebuild build -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 16 Pro" 2>&1 | tail -10`

- [ ] **Step 3: Visually verify preview**

Confirm: title "Social Media" top-left, "Default formats" section with Square + Story side-by-side, "Vertical" section with Facebook + Instagram on one row and X left-aligned on the next. All 5 tiles show live ticket previews.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/views/tickets/new/social/SocialView.swift"
git commit -m "feat(social-export): SocialView phase C grid screen"
```

---

## Task 9: Wire Phase C into `ExportSheet`

**Files:**
- Modify: `Lumoria App/views/tickets/new/ExportSheet.swift`

- [ ] **Step 1: Add the `.social` phase and switch branch**

In `Lumoria App/views/tickets/new/ExportSheet.swift`, update the `Phase` enum and the `body`:

Replace line 32:
```swift
    enum Phase { case destinations, cameraRoll }
```
with:
```swift
    enum Phase { case destinations, cameraRoll, social }
```

Inside `body`, the current `switch phase` has two cases. Add a third after `.cameraRoll`:

```swift
            case .social:
                SocialView(
                    ticket: ticket,
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            phase = .destinations
                        }
                    },
                    onExported: { dismiss() }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .trailing)
                ))
```

- [ ] **Step 2: Unlock the Social Media destination card and wire its tap**

In `DestinationsView.body`, find the existing Social Media card (lines 208-215):

```swift
                    destinationCard(
                        iconRow: AnyView(socialIconRow(.social)),
                        title: "Social Media",
                        subtitle: "Post your Lumoria ticket in your story or as a post.",
                        isEnabled: false,
                        isComingSoon: true,
                        action: {}
                    )
```

Replace with:

```swift
                    destinationCard(
                        iconRow: AnyView(socialIconRow(.social)),
                        title: "Social Media",
                        subtitle: "Post your Lumoria ticket in your story or as a post.",
                        isEnabled: true,
                        isComingSoon: false,
                        action: onSocial
                    )
```

Add an `onSocial` parameter to the `DestinationsView` struct (after `onInstantMessaging`, around line 189):

```swift
    let onSocial: () -> Void
```

- [ ] **Step 3: Pass the `onSocial` handler from `ExportSheet`**

In `ExportSheet.body`, the `.destinations` case currently constructs `DestinationsView(...)` with `onClose`, `onCameraRoll`, `onInstantMessaging`. Add `onSocial`:

```swift
                DestinationsView(
                    isPreparingIMShare: isPreparingIMShare,
                    onClose: { dismiss() },
                    onCameraRoll: {
                        Analytics.track(.exportDestinationSelected(destination: .camera_roll))
                        withAnimation(.easeInOut(duration: 0.25)) {
                            phase = .cameraRoll
                        }
                    },
                    onInstantMessaging: {
                        Analytics.track(.exportDestinationSelected(destination: .whatsapp))
                        Task { await handleIMShare() }
                    },
                    onSocial: {
                        // Per-format destination analytics fires inside SocialView
                        // on tile tap; this event just records that the user
                        // entered the social sub-flow.
                        withAnimation(.easeInOut(duration: 0.25)) {
                            phase = .social
                        }
                    }
                )
```

- [ ] **Step 4: Build and run the app on simulator — expect success**

Run: `xcodebuild build -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 16 Pro" 2>&1 | tail -15`

Expected: "BUILD SUCCEEDED".

- [ ] **Step 5: Manual QA**

Run the app on a simulator or device (`Lumoria App` scheme). For both a horizontal and a vertical sample ticket:

1. Open a ticket → tap Export → confirm the Social Media card is enabled (no "Coming soon" label, full opacity).
2. Tap Social Media — sheet slides left to Phase C with "Social Media" title and 5 tiles in 2 sections.
3. Tap the back chevron — confirm slide right back to Phase A.
4. Re-enter Phase C. Tap Square — tile shows a spinner, image saves to Photos, toast appears, sheet dismisses ~1.2s later. Open Photos, verify a 1080×1080 PNG at 2x/3x (= 2160² / 3240²) is present.
5. Repeat for Story, Facebook, Instagram, X. Verify dimensions = `canvas × UIScreen.main.scale`.
6. Trigger a rapid double-tap on one tile — confirm only one save fires, no duplicate image in Photos.
7. Tap Camera roll — confirm Phase B still works unchanged.
8. Tap Instant messaging — confirm activity sheet still works unchanged.

- [ ] **Step 6: Commit**

```bash
git add "Lumoria App/views/tickets/new/ExportSheet.swift"
git commit -m "feat(social-export): unlock Social card, wire SocialView phase"
```

---

## Task 10: Verify full test suite + stage for PR

- [ ] **Step 1: Run full test suite**

Run: `xcodebuild test -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 16 Pro" 2>&1 | tail -30`

Expected: all tests pass, including the 5 new `SocialFormatTests` and the expanded `AnalyticsEventTests`.

- [ ] **Step 2: Check git log and plan file**

Run: `git log --oneline main ^origin/main`

Expected output (plus the two earlier commits from this session):
```
feat(social-export): unlock Social card, wire SocialView phase
feat(social-export): SocialView phase C grid screen
feat(social-export): SocialFormatTile preview grid card
feat(social-export): InstagramRenderView 1080x1350
feat(social-export): FacebookRenderView 1080x1359
feat(social-export): StoryRenderView 1080x1920 with supplementary
feat(social-export): XRenderView 720x1280
feat(social-export): SquareRenderView 1080x1080
feat(social-export): SocialFormat enum + analytics destinations
```

- [ ] **Step 3: Final sanity scan of modified code**

Search for placeholder strings that shouldn't ship:

Run (via Grep tool): `TODO|FIXME|XXX` inside `Lumoria App/views/tickets/new/social/` and the modified `ExportSheet.swift`.

Expected: no hits related to this feature.

- [ ] **Step 4: Write a PR body**

Prepare (do not push) a PR body:

```
## Summary
- Unlocks the "Social Media" destination on `ExportSheet`
- Adds Phase C (SocialView) with a grid of 5 format tiles: Square, Story, Facebook, Instagram, X
- Each tile renders a dedicated SwiftUI composition per Figma and saves straight to the photo library
- Adds `SocialFormat` enum, 5 new `ExportDestinationProp` cases, per-format `ticketExported` analytics

## Test plan
- [ ] Open a horizontal ticket, tap Export → Social Media, save each format, verify PNG dimensions in Photos
- [ ] Same for a vertical ticket
- [ ] Back chevron returns to destinations list
- [ ] Rapid double-tap on one tile saves once
- [ ] Camera roll and Instant messaging flows unchanged
```

---

## Out of scope for this plan

- Pixel-perfect replication of the Story / FB / IG supplementary ticket compositions. Initial implementation approximates; visual review and Figma-comparison tweaks happen during the render-view tasks.
- Localization of the new strings beyond English. String catalog entries are inferred at build time from `LocalizedStringKey` usage; translators pick them up in the normal Localizable.xcstrings pass.
- Sharing via platform SDKs (Instagram Stories deep link, Snapchat Creative Kit). Explicit non-goal in the spec.
- Background / watermark / resolution toggles for social formats. Camera roll configurator remains the only flow that exposes those.
