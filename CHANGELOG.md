# Changelog

All notable changes to Lumoria App are logged here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions use
the Xcode `MARKETING_VERSION` and are grouped under Added / Changed /
Fixed / Removed.

Going forward, every change merged into the app must land with an
entry in the `[Unreleased]` section. Promote the section to a dated
version on release.

## [Unreleased]

### Added
- **Concert venue search field.** Replaced the plain-text venue input
  on the concert form with a new `LumoriaVenueField` — a MapKit POI
  search mirroring `LumoriaStationField` / `LumoriaAirportField`.
  Suggestions span stadiums, arenas, theatres, clubs, parks; picking
  one auto-fills the venue name and persists a `TicketLocation`
  (`kind == .venue`) so concerts now appear as pins on the memory
  map alongside flights and train trips.
- **Aesthetic auto-fill on advance.** When the user advances past the
  new-ticket form step with optional fields blank, the funnel now
  fills them with template-appropriate placeholder copy (e.g.
  "World Tour 2026", a pseudo-random ticket reference like
  `CON-2026-081742`) so the rendered ticket always looks finished.
  The success step surfaces an inline notice listing the fields we
  touched so the user can edit the ticket later if they want to
  swap the copy. Required fields still gate Next; edit flow is
  excluded from the auto-fill so intentional blanks aren't
  overwritten. Currently wired for the Concert template; extendable
  per template via `applyAestheticDefaults()`.
- **New ticket categories.** Expanded `TicketCategory` to the ten
  planned buckets: Plane, Train, Concert, Event, Food, Movie, Museum,
  Sport, Garden, Public Transit. Plane / Train / Concert are the
  currently available ones; the rest are placeholders awaiting
  templates. `TicketCategoryStyle` grew to match, with colour families
  and SF Symbols per category.
- **Three new templates.**
  - `post` (Train) — cream-paper, serif-type TGV / Shinkansen stub.
  - `glow` (Train) — pitch-black code-drawn stub with a warm magenta bloom.
  - `concert` (Concert) — dreamy pop-concert stub with a curved
    artist-name arc, matching curved tour subtitle, scattered heart /
    star decorations baked into the background art, Date / Doors /
    Show / Venue grid and an ADMIT ONE footer pill. Long artist names
    automatically break at the best-balanced word boundary onto two
    stacked arcs, and the subtitle follows the arc line count.
- **Concert template font.** Bundled Momo Trust Display (Google Font)
  for the artist arc. `ConcertFont.momoTrustDisplay(size:)` resolves
  via PostScript-name candidates and fuzzy family matching so the
  view survives name variations; falls back to system italic while
  the font is being wired up.
- **Memory "+" button.** Added a dedicated plus icon between the map
  and ellipsis icons on `MemoryDetailView` that opens the new-ticket
  funnel directly, trimming one tap from the existing menu flow.
- **Underground / public-transport ticket template.** New dark-card
  subway/metro/tram/bus template (`templates/publicTransit/
  underground/`). The line's SF-Symbol mode (subway tunnel, tram,
  bus, cable-car, ferry) is drawn as a pip at the bottom-right of
  the line badge; line brand colour is stored per-ticket in the
  payload (`UndergroundTicket.lineColor`) so every line keeps its
  official hue even when the same template renders many tickets on
  the same memory map. Migration
  `20260504000000_underground_template_kind.sql` whitelists
  `template_kind = 'underground'` in the DB constraint.
- **Transit catalog system + GTFS importer.** Build-time Python
  pipeline (`scripts/gtfs-import/import.py`) consumes any
  GTFS-compliant zip and emits a compact JSON catalog bundled with
  the app. Runtime layer:
  - `TransitCatalog` / `TransitLine` / `TransitStation` DTOs,
    mode-aware via `TransitMode` (`0` tram → `12` monorail)
  - `TransitCatalogLoader` with city aliases ("Wien" → Vienna,
    "NYC" → New York, "Île-de-France" → Paris) so MapKit-picked
    locality strings resolve regardless of language
  - `TransitRouter.routes(from:to:in:max:)` — BFS over a
    name-based transfer graph (collapses Wiener Linien's per-
    platform stop_ids back into one interchange node); returns up
    to 4 diverse routes via line-exclusion passes, so a single-line
    origin like Oberlaa still surfaces alternatives through
    different transfers or modes
  - `LumoriaSubwayStationField` — catalog-backed station picker
    with mode icons per line, locale-aware alphabetical sort,
    interchange line-list in the suggestion row
- **Three bundled transit cities at ship.**
  - **Vienna** (Wiener Linien) — 189 lines: 5 subway (U1–U6), 30
    tram, 154 bus with authentic brand colours (U1 red, U2 purple
    …)
  - **New York** (MTA) — 26 subway lines with official MTA
    colours (1/2/3 red, 4/5/6 green, 7 purple, A/C/E blue, B/D/F/M
    orange, G, J/Z, L, N/Q/R/W yellow, S)
  - **Paris** (Île-de-France Mobilités) — 48 lines: 16 metro, 15
    RER/rail, 17 tram
- **Public-transport funnel flow.** New `UndergroundFormStep` with
  a city dropdown at the top (🇦🇹 Vienna, 🇺🇸 New York, 🇫🇷 Paris)
  that scopes both station pickers to one operator. Changing the
  city invalidates the picked stations. Once both stations are
  picked, `TransitRouter` runs, and:
  - A route-picker grid of `RouteTile`s appears when 2+
    alternatives exist — each tile shows the line chain
    (mode-icon chips with brand colours + → arrows), transfer
    count, and total stops
  - The selected route drives a preview stack of one
    `UndergroundTicketView` per leg
  - On submit, `createUndergroundTickets(using:)` persists each
    leg as its own `UndergroundTicket` with the correct per-line
    colour, mode, stations, and stop count
- **Group add-to-memory.** `AddToMemorySheet` now takes
  `tickets: [Ticket]` and treats multi-leg underground journeys as a
  unit — a memory is marked "added" only when every leg is in it;
  one tap adds/removes all legs at once; toast reports
  "3 tickets added to Tokyo 2026" for the batch. Single-ticket
  templates keep their existing UX via an `init(ticket:)`
  convenience.
- **Memory map story mode — V1.** Substantial overhaul of
  `MemoryMapView`:
  - `Memory` gains optional `startDate` / `endDate` (encrypted like
    name/emoji via the new `MemoryDateCodec`). Migration
    `20260502000000_memory_dates_and_journey_anchors.sql` adds
    `start_date_enc` / `end_date_enc` columns and a new
    `journey_anchors` table for user-defined stops (start / end /
    waypoint) with RLS policies matching `memories`.
  - `NewMemoryView` + `EditMemoryView` now include a Start / End
    date row backed by the new `LumoriaDateField` component
    (nullable date picker with warning state + dirty assistive
    text).
  - `JourneyAnchor` model + `MapDate` helpers wired through
    `MemoriesStore.create` / `.update`; anchor CRUD UI deferred to
    a later spec.
  - New `LumoriaNumberedData` + `MemoryDataArea` components
    render a 2×2 stats card (Tickets / Days / Categories /
    Kilometers) pinned flush to the bottom of the map. Distance
    uses Haversine across the full chronological sequence (ticket
    origin→destination legs plus anchors) and honours the new
    km↔mi preference.
  - `MemoryMapView` swaps the ellipsis menu for a two-entry list
    (View timeline / Hide timeline, Export map…). The timeline is
    an in-place mode swap now — no new fullscreen cover — with
    an animated card transition. A dotted, curved `MapPolyline`
    (quadratic Bezier per leg via `MemoryJourneyPath.curved`)
    connects every stop in chronological order both on-screen and
    in the exported snapshot.
  - `MemoryTimeline` film strip: date-axis ScrollView, chronological
    ticket tiles with 16pt intra-day spacing, fading white connector
    segments linking same-day tiles, `moon.zzz.fill` separators
    between days, `arrow.right.to.line` start anchor and
    `flag.pattern.checkered` end anchor bookending the axis,
    continuous tick rail behind the sticky top-left date label,
    24pt card padding, overflow clipped to the card's rounded
    rectangle. The red playhead stays pinned to the card centre;
    selection comes from whichever tile (or anchor) is nearest the
    playhead via `onScrollGeometryChange`. The top-left date label
    slides in from right on forward scroll / left on backward
    scroll. Selecting the start or end anchor resets the camera to
    the fit-all overview and lights up the icon in full white.
  - Map pins in timeline mode are per-stop; the selected pin scales
    to 1.18× with a spring (or a quick ease under reduce motion).
    Transitions between stops use a two-phase dezoom-through-leg-
    midpoint → settle-on-new-stop animation.
  - `MemoryMapExporter`: `MKMapSnapshotter` + Core Graphics
    composition renders curved polyline and flat category-tinted
    pins into a shareable `UIImage`; hands off to the system share
    sheet.
- **Map preferences settings page.** New `MapPreferencesView` under
  `Settings → Map` with four controls, all `@AppStorage` backed and
  read via the new `MapPreferences` helper:
  - Distance units (km ↔ miles) — rewrites the `MemoryDataArea`
    Kilometers pill and converts the stored km total.
  - Map style (Standard / Satellite) — composes the right
    `MapStyle` for `MemoryMapView`.
  - Points of interest — swaps `.all` ↔ `.excludingAll` on the POI
    filter.
  - Reduce motion — shortens camera transitions (single 0.25 s ease
    instead of dezoom-through-midpoint) and swaps the pin-scale
    spring for an ease-in-out.
- **Map export backgrounds.** The Camera Roll export now ships
  three selectable backgrounds (Grid / Gradient / White) wired to
  both the live preview and the rendered image. When the Background
  toggle is off, the preview renders a `CheckeredBackgroundView`
  so the transparent export is readable; `ImageRenderer.isOpaque`
  is driven by the same toggle so PNG exports keep their alpha
  channel.
- **Onboarding resume routing.** The "Continue tutorial" button on
  `ResumeSheetView` now drops the user back at the screen they left
  off on instead of just closing the sheet. `OnboardingCoordinator`
  emits a one-shot `OnboardingResumeRoute` (`openFirstMemory` /
  `openNewTicketFunnel`); `MemoriesView` consumes it and either
  pushes the first memory's detail view or presents the
  `NewTicketFunnelView` full-screen. Memory steps stay on the
  Memories root (already correct via `selectedTab = 0`); the
  end-cover sheet still auto-presents via `coordinator.showEndCover`.
  A 0.3s delay between resume-sheet dismiss and the next presentation
  avoids the SwiftUI sheet/cover stack-drop race.
- **Onboarding funnel state persistence.** Cold-launching mid-tutorial
  no longer wipes the in-progress new-ticket funnel. `NewTicketFunnel`
  exposes `snapshot(createdTicketId:)` / `hydrate(from:)`, and the
  view installs a debounced (`400ms`) Combine bridge on
  `objectWillChange` that mirrors every change to a single
  `OnboardingFunnelDraft` JSON blob in `UserDefaults` (key
  `onboarding.funnelDraft`). On resume the funnel hydrates from disk,
  re-fetches the saved ticket via `TicketsStore` when `createdTicketId`
  is present, and jumps `funnel.step` straight to where the user
  left off. The draft is cleared at every onboarding terminal point
  (leave / decline-resume / dismiss-welcome / finish-end-cover /
  replay). Required Codable conformances added to `Airline`,
  `TicketCategory`, `TransitCatalogLoader.City`, `NewTicketStep`,
  and the four form structs (`FlightFormInput`, `TrainFormInput`,
  `EventFormInput`, `UndergroundFormInput`); underground routes
  recompute via `replan()` on hydrate since `TransitLeg` lives in a
  non-Codable graph.

### Changed
- **Category palette matches Figma.** Aligned `TicketCategoryStyle`
  colour families and display labels with the
  `_TicketDetails Category` component in Figma (node 1652:57952):
  food → Pink, concert → Purple, movie → Indigo, museum → Red,
  garden → Lime, publicTransit → Cyan. Labels now read "Movies",
  "Parks & Gardens" and "Public Transport" end-to-end (both the
  funnel's `TicketCategory.title` and the pill `displayName`).
- **Concert template uses native font sizing.** Swapped custom Barlow
  sizes for `.system(size: X * s, weight: …)` across details, footer
  strip, and ADMIT ONE badge in both horizontal and vertical
  variants. Keeps the SF Pro look, scales correctly in template /
  orientation tiles, and respects the ticket's proportional `s`
  factor.
- **Memory empty-state layout.** Message is now top-aligned inside
  the content card with 48 pt top padding and centre-aligned
  multi-line text (title previously defaulted to leading).
- **Memory top-bar menu.** Removed the "New ticket…" menu item from
  the ellipsis menu; creation now lives on the dedicated + button.
- **Settings subviews scroll the header.** `SettingsView`,
  `ProfileView`, `AppearanceView`, `NotificationsView`,
  `MapPreferencesView`, and `HelpCenterView` now scroll their
  whole contents — including the back button + title — instead of
  pinning a sticky blur header. `HelpArticleView` already followed
  this pattern.
- **Fit-all map camera for multi-continent trips.** `MemoryMapView`
  switches to a min-zoom camera (`MapCamera` with a very large
  `distance`) centred on the pins' centroid whenever the
  longitude span exceeds ~80° (or latitude ~70°), since portrait
  phones physically can't frame a wider-than-~80° span at a
  useful Mercator zoom. Smaller memories still use a computed
  region with tiered padding. Curved dotted polyline stays in
  sync in both modes.
- **Onboarding `fillInfo` overlay → cutout.** Replaced the bottom
  banner with a cutout anchored to the first form field
  (`funnel.firstFormField`, currently the departure airport on the
  Afterglow plane template). A new `gatedBy:` parameter on
  `onboardingOverlay` / `onboardingBannerOverlay` auto-dismisses
  the cutout once the user has picked an airport
  (`funnel.form.originAirport != nil`), so the rest of the form
  remains scrollable / tappable without forcing the onboarding
  step to advance early.
- **Onboarding `allDone` overlay waits for the print-reveal.** The
  cutout over the success-screen action buttons no longer flashes
  up the moment the success step appears. A new
  `allDoneOverlayReady` flag in `NewTicketFunnelView` flips true
  3.5s after the funnel lands on `.success` (matches
  `TicketSaveRevealView`'s end-to-end print animation), and is
  passed to the overlay via `gatedBy:`. Cold-resume into success
  starts the same gate from `onAppear`.
- **Tip card stagger + overlay fade.** Every onboarding overlay
  now fades in/out via an explicit
  `.animation(.easeInOut(0.25), value:)` on its container, and the
  tip card itself dissolves in 0.25s after the dim layer via a new
  `DelayedFadeIn` modifier so it reads as a two-beat reveal
  instead of one slab.
- **Tip placement only flips above when there's no room.** Replaced
  the "lower half → above" rule with a fit check that reserves 60pt
  for the home indicator. Camera-roll-style cutouts in the middle
  of the sheet keep their tip below; success-step cutouts near the
  bottom flip above as before.
- **Onboarding tab bar hides during overlay steps.** `OnboardingCoordinator`
  exposes `shouldHideTabBar` (true on `createMemory`,
  `memoryCreated`, `enterMemory`); `MemoriesView` and
  `MemoryDetailView` apply `.toolbar(.hidden, for: .tabBar)` so
  the SwiftUI floating tab bar can't render above the dim layer
  (it's a sibling of the tab content, not a child, so per-screen
  overlays can't cover it).
- **Onboarding `exportOrAddMemory` cutout points at Camera roll.**
  Moved the anchor from the whole destinations group
  (`export.groups`) to the camera-roll card (`export.cameraRoll`)
  and updated the tip copy to "Save to camera roll".
- **Success-step actions return to Memories on completion.** Both
  Export (Camera roll / Social) and Add to Memory now dismiss the
  whole funnel back to the Memories tab once the action lands —
  Export via the new `onCompleted` closure on `ExportSheet`,
  Add-to-Memory via the new `onCompleted` closure on
  `AddToMemorySheet` (fires after the toast settles). When the
  onboarding tutorial is active, the same closure advances
  `.exportOrAddMemory → .endCover` so the end-cover sheet pops over
  Memories instead of stacking under the success screen. Removed
  the old eager destination-tap and inline `toggle()` advances that
  used to fire the end-cover before the user had actually
  exported / added.
- **Floating bottom sheet animates on appear.** Moved
  `.animation(.spring(0.35), value: isPresented)` outside the
  `if isPresented` branch in `FloatingBottomSheet` so SwiftUI
  reliably animates the move-from-bottom + opacity transition on
  appear, not just on dismiss.

### Fixed
- **`device_tokens` RLS 42501 on sign-in with a re-owned device.**
  Token registration used `upsert(onConflict: "token")` which
  triggers the UPDATE policy's `USING` clause against the existing
  row; if another user owned it (sim sign-out + sign-in, shared
  dev device), the insert failed. Added migration
  `20260503000000_register_device_token_rpc.sql` — a
  `SECURITY DEFINER` RPC `public.register_device_token(token,
  environment, platform)` that stamps `user_id = auth.uid()` on
  conflict and is `execute`-granted only to authenticated callers.
  `PushNotificationService.uploadTokenIfPossible` now calls the
  RPC instead of upserting directly.
- **Memory view scroll-bleed.** Tint background no longer shows
  through when the user bounces a short ticket list (e.g. a single
  ticket). The tint is now a top-pinned layer above a white base in
  the `MemoryDetailView` ZStack; overscroll reveals the white base
  instead of the colour.
- **New-memory keyboard dismiss.** Tapping the Emoji field or the
  Color dropdown after typing a title now dismisses the keyboard
  via a `simultaneousGesture` that sends `resignFirstResponder`,
  so the presented picker / sheet isn't hidden behind the keyboard.
- **Dropdown pushes siblings.** `LumoriaDropdown`'s option list now
  renders as an overlay anchored to the field instead of inline in
  the column, so opening a dropdown no longer shifts captions or
  assistive text below it (visible in the new-memory view where the
  Color dropdown was pushing the helper caption down).
- **Dropdown draws behind caption.** Raised the emoji + color row's
  `zIndex` in both the new-memory and edit-memory views so the
  overlaid color-picker list visibly covers the helper caption below
  it instead of rendering behind it (SwiftUI draws later VStack
  siblings on top of earlier ones' out-of-bounds overlays by default).
