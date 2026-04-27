# Sharing DesignTokens between the app and widget targets

The colour palette and semantic tokens used to live in
`Lumoria App/Assets.xcassets/Colors/...` and `Lumoria App/DesignTokens.swift`,
both compiled only into the main app target. The widget target had to
mirror those tokens by hand in `Lumoria/WidgetTokens.swift`.

To keep one source of truth across both targets:

1. The colour-set folder has been moved to `Shared.xcassets/Colors/`
   at the project root.
2. `DesignTokens.swift` stays where it is but needs to be added to the
   widget target's Compile Sources.
3. `Shared.xcassets` needs to be added to **both** targets' Copy Bundle
   Resources so `Color("Colors/Gray/0")` lookups resolve in either
   bundle at runtime.

## One-time Xcode setup

Do this once in Xcode UI — pbxproj surgery from the CLI is too easy
to corrupt. Estimated time: ~5 minutes.

### 1. Add `Shared.xcassets` to the project

- In the Xcode project navigator (left pane), right-click the project
  root → **"Add Files to 'Lumoria App'..."**.
- Select `Shared.xcassets` from the project root folder.
- In the dialog: leave **"Copy items if needed"** unchecked (file is
  already in place); **check both** `Lumoria App` and `Lumoria`
  (widget extension) under "Add to targets".
- Click **Add**.

### 2. Add `DesignTokens.swift` to the widget target

- Click `Lumoria App/DesignTokens.swift` in the project navigator.
- In the File Inspector (right pane, ⌥⌘1), under **Target Membership**,
  tick `Lumoria` (the widget extension) in addition to `Lumoria App`.

### 3. Verify target memberships

- `Shared.xcassets` → both targets ticked.
- `DesignTokens.swift` → both targets ticked.
- `Lumoria App/Assets.xcassets` → `Lumoria App` only (widget extension
  unchecked).
- `Lumoria/Assets.xcassets` → `Lumoria` only (main app unchecked).

### 4. Clean build folder + rebuild

- **Product → Clean Build Folder** (⇧⌘K).
- **Product → Build** (⌘B).
- Run the app — verify text and surfaces still render.
- Run the widget — verify the same.

### 5. Delete `Lumoria/WidgetTokens.swift`

Once both targets build and render correctly using `DesignTokens.swift`,
remove the widget-side mirror. It was kept in place during the
transition so the widget never has a build break.

```bash
rm "Lumoria App/Lumoria/WidgetTokens.swift"
```

## How to verify the runtime swap worked

- Set the simulator to dark mode. The widget background should flip to
  the very-dark grays (#0A0A0A / #171717), driven by the asset
  catalog's appearance variants.
- Set the simulator to "Increased Contrast". The colours should jump
  to the High Contrast variants the asset catalog ships.

If colours fall back to clear or stay light in dark mode, target
membership for `Shared.xcassets` is incomplete — re-check step 1.

## Why this matters

- Single source of truth — palette and token changes in
  `DesignTokens.swift` flow through to both app and widget without
  manually editing two files.
- Asset-catalog appearance variants (Light / Dark / HC Light / HC Dark)
  are honoured in widgets too — previously the widget mirror had only
  Light / Dark hard-coded.
- Smaller widget binary (slightly): the widget no longer ships its own
  duplicate token implementation.
