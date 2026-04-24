# Onboarding V2 — design

**Date:** 2026-04-24
**Status:** Draft, awaiting user approval
**Area:** New-user activation
**Supersedes:** `docs/superpowers/specs/2026-04-20-onboarding-tipkit-design.md`

## Summary

Rework the first-run tutorial. Replace the TipKit-based onboarding with a server-backed state machine that drives a 12-step guided tour across Memories, Memory Detail, the New Ticket funnel, Export, and Add-to-Memory. Each step (except `welcome`, `fillInfo`, `endCover`) presents a dimming overlay with a pass-through cutout around a target UI element and a blue tip card nearby. The tutorial flag and current step live on a new `public.profiles` row so the user can resume across app kills and devices.

## Goals

- Guide every fresh signup through creating their first memory, their first ticket, and either exporting or adding it to a memory.
- Persist progress server-side so users can resume after an interruption, across devices.
- Use a single reusable overlay primitive (`OnboardingOverlay`) that host views opt into per step.
- Remove TipKit entirely.

## Non-goals (v1)

- A/B variants of tutorial copy.
- Deep-linking into the tutorial from email or push.
- Animations between tips.
- Per-platform variants (iPad-specific layouts).
- Offline queuing of step writes beyond the built-in Supabase client retries.

## Decisions locked (from brainstorm)

| # | Decision |
|---|----------|
| 1 | Storage: new `public.profiles` table. |
| 2 | Resume after interruption: prompt user via re-skinned bottom sheet, never silently. |
| 3 | Overlay interaction: pass-through cutout (`.allowsHitTesting(false)` on cutout region). |
| 4 | `pickStyle` step is conditional — skipped if chosen template has no style variants. Runs between `fillInfo` and `allDone`. |
| 5 | X on a tip during tutorial → alert "Leave the tutorial?"; confirm → `show_onboarding = false`, `onboarding_step = done`. |
| 6 | `fillInfo` step: cutout on first required field (matches Figma); tap in cutout dismisses overlay so user can fill the whole form. |
| 7 | Full rewrite — delete TipKit, `OnboardingTips.swift`, all `.popoverTip` call sites, `Tips.configure`. |
| 8 | Keep "Replay onboarding" in Settings; wires to `coordinator.resetForReplay()` which writes `show_onboarding=true, onboarding_step=welcome` server-side. |
| 9 | Timing: 3s delay after landing on MemoriesView before welcome cover (or resume sheet). Subsequent tips fire immediately on host view appear. |
| 10 | X on Welcome cover = silent `show_onboarding = false`; no alert (differs from X during tutorial). |
| 11 | Resume sheet shows only on cold launch. Foreground-from-background silently continues the current step. |

## Flow

```
signup
  ↓  (profile row auto-created via trigger, show_onboarding=true, step=welcome)
ContentView lands on MemoriesView
  ↓  (3s delay)
  ├─ step == welcome          → WelcomeSheetView
  └─ step in (createMemory..addToMemory)
                               → ResumeSheetView
                                     ↓ Continue → step stays; overlays resume
                                     ↓ X       → show_onboarding=false, step=done
welcome "Start tutorial" → step=createMemory
welcome X                → show_onboarding=false, step=done
                          ↓
createMemory          → CollectionsView: cutout on + button
                          ↓ user taps +, sheet opens, creates memory
                          ↓ CollectionsStore.addMemory success
                          → step=memoryCreated
memoryCreated         → CollectionsView: cutout on new tile
                          ↓ user taps tile → MemoryDetailView pushes
                          ↓ MemoryDetailView.onAppear
                          → step=enterMemory
enterMemory           → MemoryDetailView: cutout on + button
                          ↓ user taps +, new ticket funnel presents
                          ↓ CategoryStep.onAppear
                          → step=pickCategory
pickCategory          → CategoryStep: cutout on categories grid
                          ↓ user taps a category, selection flows through
                          ↓ funnel advances to template grid
                          → step=pickTemplate
pickTemplate          → NewTicketFunnel template stage: cutout on first template card
                          ↓ user picks a template, tap Next
                          ↓ FormStep.onAppear
                          → step=fillInfo
fillInfo              → FormStep / UndergroundFormStep: cutout on first required field
                          ↓ user taps inside cutout → overlay dismisses, user fills form
                          ↓ user taps Next
                          ↓ if selected template.hasStyleVariants → step=pickStyle
                          ↓ else → step=allDone
pickStyle (conditional) → styling screen: cutout on style grid
                          ↓ user picks style, taps Next
                          → step=allDone
allDone               → SuccessStep: tip card anchored over the success card (no cutout on card itself; cutout on the two bottom CTAs as a pair? see §6)
                          ↓ user taps Export Ticket or Add to Memory
                          → step=exportOrAddMemory (variant stored on coordinator)
exportOrAddMemory     → Export screen: cutout on the 3 export group cards (Social / IM / Camera roll)
                        OR Add-to-memory sheet: cutout on the memory list
                          ↓ user picks one and action completes
                          → step=endCover
endCover              → back on MemoriesView: OnboardingEndSheetView
                          ↓ user taps "Start using Lumoria" or X
                          → show_onboarding=false, step=done
done                  → terminal, no further tutorial UI.
```

## Data model

### Migration `supabase/migrations/20260424000000_profiles.sql`

```sql
create table public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  show_onboarding boolean not null default true,
  onboarding_step text not null default 'welcome'
    check (onboarding_step in (
      'welcome','createMemory','memoryCreated','enterMemory',
      'pickCategory','pickTemplate','fillInfo','pickStyle',
      'allDone','exportOrAddMemory','endCover','done'
    )),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "profiles_self_read"
  on public.profiles for select
  using (auth.uid() = user_id);

create policy "profiles_self_update"
  on public.profiles for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- no insert/delete policies for clients — insert via trigger, delete via cascade
create trigger profiles_updated_at
  before update on public.profiles
  for each row execute function moddatetime(updated_at);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (user_id) values (new.id);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
```

No backfill needed — existing test users have completed onboarding in v1; they'll be inserted at `show_onboarding=false, onboarding_step=done` via a one-shot `insert ... on conflict do nothing` migration targeting existing `auth.users` rows (see migration bottom):

```sql
insert into public.profiles (user_id, show_onboarding, onboarding_step)
  select id, false, 'done' from auth.users
  on conflict (user_id) do nothing;
```

## Swift architecture

### New files

```
Lumoria App/
├── services/onboarding/
│   └── ProfileService.swift              # Supabase CRUD for profiles
└── views/onboarding/
    ├── OnboardingCoordinator.swift        # rewrite of existing file
    ├── OnboardingStep.swift               # enum with all 12 cases
    ├── OnboardingOverlay.swift            # reusable overlay modifier
    ├── OnboardingOverlayAnchor.swift      # PreferenceKey for target frames
    ├── OnboardingTipCard.swift            # the blue card with title/body/X
    ├── WelcomeSheetView.swift             # rewrite to match new Figma
    ├── ResumeSheetView.swift              # new — re-skinned welcome shell
    └── OnboardingEndSheetView.swift       # new — end cover
```

`OnboardingCoordinator.swift`:

```swift
@Observable @MainActor
final class OnboardingCoordinator {
    // Persisted (server-backed)
    private(set) var showOnboarding = false
    private(set) var currentStep: OnboardingStep = .welcome

    // Transient UI state
    var showWelcome = false
    var showResume  = false
    var showEndCover = false
    var showLeaveAlert = false        // driven by tip-card X
    var exportOrAddChoice: ExportVariant? = nil   // set in allDone
    var pendingStyleStep: Bool = false            // set at pickTemplate advance

    private let service: ProfileService
    private var startedAt: Date?

    func loadOnAuth() async        // fetch row, hydrate
    func maybePresentEntry()       // called by ContentView after 3s delay
    func startTutorial() async     // welcome "Start" → createMemory
    func dismissWelcomeSilently() async  // welcome X → show_onboarding=false
    func confirmLeaveTutorial() async    // tip X confirm → flag false, step=done
    func advance(from expected: OnboardingStep) async
    func chose(_ variant: ExportVariant) async // at allDone
    func resume() async            // resume sheet Continue
    func declineResume() async     // resume sheet X
    func finishAtEndCover() async  // end sheet "Start using Lumoria" or X
    func resetForReplay() async    // Settings → replay
}

enum ExportVariant { case export, addToMemory }
```

`OnboardingStep.swift`:

```swift
enum OnboardingStep: String, Codable, CaseIterable {
    case welcome
    case createMemory
    case memoryCreated
    case enterMemory
    case pickCategory
    case pickTemplate
    case fillInfo
    case pickStyle
    case allDone
    case exportOrAddMemory
    case endCover
    case done
}
```

`ProfileService.swift` (stub):

```swift
struct Profile: Codable { let userId: UUID; var showOnboarding: Bool; var onboardingStep: OnboardingStep }

final class ProfileService {
    func fetch() async throws -> Profile
    func setStep(_ step: OnboardingStep) async throws
    func setShowOnboarding(_ value: Bool) async throws
    func replay() async throws  // sets show=true, step=welcome
}
```

### Overlay primitive

`OnboardingOverlay` is applied via modifier at the host view root:

```swift
someView
  .onboardingOverlay(
      step: .createMemory,         // only renders when coordinator.currentStep matches
      coordinator: coordinator,
      tip: TipCopy(
          title: "Create a memory",
          body: "Memories gather tickets into one place. Create one by tapping the + button."
      ),
      anchorID: "memories.plus"
  )
```

The target element declares its anchor with:

```swift
PlusButton()
  .onboardingAnchor("memories.plus")   // records bounds in PreferenceKey
```

`onboardingAnchor(_:)` writes a `[String: Anchor<CGRect>]` preference up the view tree. The overlay modifier, placed higher in the hierarchy, reads the preference, resolves the `CGRect` via `GeometryReader`, and renders:

- Dim layer (black @ 40% opacity) across the full screen.
- `Rectangle()` cutout at the anchor rect (expanded by 8pt padding, corner radius matching the element) combined with `.blendMode(.destinationOut)` inside a `ZStack { ... }.compositingGroup()`.
- `OnboardingTipCard` positioned below the anchor (or above if there's no room below).
- `.allowsHitTesting(false)` applied to everything **except** the tip card and its X button. Effect: taps inside the cutout pass through to the underlying control; taps on the dimmed area do nothing; taps on the tip card X trigger the leave-alert.

The overlay auto-dismisses when `coordinator.currentStep` changes.

### Modified files

| File | Change |
|------|--------|
| `Lumoria_AppApp.swift` | Remove `Tips.configure(...)`. Add `@State private var onboardingCoordinator = OnboardingCoordinator(...)`. Inject as `.environment(onboardingCoordinator)` under the authed tab UI. Call `await onboardingCoordinator.loadOnAuth()` when auth flips to authenticated. |
| `ContentView.swift` | Watch Memories-tab active + first-appear; after 3s, call `onboardingCoordinator.maybePresentEntry()`. Present `WelcomeSheetView`, `ResumeSheetView`, `OnboardingEndSheetView` via `.sheet(isPresented:)`. Present the leave-alert via `.alert(isPresented: $showLeaveAlert)`. |
| `views/collections/CollectionsView.swift` | Attach `.onboardingOverlay(step: .createMemory, ...)` and `.onboardingOverlay(step: .memoryCreated, ...)` at the root. Tag `PlusButton` with `.onboardingAnchor("memories.plus")` and the newest memory tile with `.onboardingAnchor("memories.newTile")`. |
| `views/collections/CollectionsStore.swift` | On `addMemory` success during tutorial, call `coordinator.advance(from: .createMemory)`. |
| `views/collections/CollectionDetailView.swift` | `.onboardingOverlay(step: .enterMemory, ...)`. Tag `+` button with `.onboardingAnchor("memoryDetail.plus")`. On `.onAppear`: if `currentStep == .memoryCreated`, call `advance(from: .memoryCreated)` — coordinator moves step to `.enterMemory`, and the enter-memory overlay renders on the + button. |
| `views/tickets/new/CategoryStep.swift` | `.onboardingOverlay(step: .pickCategory, ...)`. Tag categories grid with `.onboardingAnchor("funnel.categories")`. On selection callback, `advance(from: .pickCategory)`. |
| `views/tickets/new/NewTicketFunnel.swift` | `.onboardingOverlay(step: .pickTemplate, ...)` on template stage. Tag first template card with `.onboardingAnchor("funnel.firstTemplate")`. On template selection, record `coordinator.pendingStyleStep = template.hasStyleVariants` then `advance(from: .pickTemplate)`. |
| `views/tickets/new/FormStep.swift` + `UndergroundFormStep.swift` | `.onboardingOverlay(step: .fillInfo, ...)`. Tag the first required field with `.onboardingAnchor("funnel.firstField")`. On first-field focus, `advance(from: .fillInfo)` — coordinator consults the `pendingStyleStep` flag recorded at `pickTemplate` advance and sets `currentStep = pendingStyleStep ? .pickStyle : .allDone`. Overlay vanishes immediately. User fills the form freely and taps Next; the next funnel screen (styling or success) is already wired to render its own overlay. |
| `views/tickets/new/TemplateDetailsSheet.swift` (or styling screen) | `.onboardingOverlay(step: .pickStyle, ...)`. Tag styles grid with `.onboardingAnchor("funnel.styles")`. On style pick or Next, `advance(from: .pickStyle)`. |
| `views/tickets/new/SuccessStep.swift` | `.onboardingOverlay(step: .allDone, ...)`. Anchor on the two-CTA stack (`Export Ticket` + `Add to Memory`). On Export tile tap → `coordinator.chose(.export)`; on Add-to-memory tap → `coordinator.chose(.addToMemory)`. Each transitions the coordinator to `.exportOrAddMemory` with the variant recorded. |
| Export screen (wherever the 3 export group cards live) | `.onboardingOverlay(step: .exportOrAddMemory, coordinator: ..., variant: .export, ...)`. Tag the 3 group cards as the anchor. On any export-group card tap, `advance(from: .exportOrAddMemory)`. |
| Add-to-memory sheet | `.onboardingOverlay(step: .exportOrAddMemory, ..., variant: .addToMemory, ...)`. Tag the memory list with `.onboardingAnchor("addToMemory.list")`. On memory pick, `advance(from: .exportOrAddMemory)`. |
| `views/settings/SettingsView.swift` | "Replay onboarding" row → `Task { await coordinator.resetForReplay() }`. Dismiss Settings, then welcome sheet appears on MemoriesView re-entry. |
| `services/analytics/AnalyticsEvent.swift` | Extend with new events (see Analytics). |
| `services/analytics/AnalyticsProperty.swift` | Extend `OnboardingStepProp` with the 12 new step cases. |
| `Localizable.xcstrings` | Add all new copy keys. |

### Deleted files & code

- `views/onboarding/OnboardingTips.swift` — TipKit `Tip` structs and `Tips.Event` constants.
- `Tips.configure([...])` call in `Lumoria_AppApp.swift`.
- All `.popoverTip(MemoryTip())`, `.popoverTip(TicketTip())`, `.popoverTip(ExportTip())` modifiers across CollectionsView / CollectionDetailView / SuccessStep.
- `TipKit` import where no longer used.
- UserDefaults keys `onboarding.welcomeSeen`, `onboarding.skipped`, `onboarding.completed` — no longer read.

## Assets

New imagesets in `Lumoria App/Assets.xcassets/onboarding/`:
- `cover.imageset/` — hero art for welcome sheet (purple/off-white as in Figma). Placeholder asset committed; user replaces with final art.
- `end_cover.imageset/` — hero art for end sheet. Same treatment.

## Copy (from Figma, locked)

### Welcome sheet
- Title: **Welcome to Lumoria!**
- Body: Memories gather tickets into one place — a trip, a season, a night out. Whatever you want to hold onto.
- CTA: **Start tutorial**
- X: silent dismissal, `show_onboarding=false`.

### Tip cards (blue card, white title/body, X)
| Step | Title | Body |
|------|-------|------|
| createMemory | Create a memory | Memories gather tickets into one place. Create one by tapping the + button. |
| memoryCreated | Your memory has been created | Once you will have tickets added to this memory, they will appear on this tile. Tap this memory to open it. |
| enterMemory | Create your first ticket | Let's fill this memory with your first ticket. Tap the + button to start. |
| pickCategory | Pick a category | Tickets are separated into categories. Pick a category to continue. |
| pickTemplate | Pick a template | Each category has different templates that match it. You can also check the content of each template by tapping the information button. |
| fillInfo | Fill the required information | Every template have specific information attached to it. Fill all the required information to edit your ticket. |
| pickStyle | Select a style | Some templates have alternative styles. Scroll through the options and tap the one you like to change how your ticket looks. |
| allDone | Ticket created! | Your ticket has been created. You can find it in All Tickets. You can now add it to a Memory or Export your ticket to use it in another app. |
| export | Export your ticket | Choose the export option that matches what you want to achieve. |
| addToMemory | Add to a memory | Tap the memory you would like to add your ticket to. This can be changed later. |

### End sheet
- Title: **All done!**
- Body: You can now enjoy Lumoria and create beautiful tickets for every moments you'd like to remember. We just covered the basics of Lumoria. There's so many more features waiting to be discovered.
- CTA: **Start using Lumoria**

### Resume sheet
- Title: **Welcome back**
- Body: Want to continue where you left off in the tutorial?
- CTA: **Continue tutorial**
- X: `show_onboarding=false`, `onboarding_step=done`.

### Leave alert (tip X)
- Title: Leave the tutorial?
- Message: You can replay it anytime from Settings.
- Buttons: **Leave** (destructive) / **Stay**.

## Analytics

Extend `AnalyticsEvent`:
- `onboardingShown` (welcome sheet appears)
- `onboardingStarted` (welcome Start tap)
- `onboardingResumed` (resume sheet Continue)
- `onboardingDeclinedResume` (resume sheet X)
- `onboardingStepCompleted(step: OnboardingStepProp)`
- `onboardingLeft(atStep: OnboardingStepProp)` (tip X confirmed, OR welcome X, OR resume X)
- `onboardingCompleted(durationSeconds: Int)` (end sheet CTA/X)
- `onboardingReplayed` (Settings replay)

Extend `OnboardingStepProp`: cases for all 12 steps.

## Edge cases

- **Profile row missing (race with trigger)**: `ProfileService.fetch()` retries with exponential backoff once; if still missing, defaults to `show_onboarding=true, step=welcome` in memory only. Next successful write upserts the row.
- **Offline writes**: coordinator optimistically updates local state immediately, queues write. Failures logged; next launch hydrates from server truth.
- **User creates memory outside tutorial path** (step is still `createMemory`, user taps + via an unrelated surface): advance still happens on `addMemory` success. Acceptable — the overlay dismisses naturally because `currentStep` moves past `createMemory`.
- **User navigates back in funnel mid-tutorial** (e.g. tap Back from templates to category after `pickTemplate` already advanced): the overlay is gone because step advanced; user can still interact normally. Step does NOT roll back. Acceptable — Figma does not show re-entry overlays.
- **Template with no styles**: on `FormStep` Next, check `Template.hasStyleVariants`. If 0, skip `pickStyle`, go direct to `allDone`.
- **Signed-out user with show_onboarding=true**: profile fetch is gated on auth. Coordinator stays idle until `loadOnAuth()` runs.
- **Multi-device**: step is server-side. User who starts on iPhone and opens iPad mid-tour sees the resume sheet on iPad. Accepted.
- **Delete account**: `on delete cascade` removes profile.
- **Returning v1 user who previously completed**: backfill migration inserts `show_onboarding=false, onboarding_step=done`. No tutorial shows.
- **fillInfo cutout — user taps outside the cutout** (e.g. taps Next immediately, or scrolls): tap is blocked by `.allowsHitTesting(true)` on the dim layer. Only the cutout + tip card + X are hittable. User MUST tap inside the cutout to dismiss, which also focuses the first required field.
- **User abandons at exportOrAddMemory**: next cold launch shows resume sheet. Step persists.
- **User swipes down the new-ticket funnel mid-tour** (e.g. during pickCategory): funnel dismisses. Step stays at `pickCategory`. Next time user opens the + button in memory detail, category step overlay reappears. Self-healing.

## Testing

### Unit (OnboardingCoordinator)
- Fresh state + `loadOnAuth()` with `show_onboarding=true, step=welcome` → `showWelcome == true` after `maybePresentEntry()`.
- `show_onboarding=true, step=createMemory` → `showResume == true` after `maybePresentEntry()`.
- `show_onboarding=false` → no sheet ever.
- `advance(from: expected)` ignores mismatched expected-steps (stale call from earlier advance).
- `resetForReplay()` writes `show=true, step=welcome`, clears local state.
- `confirmLeaveTutorial()` writes `show=false, step=done`, fires `onboardingLeft`.
- `chose(.export)` / `chose(.addToMemory)` stores variant, advances to `exportOrAddMemory`.

### Integration (ProfileService mock)
- Trigger fires on signup → row exists with defaults.
- RLS: one user cannot read another's profile.

### Snapshot
- `WelcomeSheetView`, `ResumeSheetView`, `OnboardingEndSheetView` in Light/Dark.
- `OnboardingTipCard` at each of: below anchor, above anchor, edge-clipped (safe-area).

### UI
- Full happy path: signup → welcome → 11 tips → end cover → profile row == `show=false, step=done`.
- Skip path: welcome X → no tips fire.
- Resume path: kill app at `pickCategory` → relaunch → resume sheet → Continue → overlay on categories grid.
- Replay path: Settings → Replay → welcome sheet re-presents.
- Leave path at tip: step 5 → X on tip → Alert Leave → no more tips.

## Open decisions — none

All resolved in brainstorm. Ready for implementation plan.
