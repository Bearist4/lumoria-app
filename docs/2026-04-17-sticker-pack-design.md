# iMessage Sticker Pack — Design

Date: 2026-04-17
Status: Approved, in implementation

## Goal
Let users send their own Lumoria tickets as stickers in Messages.

## Targets

| Target | Kind | Bundle id |
|--------|------|-----------|
| Lumoria App | iOS app (existing) | `bearista.Lumoria-App` |
| LumoriaStickers | iMessage app extension (new) | `bearista.Lumoria-App.LumoriaStickers` |

App Group shared between both: `group.bearista.Lumoria-App`.

## Architecture

- User's own tickets → stickers. No curated pack.
- Main app renders tickets to transparent PNGs on write; caches in App Group.
- Extension reads cache only. No network, no auth, no decryption in the extension.

### Data flow

```
Main app (TicketsStore mutation)
  └─> StickerRenderService
        ├─> writes <ticketId>.png into App Group /stickers/
        └─> updates App Group /stickers/manifest.json
              (entries sorted createdAt desc)

LumoriaStickers extension (MSStickerBrowserViewController)
  ├─> viewWillAppear: load manifest
  ├─> build [MSSticker] from files
  └─> reloadData
```

### Write triggers (main app)
- Ticket create → render + manifest append
- Ticket update (payload, style, orientation) → re-render, manifest update
- Ticket delete → unlink PNG, manifest remove
- `TicketsStore.load()` success → `reconcile(with:)` diffs manifest vs tickets; renders missing, prunes orphans

## Sticker PNG spec

- Renderer: SwiftUI `ImageRenderer` on new `StickerRenderView` — `TicketPreview` only, transparent background, no watermark, no shadow.
- Output: PNG, max 1200 px long edge, ≤400 KB target (Apple's hard limit is 500 KB).
- Retry ladder if oversized: 1200 → 900 → 700 px. Three tries then log + skip.
- Filename: `<ticketUUID>.png` inside App Group container `/stickers/`.

## Manifest format

```json
{
  "version": 1,
  "entries": [
    {
      "ticketId": "UUID",
      "filename": "UUID.png",
      "createdAt": "2026-04-17T…",
      "label": "Plane ticket · HKG to LHR"
    }
  ]
}
```

Accessibility label rule: `"<categoryLabel> · <origin> to <destination>"` for trips; `"<categoryLabel>"` when no destination.

Written atomically (temp file + rename).

## Components / files

### New (main app)
- `services/StickerRenderService.swift`
- `services/StickerManifest.swift` — shared with extension
- `views/tickets/StickerRenderView.swift`

### New (extension target)
- `LumoriaStickers/MessagesViewController.swift` — `MSStickerBrowserViewController` subclass
- `LumoriaStickers/Info.plist`
- `LumoriaStickers/LumoriaStickers.entitlements`

### Modified
- `SupabaseManager.swift` is unaffected.
- `views/tickets/TicketsStore.swift` — hooks on create/update/delete/load
- `Lumoria App.entitlements` — add App Group
- `Lumoria App.xcodeproj` — add extension target, embed it into app, wire App Group cap on both

## Extension UX
- Native `MSStickerBrowserViewController` grid.
- Newest first.
- Tap to send. Long-press peek + drag supported by the system.
- Empty state string (when no tickets): `Nothing here yet.` / `Craft a ticket in Lumoria.`

## Failure policy
- Render / manifest failures never block main-app ticket ops. Logged only.
- Extension tolerates missing files: any manifest entry whose PNG is missing is skipped on load.
