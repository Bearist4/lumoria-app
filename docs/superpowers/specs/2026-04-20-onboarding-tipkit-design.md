# Onboarding with TipKit — design

**Date:** 2026-04-20
**Status:** Draft, awaiting user approval
**Area:** New-user activation

## Summary

Guide brand-new signed-up users through a three-step activation path — create a memory, add a ticket, share it — using a one-time welcome sheet followed by a chain of TipKit popover tips. Users can skip the entire tour from the welcome sheet, and replay it later from Settings.

## Goals

- Convert a fresh signup into a user who has created a memory, created a ticket, and shared it, in one session.
- Use native iOS patterns (TipKit) so the experience matches platform conventions and persists state across launches without custom plumbing.
- Remain completely invisible to returning users and to anyone who skipped.

## Non-goals (v1)

- Mid-tour skip button on individual tips.
- A/B testing of onboarding variants.
- Deep-linking into the tour from email or push.
- Force-blocking the UI to make onboarding unavoidable.

## Flow

1. User completes signup. `AuthManager.isAuthenticated` flips to `true`. `ContentView` mounts.
2. `ContentView.task` loads memories + tickets, then calls `onboardingCoordinator.evaluateEligibility(...)`. If `onboarding.completed == false` AND `onboarding.skipped == false` AND both counts are zero, coordinator sets `showWelcome = true`.
3. `ContentView` presents the welcome sheet. User taps **Start** or **Skip**.
   - **Skip** → `skipped = true`, `welcomeSeen = true`, sheet dismisses, no tips ever fire.
   - **Start** → `welcomeSeen = true`, `Tips.Event` named `onboardingStarted` is donated, sheet dismisses to Memories tab.
4. `MemoryTip` popover appears on the "New memory" CTA in `CollectionsView` (rule: `onboardingStarted` donated AND `firstMemoryCreated` not donated).
5. User creates a memory. `CollectionsStore.addMemory` success path donates `firstMemoryCreated`. `OnboardingCoordinator` pushes `MemoryDetailView(memory: new)` onto the Memories nav stack.
6. `TicketTip` popover appears on the "Add ticket" button in `MemoryDetailView`.
7. User taps it, runs the existing `NewTicketFunnel` flow, lands on `SuccessStep`.
8. `SuccessStep.onAppear` donates `firstTicketCreated`. `ExportTip` popover appears on the Export tile.
9. User taps Export. `onboardingComplete` donated, `completed = true`. Tour ends. TipKit's built-in per-tip invalidation means tips never reappear.

**Skip-after-start path:** user taps Start, then abandons. Tips live in TipKit's datastore and resume on the next relevant view visit. If the user never returns to the relevant screen, no further tips fire and no state corruption occurs.

## Architecture

### Approach

TipKit rules + shared events (evaluated as Approach 1 in brainstorm). Each tip is a small `Tip` struct with rules tied to shared `Tips.Event` instances owned by `OnboardingCoordinator`. TipKit handles persistence, first-show logic, and invalidation natively. `Tips.resetDatastore()` is the reset mechanism.

### Components

#### New files

- `Lumoria App/views/onboarding/OnboardingCoordinator.swift`
  - `@MainActor final class OnboardingCoordinator: ObservableObject` (uses `@Published`, matches the rest of the app's coordinators like `AuthManager` and `WalletImportCoordinator`)
  - `@AppStorage`-backed flags: `welcomeSeen`, `skipped`, `completed`
  - `@Published var showWelcome: Bool` — drives the sheet presentation
  - `@Published var pendingMemoryToOpen: Memory? = nil` — drives auto-navigation after first memory creation
  - Methods: `start()`, `skip()`, `donateMemoryCreated(_:)`, `donateTicketCreated()`, `donateExportOpened()`, `reset()`
  - Tracks `startedAt: Date?` for duration analytics
  - Exposes `evaluateEligibility(memoriesCount:, ticketsCount:)` — called by `ContentView` after both stores finish their initial `.load()`. If either count > 0 and no flags set, mark `completed = true` silently (returning-user gate). Otherwise set `showWelcome = true` when `!welcomeSeen && !skipped && !completed`. This is the single entry point — no separate auth-change hook, because stores need to be loaded first anyway.

- `Lumoria App/views/onboarding/OnboardingTips.swift`
  - Shared `Tips.Event` constants: `onboardingStarted`, `firstMemoryCreated`, `firstTicketCreated`, `onboardingComplete`
  - `struct MemoryTip: Tip` — rule: `#Rule(Self.$onboardingStarted) { $0.donations.count > 0 }` AND `#Rule(Self.$firstMemoryCreated) { $0.donations.count == 0 }`
  - `struct TicketTip: Tip` — rule: memory donated AND ticket not donated
  - `struct ExportTip: Tip` — rule: ticket donated AND export not donated

- `Lumoria App/views/onboarding/WelcomeSheetView.swift`
  - Visual direction: hero logogram + 3 numbered steps + primary/tertiary CTAs (brainstorm option A)
  - Voice direction: direct & plain (brainstorm voice option A)
  - Copy:
    - Title: "Create your first ticket in three steps."
    - Subtitle: "About a minute."
    - Steps: "Create a memory", "Add a ticket", "Share it"
    - Primary CTA: "Start"
    - Tertiary: "Skip"
  - Uses Lumoria tokens: `Color.Background.default`, `Button.primary.*`, SF Pro per brand spec, 16pt radius on buttons.

#### Modified files

- `Lumoria App/Lumoria_AppApp.swift`
  - Call `try? Tips.configure([.displayFrequency(.immediate), .datastoreLocation(.applicationDefault)])` in the existing bootstrap block.
  - `@StateObject private var onboardingCoordinator = OnboardingCoordinator()`
  - Inject as `.environmentObject(onboardingCoordinator)` when the user is signed in.
  - Inject the coordinator only once the tab UI mounts (so `ContentView`'s `.task` can call `evaluateEligibility` after the stores load).

- `Lumoria App/ContentView.swift`
  - Read coordinator from env. Attach `.sheet(isPresented: $coordinator.showWelcome) { WelcomeSheetView() }` to the TabView.
  - Bind `coordinator.pendingMemoryToOpen` to programmatically push `MemoryDetailView` onto the Memories nav stack via `NavigationPath`.

- `Lumoria App/views/collections/CollectionsView.swift`
  - `.popoverTip(MemoryTip())` on the "New memory" CTA.

- `Lumoria App/views/collections/CollectionsStore.swift`
  - On `addMemory` success: `onboardingCoordinator.donateMemoryCreated(newMemory)`.
  - Coordinator resolved via a weak setter on `CollectionsStore` called from `ContentView`'s `.task` (mirrors how `ContentView` already wires env stores after init). Avoids making `CollectionsStore` depend on a global singleton.

- `Lumoria App/views/collections/CollectionDetailView.swift`
  - `.popoverTip(TicketTip())` on the "Add ticket" button.

- `Lumoria App/views/tickets/new/SuccessStep.swift`
  - `.popoverTip(ExportTip())` on the Export tile.
  - `.onAppear { coordinator.donateTicketCreated() }` (only when in onboarding window).
  - Export tile tap → `coordinator.donateExportOpened()`.

- `Lumoria App/views/settings/SettingsView.swift`
  - New row: "Replay onboarding" → calls `coordinator.reset()`.

- `Lumoria App/services/analytics/AnalyticsEvent.swift`
  - New cases under `// MARK: — Onboarding`:
    - `onboardingShown`
    - `onboardingStarted`
    - `onboardingSkipped(atStep: OnboardingStepProp)`
    - `onboardingStepCompleted(step: OnboardingStepProp)`
    - `onboardingCompleted(durationSeconds: Int)`
    - `onboardingReplayed`

- `Lumoria App/services/analytics/AnalyticsProperty.swift`
  - New: `enum OnboardingStepProp: String { case welcome, memory, ticket, export }`.

- `Lumoria App/Localizable.xcstrings`
  - Keys for welcome sheet copy, 3 tip titles + messages, settings row, analytics screen names.

### State machine

Persisted flags (all `@AppStorage`):

| Flag | Default | Set true when |
|------|---------|---------------|
| `onboarding.welcomeSeen` | false | "Start" or "Skip" tapped |
| `onboarding.skipped` | false | "Skip" tapped |
| `onboarding.completed` | false | Export tile tapped during tour, OR existing-user gate fires |

Transitions (TipKit `Tips.Event` donations):

| Event | Donated at | Unlocks |
|-------|-----------|---------|
| `onboardingStarted` | Welcome "Start" tap | MemoryTip |
| `firstMemoryCreated` | `CollectionsStore.addMemory` success during tour | TicketTip + auto-push to MemoryDetailView |
| `firstTicketCreated` | `SuccessStep.onAppear` during tour | ExportTip |
| `onboardingComplete` | Export tile tap during tour | sets `completed = true` |

## Copy (locked)

### Welcome sheet (option A — direct & plain)
- Title: **Create your first ticket in three steps.**
- Subtitle: About a minute.
- Steps: Create a memory · Add a ticket · Share it
- Primary CTA: **Start**
- Tertiary: Skip

### Tips
- **MemoryTip** — "Create a memory" / "A trip, a show, anything. Give it a name."
- **TicketTip** — "Add a ticket" / "Pick a style. Fill in the details."
- **ExportTip** — "Share it" / "Post it, send it, or save it to camera roll."

### Settings row
- Label: **Replay onboarding**

### Terminology
- **Memory** (app-canonical) — never "collection", "folder", "album"
- **Ticket** — never "stub", "pass", "card"
- Verbs: **create**, **add**, **share**

Voice dimensions: casual · neutral · simple · authoritative. No sensory or literary language in onboarding surfaces.

## Edge cases

- **Signup fails / network drop during welcome:** auth flips back, `ContentView` unmounts. Flags persisted, so welcome reshows on next successful auth.
- **Multi-device:** flags are `@AppStorage` (device-local). A user who signed up on one device gets the tour again on a new one. Accepted.
- **App delete + reinstall:** `@AppStorage` wiped, tour reshows. Accepted.
- **User creates memory/ticket outside the tour path** (e.g., never taps Start, then creates via All Tickets): tips gate on `onboardingStarted`, so they don't fire for skippers. For returning existing users, the gate at init marks `completed = true` so no donations trigger anything.
- **Backgrounding mid-flow:** TipKit datastore persists events; next relevant view resumes the correct tip. Tips already seen don't reappear.
- **Replay from Settings:** `coordinator.reset()` clears flags, calls `Tips.resetDatastore()`, sets `showWelcome = true`. Settings sheet is dismissed first (it's modal over ContentView), then the welcome sheet presents. If a tap race puts this into a bad state, worst case is the welcome sheet presents one tick late — acceptable.
- **Auto-push to MemoryDetailView fails:** if `NavigationPath` push fails for any reason, the memory tip is invalidated but the ticket tip's rule (memory donated + ticket not donated) still fires on any subsequent visit to a `MemoryDetailView`. Self-healing.
- **User dismisses a tip without acting:** TipKit auto-invalidates dismissed tips. User must complete the underlying action for the chain to advance, via the normal UI. If the user never does, no further tips fire; `completed` stays false indefinitely — analytics reflects drop-off point.

## Analytics

New events (see Modified files above). Properties: `OnboardingStepProp { welcome, memory, ticket, export }`. Durations tracked via `startedAt` stamped when `start()` is called. Adds matching rows in the Notion Events DB in the same PR.

## Testing

### Unit (OnboardingCoordinator)
- Fresh state (no memories, no tickets, no flags) → `showWelcome == true` after `evaluateEligibility(memoriesCount: 0, ticketsCount: 0)`.
- `skip()` → `skipped == true`, `showWelcome == false`, subsequent donations no-op.
- `reset()` → all flags cleared, `Tips.resetDatastore()` invoked (mock), `showWelcome == true`.
- Existing-user gate: injecting non-empty stores at init → `completed == true`, no sheet.
- `donateMemoryCreated(_:)` during tour → sets `pendingMemoryToOpen`. Outside tour → no-op.
- Duration: `start()` at T0, `donateExportOpened()` at T0+60s → `onboardingCompleted(durationSeconds: 60)` fires.

### Snapshot
- `WelcomeSheetView` in Light, Dark, HC Light, HC Dark variants.

### Manual
- Fresh signup → happy path end-to-end → verify 6 analytics events fire in order.
- Fresh signup → Skip → verify `onboardingShown` + `onboardingSkipped(atStep: .welcome)` only.
- Complete → go to Settings → Replay → verify `onboardingReplayed` + fresh tip chain.
- Signup on device with existing test data (memories > 0) → verify no sheet, no tips.

### TipKit note
Popovers aren't part of the SwiftUI view hierarchy in the testable sense; verify presence via UI tests hitting the rendered popover's accessibility label, not snapshots.

## Open decisions — none

All open questions resolved during brainstorm. Ready for planning.
