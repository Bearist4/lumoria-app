# Social Media Export — Design

**Status:** Draft
**Date:** 2026-04-20
**Owner:** @benjamin
**Figma:** [Export Social sheet](https://www.figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1109-31332) · [frames index](#frame-index)

## Problem

The `ExportSheet` destinations list currently shows "Social Media" as a locked "Coming soon" tile. Users cannot export a ticket image sized and composed for specific social platforms. Current export paths only produce one canonical 4× ticket render (camera roll) or a 1200×1200 share card (instant messaging), neither of which fits Instagram Stories, Facebook feed, X, etc.

## Goals

1. Unlock the "Social Media" destination on `ExportSheet.DestinationsView`.
2. Let the user save a ticket image pre-composed for 5 social formats into their camera roll with a single tap, no additional configuration.
3. Render each format using its dedicated Figma composition (some formats include a hero ticket + supporting mini renditions — not just a resize).
4. Track format selection + save completion in Amplitude.

## Non-goals

- Direct posting via platform SDKs (Instagram Stories deep link, Snapchat Creative Kit, FB Share Dialog). Save-to-camera-roll is the entire v1 flow.
- User-adjustable background / watermark / resolution / format toggles for social exports. Those remain camera-roll-only.
- TikTok, Threads, LinkedIn, or any format not present in the Figma file as of 2026-04-20.
- Multi-format "save all" batch export.

## User flow

1. On the ticket detail screen, the user taps the existing export affordance → `ExportSheet` appears.
2. Phase A (`DestinationsView`) — the "Social Media" tile is no longer `isEnabled: false`. Tap it.
3. Horizontal slide transitions the sheet to a new **Phase C: `SocialView`** (same animation pattern `destinations ↔ cameraRoll` already uses).
4. Phase C shows:
   - Back chevron top-left, "Social Media" title.
   - Section **"Default formats"** — 2-column grid: `Square`, `Story`.
   - Section **"Vertical"** — 2-column grid: `Facebook`, `Instagram`, `X` (3 tiles; last row is a single tile left-aligned).
   - Each tile: thumbnail preview of the final composition for the current ticket + platform logo + label.
5. User taps a tile. The tapped tile enters a loading state (spinner + disabled look). Other tiles stay enabled but tapping another is ignored while one is rendering.
6. The view renders the chosen format via `ImageRenderer`, writes the resulting `UIImage` to the photo library via `UIImageWriteToSavedPhotosAlbum`, tracks analytics, surfaces a `lumoriaToast` with "Saved to Camera roll", and dismisses the sheet after ~1.2 s (matches existing camera-roll completion behaviour).
7. On render failure: toast "Couldn't render ticket." + `ticketExportFailed` analytics event. Sheet stays open so the user can retry or pick a different format.

## Architecture

### Format taxonomy

```swift
enum SocialFormat: String, CaseIterable, Identifiable {
    case square      // 1080 × 1080
    case story       // 1080 × 1920
    case facebook    // 1080 × 1359
    case instagram   // 1080 × 1350
    case x           // 720  × 1280
}
```

Each case encodes:
- Canvas size in points (matches Figma frame export size; renderer scale applied on top).
- Section (`.defaultFormats` / `.vertical`) for grid placement.
- Analytics destination mapping (see below).
- Localized title + platform icon asset name.

### View hierarchy

```
ExportSheet                              (existing, unchanged orchestrator)
├── DestinationsView    (Phase A)        (existing — unlock social card only)
├── CameraRollView      (Phase B)        (existing, unchanged)
└── SocialView          (Phase C, NEW)   (grid of format tiles)
    └── SocialFormatTile × 5             (preview thumbnail + label)
```

Render views (offscreen, used by both thumbnails and final export):

```
SquareRenderView
StoryRenderView
FacebookRenderView
InstagramRenderView
XRenderView
```

Each render view:
- Takes a `Ticket` and renders at its native canvas size (1080×1080, 1080×1920, …).
- Handles both ticket orientations internally (mirrors the pattern in `IMShareRenderView` which checks `ticket.orientation`).
- Bakes in watermark placement and background per Figma — no environment toggles, no conditional rendering paths.
- Is not inserted into the interactive view tree. It exists only as a SwiftUI body that `ImageRenderer` can materialize and as a thumbnail source inside `SocialFormatTile`.

### Thumbnail strategy

Each `SocialFormatTile` renders its `*RenderView` inline at reduced `.frame(...)`, constrained to ~167pt tall inside a 199pt tile (per Figma). Using the same SwiftUI view for thumbnail + final render eliminates drift: whatever the user previews is what saves to Photos. No asset catalog PNGs.

### Render + save path

`SocialView` owns `isSaving: SocialFormat?`. Tap handler:

```swift
@MainActor
private func save(_ format: SocialFormat) async {
    guard isSaving == nil else { return }
    isSaving = format
    defer { isSaving = nil }

    let start = Date()
    let renderer = ImageRenderer(content: renderView(for: format))
    renderer.scale = UIScreen.main.scale
    renderer.isOpaque = true
    guard let image = renderer.uiImage else { /* toast + analytics fail */ return }

    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    Analytics.track(.ticketExported(
        destination: format.analyticsDestination,
        resolution: nil, crop: nil, format: .png,
        includeBackground: nil, includeWatermark: nil,
        durationMs: Int(Date().timeIntervalSince(start) * 1000)
    ))
    toast = "Saved to Camera roll"
    try? await Task.sleep(nanoseconds: 1_200_000_000)
    onDismissSheet()
}
```

`isOpaque = true` — all five Figma compositions are fully opaque (white background for Square/Story, ticket-gradient background for FB/IG/X cards); skipping alpha halves memory + speeds the encode.

## Analytics

Reuse existing `ExportDestinationProp` enum but add 5 cases:

```swift
enum ExportDestinationProp: String, CaseIterable {
    case camera_roll, whatsapp, messenger, discord
    case instagram, twitter, threads, snapchat, facebook   // (existing, used by IM share)
    case social_square, social_story, social_facebook,     // NEW
         social_instagram, social_x                         // NEW
}
```

Rationale for new cases rather than reusing `.instagram` / `.facebook`: those were added for the (now-unused) future IM share branch to those platforms. Using them for "save-to-roll formatted for IG" would conflate flows and break downstream funnels. Keep them distinct.

Events fired:

- `exportDestinationSelected(destination: .social_<format>)` on tile tap.
- `ticketExported(destination: .social_<format>, resolution: nil, crop: nil, format: .png, includeBackground: nil, includeWatermark: nil, durationMs: …)` on successful save.
- `ticketExportFailed(destination: .social_<format>, errorType: "render_failed")` on renderer returning nil.
- `Analytics.updateUserProperties(["last_export_destination": ExportDestinationProp.social_<format>.rawValue])`.

Also: add a new event to distinguish "opened the Social phase" from "selected a format" — not needed in v1. `exportDestinationSelected` on the Social card (Phase A) already captures intent; tile tap inside Phase C fires the per-format `exportDestinationSelected` above.

## File layout

```
Lumoria App/views/tickets/new/
├── ExportSheet.swift                    (modify: add .social phase)
└── social/                              (NEW)
    ├── SocialFormat.swift               (enum + canvas specs + analytics map)
    ├── SocialView.swift                 (Phase C grid)
    ├── SocialFormatTile.swift           (card w/ thumbnail + label)
    └── renders/
        ├── SquareRenderView.swift
        ├── StoryRenderView.swift
        ├── FacebookRenderView.swift
        ├── InstagramRenderView.swift
        └── XRenderView.swift
```

Files modified:

- `Lumoria App/views/tickets/new/ExportSheet.swift` — enum `Phase` gains `.social`; wire Phase A's Social card tap handler to `phase = .social`; add `SocialView` case in the `switch` with the same asymmetric horizontal transition used between A and B.
- `Lumoria App/services/analytics/AnalyticsProperty.swift` — 5 new `ExportDestinationProp` cases.

No change needed in `AnalyticsEvent.swift` or `AnalyticsMappers.swift` — the new destination cases flow through existing event signatures.

## Error handling

- Render failure (ImageRenderer returns nil): toast + `ticketExportFailed` analytics, sheet stays open. Recoverable by tapping another tile or re-tapping the same one.
- Photos permission: `UIImageWriteToSavedPhotosAlbum` is the same API already used by `CameraRollView`, with the existing `NSPhotoLibraryAddUsageDescription` in `Info.plist`. No new permission plumbing.
- Rapid tapping: `isSaving` guard short-circuits second taps during an in-flight render.

## Testing

- Unit: extend `Lumoria AppTests/AnalyticsEventTests.swift` to cover the 5 new destination enum cases round-tripping through `Analytics.track(.ticketExported)` and `exportDestinationSelected`.
- Manual (can't be automated until UI test target exists):
  - Save each of the 5 formats for a horizontal ticket; verify camera roll image pixel dimensions match canvas × screen scale (e.g. Story = 1080×1920 × 3 on a @3x device = 3240×5760 on the final PNG).
  - Save each of the 5 formats for a vertical ticket; verify composition swaps (vertical tickets pick the `_verticalTicket/*` Figma variant).
  - Tap the Social card in Phase A, back-chevron out of Phase C, confirm you land back on Phase A (not Phase B).
  - Render failure path: hard to induce naturally; skip v1 beyond the toast code existing.

## Rollout

Single PR. No feature flag. Behind-the-scenes analytics changes are additive only — no consumer of `ExportDestinationProp` expects exhaustive switches on the enum (spot-check: all current call sites use `.rawValue` or wildcard mapping).

## Frame index

| Format | Vertical ticket | Horizontal ticket | Size |
|---|---|---|---|
| Square | [1107:25828](https://www.figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1107-25828) | [1774:85646](https://www.figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1774-85646) | 1080×1080 |
| Story | [1107:25832](https://www.figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1107-25832) | [1774:85649](https://www.figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1774-85649) | 1080×1920 |
| Facebook | [1107:25827](https://www.figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1107-25827) | [1774:85647](https://www.figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1774-85647) | 1080×1359 |
| Instagram | [1107:25830](https://www.figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1107-25830) | [1774:85648](https://www.figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1774-85648) | 1080×1350 |
| X | [1107:25829](https://www.figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1107-25829) | [1774:85645](https://www.figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1774-85645) | 720×1280 |

Sheet: [1109:31332](https://www.figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1109-31332)
