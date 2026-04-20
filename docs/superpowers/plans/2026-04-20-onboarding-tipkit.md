# Onboarding with TipKit — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a one-time welcome sheet + TipKit tip chain that guides fresh signups through creating a memory, adding a ticket, and sharing it.

**Architecture:** A single `OnboardingCoordinator` (ObservableObject) owns persisted flags and TipKit `Tips.Event` donations. Three small `Tip` structs drive popover tips on the relevant UI anchors. The welcome sheet is presented from `ContentView` after both stores load and the eligibility gate passes. Skip/replay state lives in `@AppStorage`; tour progress lives in TipKit's datastore.

**Tech Stack:** SwiftUI, TipKit (iOS 17+), Swift Testing (`@Suite` / `@Test` / `#expect`), Supabase (existing auth + stores), Amplitude (existing analytics).

**Spec:** `docs/superpowers/specs/2026-04-20-onboarding-tipkit-design.md`.

**Min iOS target:** 26.0 — TipKit available unconditionally. No availability checks needed.

---

## File Structure

### New files

| Path | Responsibility |
|------|----------------|
| `Lumoria App/views/onboarding/OnboardingCoordinator.swift` | State machine, persistence, event donations, analytics emission, store reference wiring. |
| `Lumoria App/views/onboarding/OnboardingTips.swift` | Shared `Tips.Event` instances + three `Tip` structs with rules + localized copy. |
| `Lumoria App/views/onboarding/WelcomeSheetView.swift` | The welcome sheet UI (logogram hero + 3 steps + Start/Skip CTAs). |
| `Lumoria AppTests/OnboardingCoordinatorTests.swift` | Unit tests for coordinator state transitions + eligibility gate + analytics. |

### Modified files

| Path | What changes |
|------|-------------|
| `Lumoria App/Lumoria_AppApp.swift` | Call `Tips.configure`, own `@StateObject onboardingCoordinator`, inject into `ContentView`. |
| `Lumoria App/ContentView.swift` | Present welcome sheet, wire coordinator into stores, call `evaluateEligibility` after stores load, auto-push `MemoryDetailView` on pending memory, track pending ticket-created donations. |
| `Lumoria App/views/collections/CollectionsStore.swift` | Hold a weak ref to coordinator; donate memory-created on `create` success. |
| `Lumoria App/views/collections/CollectionsView.swift` | `.popoverTip(MemoryTip())` on the `+` icon button. |
| `Lumoria App/views/collections/CollectionDetailView.swift` | `.popoverTip(TicketTip())` on the "+ new ticket" icon button. |
| `Lumoria App/views/tickets/new/SuccessStep.swift` | `.popoverTip(ExportTip())` on the Export button; donate ticket-created on appear; donate export-opened on tap. |
| `Lumoria App/views/settings/SettingsView.swift` | New row "Replay onboarding" → `coordinator.reset()`. |
| `Lumoria App/services/analytics/AnalyticsEvent.swift` | New enum cases + name mappings + property mappings for 6 onboarding events. |
| `Lumoria App/services/analytics/AnalyticsProperty.swift` | New `OnboardingStepProp` enum. |
| `Lumoria App/Localizable.xcstrings` | Copy keys for welcome sheet, 3 tips, settings row. |

### Out of scope

- Mid-tour skip on individual tips (v2).
- Deep-link to replay from email/push (v2).
- A/B testing variants (v2).

---

## Task 1 — Analytics property: `OnboardingStepProp`

**Files:**
- Modify: `Lumoria App/services/analytics/AnalyticsProperty.swift`

- [ ] **Step 1: Read the existing file to find a clean insertion point**

Look for existing small enum props declared with `: String` conformance so the new one follows convention.

- [ ] **Step 2: Add the enum**

Append at the end of `AnalyticsProperty.swift`:

```swift
enum OnboardingStepProp: String {
    case welcome
    case memory
    case ticket
    case export
}
```

- [ ] **Step 3: Build the Lumoria App scheme to confirm the file compiles**

```bash
xcodebuild -project "Lumoria App.xcodeproj" -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 17" build
```

Expected: ** BUILD SUCCEEDED **

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/services/analytics/AnalyticsProperty.swift"
git commit -m "feat(analytics): add OnboardingStepProp"
```

---

## Task 2 — Analytics events: six onboarding cases

**Files:**
- Modify: `Lumoria App/services/analytics/AnalyticsEvent.swift`
- Test: `Lumoria AppTests/AnalyticsEventTests.swift`

- [ ] **Step 1: Write failing tests for the new events**

Append to `AnalyticsEventTests.swift` inside the existing `AnalyticsEventTests` suite:

```swift
@Test("onboardingShown has the right name and empty props")
func onboardingShownShape() {
    let event = AnalyticsEvent.onboardingShown
    #expect(event.name == "Onboarding Shown")
    #expect(event.properties.isEmpty)
}

@Test("onboardingStarted has the right name")
func onboardingStartedShape() {
    let event = AnalyticsEvent.onboardingStarted
    #expect(event.name == "Onboarding Started")
    #expect(event.properties.isEmpty)
}

@Test("onboardingSkipped carries the step")
func onboardingSkippedShape() {
    let event = AnalyticsEvent.onboardingSkipped(atStep: .welcome)
    #expect(event.name == "Onboarding Skipped")
    #expect(event.properties["at_step"] as? String == "welcome")
}

@Test("onboardingStepCompleted carries the step")
func onboardingStepCompletedShape() {
    let event = AnalyticsEvent.onboardingStepCompleted(step: .ticket)
    #expect(event.name == "Onboarding Step Completed")
    #expect(event.properties["step"] as? String == "ticket")
}

@Test("onboardingCompleted carries duration")
func onboardingCompletedShape() {
    let event = AnalyticsEvent.onboardingCompleted(durationSeconds: 42)
    #expect(event.name == "Onboarding Completed")
    #expect(event.properties["duration_seconds"] as? Int == 42)
}

@Test("onboardingReplayed has the right name")
func onboardingReplayedShape() {
    let event = AnalyticsEvent.onboardingReplayed
    #expect(event.name == "Onboarding Replayed")
    #expect(event.properties.isEmpty)
}
```

- [ ] **Step 2: Run the tests to confirm they fail**

```bash
xcodebuild test -project "Lumoria App.xcodeproj" -scheme "Lumoria App" \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -only-testing:Lumoria_AppTests/AnalyticsEventTests
```

Expected: FAIL with "type 'AnalyticsEvent' has no member 'onboardingShown'" (etc.).

- [ ] **Step 3: Add the six cases to `AnalyticsEvent.swift`**

After the `// MARK: — System` block, append:

```swift
    // MARK: — Onboarding
    case onboardingShown
    case onboardingStarted
    case onboardingSkipped(atStep: OnboardingStepProp)
    case onboardingStepCompleted(step: OnboardingStepProp)
    case onboardingCompleted(durationSeconds: Int)
    case onboardingReplayed
```

- [ ] **Step 4: Add name mappings**

Inside the existing `name` computed property's giant switch (after the System block), append:

```swift
        // Onboarding
        case .onboardingShown: return "Onboarding Shown"
        case .onboardingStarted: return "Onboarding Started"
        case .onboardingSkipped: return "Onboarding Skipped"
        case .onboardingStepCompleted: return "Onboarding Step Completed"
        case .onboardingCompleted: return "Onboarding Completed"
        case .onboardingReplayed: return "Onboarding Replayed"
```

- [ ] **Step 5: Add property mappings**

Inside the existing `properties` computed property's switch, add cases:

```swift
        case .onboardingShown, .onboardingStarted, .onboardingReplayed:
            return [:]

        case .onboardingSkipped(let step):
            return ["at_step": step.rawValue]

        case .onboardingStepCompleted(let step):
            return ["step": step.rawValue]

        case .onboardingCompleted(let seconds):
            return ["duration_seconds": seconds]
```

Place these alongside the existing `.settingsOpened`-style cases; the exact insertion point is wherever the case pattern-matching fits (Swift doesn't care about order, the compiler does).

- [ ] **Step 6: Run the tests to confirm they pass**

```bash
xcodebuild test -project "Lumoria App.xcodeproj" -scheme "Lumoria App" \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -only-testing:Lumoria_AppTests/AnalyticsEventTests
```

Expected: all tests pass (existing + 6 new).

- [ ] **Step 7: Commit**

```bash
git add "Lumoria App/services/analytics/AnalyticsEvent.swift" \
        "Lumoria AppTests/AnalyticsEventTests.swift"
git commit -m "feat(analytics): add onboarding events"
```

---

## Task 3 — `OnboardingTips.swift` — events + three Tip structs

**Files:**
- Create: `Lumoria App/views/onboarding/OnboardingTips.swift`

- [ ] **Step 1: Create the onboarding folder**

```bash
mkdir -p "Lumoria App/views/onboarding"
```

- [ ] **Step 2: Write `OnboardingTips.swift`**

Create `Lumoria App/views/onboarding/OnboardingTips.swift`:

```swift
//
//  OnboardingTips.swift
//  Lumoria App
//
//  TipKit Tip definitions + shared Tips.Event instances used by the
//  onboarding chain. OnboardingCoordinator donates to these events; each
//  Tip's rule observes them to decide whether to show.
//

import SwiftUI
import TipKit

// MARK: - Shared events

enum OnboardingEvents {
    static let onboardingStarted    = Tips.Event(id: "onboarding.started")
    static let firstMemoryCreated   = Tips.Event(id: "onboarding.firstMemoryCreated")
    static let firstTicketCreated   = Tips.Event(id: "onboarding.firstTicketCreated")
    static let onboardingComplete   = Tips.Event(id: "onboarding.complete")
}

// MARK: - Memory tip

struct MemoryTip: Tip {
    var title: Text {
        Text("onboarding.tip.memory.title")
    }
    var message: Text? {
        Text("onboarding.tip.memory.message")
    }
    var rules: [Rule] {
        #Rule(OnboardingEvents.onboardingStarted) { $0.donations.count > 0 }
        #Rule(OnboardingEvents.firstMemoryCreated) { $0.donations.count == 0 }
    }
}

// MARK: - Ticket tip

struct TicketTip: Tip {
    var title: Text {
        Text("onboarding.tip.ticket.title")
    }
    var message: Text? {
        Text("onboarding.tip.ticket.message")
    }
    var rules: [Rule] {
        #Rule(OnboardingEvents.firstMemoryCreated) { $0.donations.count > 0 }
        #Rule(OnboardingEvents.firstTicketCreated) { $0.donations.count == 0 }
    }
}

// MARK: - Export tip

struct ExportTip: Tip {
    var title: Text {
        Text("onboarding.tip.export.title")
    }
    var message: Text? {
        Text("onboarding.tip.export.message")
    }
    var rules: [Rule] {
        #Rule(OnboardingEvents.firstTicketCreated) { $0.donations.count > 0 }
        #Rule(OnboardingEvents.onboardingComplete) { $0.donations.count == 0 }
    }
}
```

- [ ] **Step 3: Add the file to the Xcode project**

Open `Lumoria App.xcodeproj` in Xcode. Drag `OnboardingTips.swift` into the `views/onboarding/` group (create the group if needed) with the `Lumoria App` target checked. Save (`Cmd+S`) and close Xcode.

Alternative: edit `Lumoria App.xcodeproj/project.pbxproj` to add the PBXFileReference + PBXBuildFile + PBXGroup entry. Only do this if comfortable with pbxproj editing — the Xcode UI is safer.

- [ ] **Step 4: Build to confirm it compiles**

```bash
xcodebuild -project "Lumoria App.xcodeproj" -scheme "Lumoria App" \
  -destination "platform=iOS Simulator,name=iPhone 17" build
```

Expected: ** BUILD SUCCEEDED ** (localization keys will show as raw keys at runtime until Task 10).

- [ ] **Step 5: Commit**

```bash
git add "Lumoria App/views/onboarding/OnboardingTips.swift" \
        "Lumoria App.xcodeproj/project.pbxproj"
git commit -m "feat(onboarding): add Tip structs + shared Tips.Events"
```

---

## Task 4 — `OnboardingCoordinator.swift`

**Files:**
- Create: `Lumoria App/views/onboarding/OnboardingCoordinator.swift`
- Create: `Lumoria AppTests/OnboardingCoordinatorTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Lumoria AppTests/OnboardingCoordinatorTests.swift`:

```swift
//
//  OnboardingCoordinatorTests.swift
//  Lumoria AppTests
//
//  State-transition tests for the onboarding coordinator. Does not exercise
//  TipKit donations (those require a real Tips.Event datastore) — instead
//  asserts on the coordinator's own published state + analytics emissions.
//

import Foundation
import Testing
@testable import Lumoria_App

@MainActor
@Suite("OnboardingCoordinator")
struct OnboardingCoordinatorTests {

    // Each test uses a unique UserDefaults suite so @AppStorage reads don't
    // leak between tests. The coordinator accepts a UserDefaults instance
    // in its initializer for this reason.
    private func fresh() -> OnboardingCoordinator {
        let suiteName = "onboarding.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return OnboardingCoordinator(defaults: defaults)
    }

    @Test("fresh user with zero data shows welcome")
    func eligibilityFreshUser() {
        let c = fresh()
        c.evaluateEligibility(memoriesCount: 0, ticketsCount: 0)
        #expect(c.showWelcome == true)
        #expect(c.completed == false)
        #expect(c.skipped == false)
    }

    @Test("existing user with memories is silently completed")
    func eligibilityExistingUser() {
        let c = fresh()
        c.evaluateEligibility(memoriesCount: 2, ticketsCount: 0)
        #expect(c.showWelcome == false)
        #expect(c.completed == true)
    }

    @Test("skip sets flags and suppresses future evaluations")
    func skipPath() {
        let c = fresh()
        c.evaluateEligibility(memoriesCount: 0, ticketsCount: 0)
        c.skip()
        #expect(c.showWelcome == false)
        #expect(c.skipped == true)
        #expect(c.welcomeSeen == true)

        // Re-evaluating should not reopen the sheet.
        c.evaluateEligibility(memoriesCount: 0, ticketsCount: 0)
        #expect(c.showWelcome == false)
    }

    @Test("start sets welcomeSeen and stamps startedAt")
    func startPath() {
        let c = fresh()
        c.evaluateEligibility(memoriesCount: 0, ticketsCount: 0)
        c.start()
        #expect(c.welcomeSeen == true)
        #expect(c.showWelcome == false)
        #expect(c.startedAt != nil)
    }

    @Test("reset clears flags and reopens welcome")
    func resetPath() {
        let c = fresh()
        c.evaluateEligibility(memoriesCount: 0, ticketsCount: 0)
        c.start()
        c.donateExportOpened()
        #expect(c.completed == true)

        c.reset()
        #expect(c.welcomeSeen == false)
        #expect(c.completed == false)
        #expect(c.skipped == false)
        #expect(c.showWelcome == true)
    }

    @Test("donations only count during an active tour")
    func donationsGatedByStart() {
        let c = fresh()
        // Not started — donations should be ignored.
        c.donateMemoryCreated(.init(
            id: UUID(), userId: UUID(),
            name: "m", colorFamily: "sky", emoji: nil,
            createdAt: .now, updatedAt: .now
        ))
        #expect(c.pendingMemoryToOpen == nil)

        c.evaluateEligibility(memoriesCount: 0, ticketsCount: 0)
        c.start()
        let memory = Memory(
            id: UUID(), userId: UUID(),
            name: "m2", colorFamily: "sky", emoji: nil,
            createdAt: .now, updatedAt: .now
        )
        c.donateMemoryCreated(memory)
        #expect(c.pendingMemoryToOpen?.id == memory.id)
    }
}
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
xcodebuild test -project "Lumoria App.xcodeproj" -scheme "Lumoria App" \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -only-testing:Lumoria_AppTests/OnboardingCoordinatorTests
```

Expected: FAIL with "cannot find 'OnboardingCoordinator' in scope".

- [ ] **Step 3: Write `OnboardingCoordinator.swift`**

Create `Lumoria App/views/onboarding/OnboardingCoordinator.swift`:

```swift
//
//  OnboardingCoordinator.swift
//  Lumoria App
//
//  Owns the state machine for the first-run tour: welcome sheet visibility,
//  persisted skip/complete flags, TipKit event donations, and the pending
//  memory that the Memories tab should auto-push after creation. Analytics
//  are emitted here so the UI stays dumb.
//

import Combine
import Foundation
import SwiftUI
import TipKit

@MainActor
final class OnboardingCoordinator: ObservableObject {

    // MARK: - Published UI state

    @Published var showWelcome: Bool = false
    @Published var pendingMemoryToOpen: Memory? = nil

    // MARK: - Persisted flags (AppStorage-backed, but accessed via UserDefaults
    // so tests can inject a throwaway suite).

    @Published private(set) var welcomeSeen: Bool
    @Published private(set) var skipped: Bool
    @Published private(set) var completed: Bool

    /// Stamped when `start()` runs; used to compute the final duration.
    private(set) var startedAt: Date?

    private let defaults: UserDefaults

    private enum Keys {
        static let welcomeSeen = "onboarding.welcomeSeen"
        static let skipped     = "onboarding.skipped"
        static let completed   = "onboarding.completed"
    }

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.welcomeSeen = defaults.bool(forKey: Keys.welcomeSeen)
        self.skipped     = defaults.bool(forKey: Keys.skipped)
        self.completed   = defaults.bool(forKey: Keys.completed)
    }

    // MARK: - Eligibility

    /// Called by `ContentView` after the stores' initial `.load()` completes.
    /// If the user already has any memories or tickets they're a returning
    /// user — silently mark onboarding completed so we never fire tips for
    /// them. Otherwise open the welcome sheet if they haven't seen it.
    func evaluateEligibility(memoriesCount: Int, ticketsCount: Int) {
        if completed || skipped { return }

        if memoriesCount > 0 || ticketsCount > 0 {
            setCompleted(true)
            return
        }

        if !welcomeSeen {
            showWelcome = true
            Analytics.track(.onboardingShown)
        }
    }

    // MARK: - User actions

    func start() {
        setWelcomeSeen(true)
        showWelcome = false
        startedAt = Date()
        OnboardingEvents.onboardingStarted.donate()
        Analytics.track(.onboardingStarted)
    }

    func skip() {
        setWelcomeSeen(true)
        setSkipped(true)
        showWelcome = false
        Analytics.track(.onboardingSkipped(atStep: .welcome))
    }

    func reset() {
        setWelcomeSeen(false)
        setSkipped(false)
        setCompleted(false)
        startedAt = nil
        pendingMemoryToOpen = nil

        Task { try? Tips.resetDatastore() }

        Analytics.track(.onboardingReplayed)
        showWelcome = true
    }

    // MARK: - Donations

    /// Called by `MemoriesStore` after a successful `create`.
    /// Only takes effect inside an active tour (post-start, pre-complete).
    func donateMemoryCreated(_ memory: Memory) {
        guard isInTour else { return }
        OnboardingEvents.firstMemoryCreated.donate()
        pendingMemoryToOpen = memory
        Analytics.track(.onboardingStepCompleted(step: .memory))
    }

    /// Called by `SuccessStep.onAppear`.
    func donateTicketCreated() {
        guard isInTour else { return }
        OnboardingEvents.firstTicketCreated.donate()
        Analytics.track(.onboardingStepCompleted(step: .ticket))
    }

    /// Called when the user taps the Export tile during the tour.
    func donateExportOpened() {
        guard isInTour else { return }
        OnboardingEvents.onboardingComplete.donate()
        Analytics.track(.onboardingStepCompleted(step: .export))

        let duration: Int
        if let startedAt {
            duration = Int(Date().timeIntervalSince(startedAt))
        } else {
            duration = 0
        }
        setCompleted(true)
        Analytics.track(.onboardingCompleted(durationSeconds: duration))
    }

    // MARK: - Helpers

    private var isInTour: Bool { welcomeSeen && !skipped && !completed }

    private func setWelcomeSeen(_ value: Bool) {
        welcomeSeen = value
        defaults.set(value, forKey: Keys.welcomeSeen)
    }
    private func setSkipped(_ value: Bool) {
        skipped = value
        defaults.set(value, forKey: Keys.skipped)
    }
    private func setCompleted(_ value: Bool) {
        completed = value
        defaults.set(value, forKey: Keys.completed)
    }
}
```

- [ ] **Step 4: Add both files to the Xcode project**

In Xcode: drag `OnboardingCoordinator.swift` into `views/onboarding/` (target: Lumoria App). Drag `OnboardingCoordinatorTests.swift` into `Lumoria AppTests/` (target: Lumoria AppTests). Save, close.

- [ ] **Step 5: Run the tests to confirm they pass**

```bash
xcodebuild test -project "Lumoria App.xcodeproj" -scheme "Lumoria App" \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -only-testing:Lumoria_AppTests/OnboardingCoordinatorTests
```

Expected: all 6 tests pass.

- [ ] **Step 6: Commit**

```bash
git add "Lumoria App/views/onboarding/OnboardingCoordinator.swift" \
        "Lumoria AppTests/OnboardingCoordinatorTests.swift" \
        "Lumoria App.xcodeproj/project.pbxproj"
git commit -m "feat(onboarding): add OnboardingCoordinator state machine"
```

---

## Task 5 — Localization keys

**Files:**
- Modify: `Lumoria App/Localizable.xcstrings`

- [ ] **Step 1: Open `Localizable.xcstrings` in Xcode**

String Catalog editor. Add one new row per key below (base localization: English).

| Key | English value |
|-----|---------------|
| `onboarding.welcome.title` | Create your first ticket in three steps. |
| `onboarding.welcome.subtitle` | About a minute. |
| `onboarding.welcome.step.memory` | Create a memory |
| `onboarding.welcome.step.ticket` | Add a ticket |
| `onboarding.welcome.step.export` | Share it |
| `onboarding.welcome.cta.start` | Start |
| `onboarding.welcome.cta.skip` | Skip |
| `onboarding.tip.memory.title` | Create a memory |
| `onboarding.tip.memory.message` | A trip, a show, anything. Give it a name. |
| `onboarding.tip.ticket.title` | Add a ticket |
| `onboarding.tip.ticket.message` | Pick a style. Fill in the details. |
| `onboarding.tip.export.title` | Share it |
| `onboarding.tip.export.message` | Post it, send it, or save it to camera roll. |
| `onboarding.settings.replay` | Replay onboarding |

- [ ] **Step 2: Build to confirm no syntax errors**

```bash
xcodebuild -project "Lumoria App.xcodeproj" -scheme "Lumoria App" \
  -destination "platform=iOS Simulator,name=iPhone 17" build
```

Expected: ** BUILD SUCCEEDED **.

- [ ] **Step 3: Commit**

```bash
git add "Lumoria App/Localizable.xcstrings"
git commit -m "feat(onboarding): add localization keys"
```

---

## Task 6 — `WelcomeSheetView.swift`

**Files:**
- Create: `Lumoria App/views/onboarding/WelcomeSheetView.swift`

- [ ] **Step 1: Write the view**

Create `Lumoria App/views/onboarding/WelcomeSheetView.swift`:

```swift
//
//  WelcomeSheetView.swift
//  Lumoria App
//
//  One-shot onboarding welcome sheet shown after signup. Calls
//  OnboardingCoordinator.start() or .skip() when the user picks.
//

import SwiftUI

struct WelcomeSheetView: View {
    @EnvironmentObject private var coordinator: OnboardingCoordinator
    @Environment(\.brandSlug) private var brandSlug

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 24)

            hero
                .frame(maxWidth: .infinity)
                .padding(.bottom, 32)

            Text("onboarding.welcome.title")
                .font(.system(size: 28, weight: .bold))
                .tracking(-0.4)
                .foregroundStyle(Color.Text.primary)
                .padding(.horizontal, 24)

            Text("onboarding.welcome.subtitle")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.Text.secondary)
                .padding(.top, 8)
                .padding(.horizontal, 24)

            steps
                .padding(.horizontal, 24)
                .padding(.top, 24)

            Spacer()

            ctaStack
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
        }
        .background(Color.Background.default.ignoresSafeArea())
        .interactiveDismissDisabled(true)
    }

    // MARK: - Hero

    private var hero: some View {
        Image("brand/\(brandSlug)/logomark")
            .resizable()
            .scaledToFit()
            .frame(width: 96, height: 96)
    }

    // MARK: - Steps

    private var steps: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepRow(index: 1, labelKey: "onboarding.welcome.step.memory")
            stepRow(index: 2, labelKey: "onboarding.welcome.step.ticket")
            stepRow(index: 3, labelKey: "onboarding.welcome.step.export")
        }
    }

    private func stepRow(index: Int, labelKey: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.Text.primary)
                    .frame(width: 24, height: 24)
                Text("\(index)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.Background.default)
            }
            Text(labelKey)
                .font(.system(size: 17))
                .foregroundStyle(Color.Text.primary)
        }
    }

    // MARK: - CTAs

    private var ctaStack: some View {
        VStack(spacing: 8) {
            Button {
                coordinator.start()
            } label: {
                Text("onboarding.welcome.cta.start")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(Color.Text.primary)
                    .foregroundStyle(Color.Background.default)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            Button {
                coordinator.skip()
            } label: {
                Text("onboarding.welcome.cta.skip")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.Text.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
    }
}
```

**Note on color tokens:** the app already has `Color.Text.primary`, `Color.Text.secondary`, `Color.Background.default`, `Color.Background.elevated` — verify these exist by grepping the codebase; if names differ, substitute the existing names without changing the visual intent.

- [ ] **Step 2: Add to Xcode project**

Drag into `views/onboarding/` group, target: Lumoria App.

- [ ] **Step 3: Build**

```bash
xcodebuild -project "Lumoria App.xcodeproj" -scheme "Lumoria App" \
  -destination "platform=iOS Simulator,name=iPhone 17" build
```

Expected: ** BUILD SUCCEEDED **. If any `Color.Text.*` or `Color.Background.*` fails to resolve, grep `Color\.(Text|Background)\.` in the codebase and use whatever shape the app already uses.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/views/onboarding/WelcomeSheetView.swift" \
        "Lumoria App.xcodeproj/project.pbxproj"
git commit -m "feat(onboarding): add WelcomeSheetView"
```

---

## Task 7 — Wire into `Lumoria_AppApp.swift`

**Files:**
- Modify: `Lumoria App/Lumoria_AppApp.swift`

- [ ] **Step 1: Import TipKit and call `Tips.configure`**

At the top of `Lumoria_AppApp.swift`, add import:

```swift
import TipKit
```

In the existing `analyticsBootstrap` closure (line ~14), append after the existing body:

```swift
    try? Tips.configure([
        .displayFrequency(.immediate),
        .datastoreLocation(.applicationDefault),
    ])
```

- [ ] **Step 2: Add the coordinator as a `@StateObject`**

In the `Lumoria_AppApp` struct, after the existing `@StateObject` declarations:

```swift
    @StateObject private var onboardingCoordinator = OnboardingCoordinator()
```

- [ ] **Step 3: Inject into `ContentView`**

In the authed branch (`if shouldShowAuthedUI`), add the environment object to the existing chain:

```swift
                if shouldShowAuthedUI {
                    ContentView()
                        .environmentObject(authManager)
                        .environmentObject(pushService)
                        .environmentObject(notificationPrefs)
                        .environmentObject(walletImport)
                        .environmentObject(onboardingCoordinator)
                }
```

- [ ] **Step 4: Build and run on simulator — verify no regressions**

```bash
xcodebuild -project "Lumoria App.xcodeproj" -scheme "Lumoria App" \
  -destination "platform=iOS Simulator,name=iPhone 17" build
```

Expected: ** BUILD SUCCEEDED **. Launching the app should still show the existing content (no sheet yet — that happens in Task 9).

- [ ] **Step 5: Commit**

```bash
git add "Lumoria App/Lumoria_AppApp.swift"
git commit -m "feat(onboarding): configure TipKit + inject coordinator"
```

---

## Task 8 — Wire coordinator into `MemoriesStore`

**Files:**
- Modify: `Lumoria App/views/collections/CollectionsStore.swift`

The store needs a way to reach the coordinator from its `create` success path without owning it directly. Use a weak ref set from `ContentView`.

- [ ] **Step 1: Add a weak coordinator ref to `MemoriesStore`**

In `CollectionsStore.swift`, inside the `MemoriesStore` class definition, add:

```swift
    /// Set from `ContentView` after both are in the env. Weak so the
    /// coordinator's lifetime isn't pinned to the store.
    weak var onboardingCoordinator: OnboardingCoordinator?
```

- [ ] **Step 2: Donate memory-created inside `create(...)`**

Find the `create(name:colorFamily:emoji:)` method. At the end of the success path — right after the new memory is appended to `self.memories` and before the method returns — add:

```swift
        onboardingCoordinator?.donateMemoryCreated(newMemory)
```

(The local variable may already be named `memory` or `created` — use whichever name exists; the plan shows `newMemory` for clarity.)

- [ ] **Step 3: Build**

```bash
xcodebuild -project "Lumoria App.xcodeproj" -scheme "Lumoria App" \
  -destination "platform=iOS Simulator,name=iPhone 17" build
```

Expected: ** BUILD SUCCEEDED **.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/views/collections/CollectionsStore.swift"
git commit -m "feat(onboarding): MemoriesStore donates on create"
```

---

## Task 9 — `ContentView` wiring: sheet, eligibility, auto-push

**Files:**
- Modify: `Lumoria App/ContentView.swift`

- [ ] **Step 1: Read the coordinator from env and wire into stores**

At the top of the `ContentView` struct, add:

```swift
    @EnvironmentObject private var onboardingCoordinator: OnboardingCoordinator
```

- [ ] **Step 2: Set the coordinator on `MemoriesStore` after task-load**

Replace the existing `.task { ... }` block with:

```swift
        .task {
            memoriesStore.onboardingCoordinator = onboardingCoordinator
            await memoriesStore.load()
            await ticketsStore.load()
            await profileStore.load()
            await notificationsStore.load()
            onboardingCoordinator.evaluateEligibility(
                memoriesCount: memoriesStore.memories.count,
                ticketsCount: ticketsStore.tickets.count
            )
        }
```

- [ ] **Step 3: Present the welcome sheet**

On the `TabView` (after the existing modifiers), add:

```swift
        .sheet(isPresented: $onboardingCoordinator.showWelcome) {
            WelcomeSheetView()
                .environmentObject(onboardingCoordinator)
        }
```

- [ ] **Step 4: Auto-push `MemoryDetailView` when a pending memory arrives**

The Memories tab uses its own NavigationStack inside `MemoriesView`. Rather than reaching into it from `ContentView`, observe `pendingMemoryToOpen` at the `ContentView` level and switch to the Memories tab; `MemoriesView` will do the push itself in Task 9b. Add after the `.sheet`:

```swift
        .onChange(of: onboardingCoordinator.pendingMemoryToOpen) { _, memory in
            guard memory != nil else { return }
            selectedTab = 0 // Memories
        }
```

- [ ] **Step 5: Build**

```bash
xcodebuild -project "Lumoria App.xcodeproj" -scheme "Lumoria App" \
  -destination "platform=iOS Simulator,name=iPhone 17" build
```

Expected: ** BUILD SUCCEEDED **. Running a fresh simulator user should now see the welcome sheet post-signup.

- [ ] **Step 6: Commit**

```bash
git add "Lumoria App/ContentView.swift"
git commit -m "feat(onboarding): present welcome sheet + eligibility gate"
```

---

## Task 9b — `MemoriesView` auto-push on pendingMemoryToOpen

**Files:**
- Modify: `Lumoria App/views/collections/CollectionsView.swift`

The Memories tab owns the `NavigationStack`. It needs to watch `pendingMemoryToOpen` and push `MemoryDetailView(memory:)` onto its own stack.

- [ ] **Step 1: Read the coordinator from env**

At the top of the `MemoriesView` struct, after the existing `@EnvironmentObject` declarations:

```swift
    @EnvironmentObject private var onboardingCoordinator: OnboardingCoordinator
```

- [ ] **Step 2: Convert the existing navigation destination state to a `NavigationPath` if not already one**

If `MemoriesView` already uses `@State var path = NavigationPath()` bound to `NavigationStack(path: ...)`, skip to Step 3. Otherwise, introduce one:

```swift
    @State private var path = NavigationPath()
```

Wrap the existing navigation content in:

```swift
    NavigationStack(path: $path) {
        // existing content
    }
```

- [ ] **Step 3: Push on `pendingMemoryToOpen` change**

On the `NavigationStack`'s root (or the outer `ZStack`), add:

```swift
    .onChange(of: onboardingCoordinator.pendingMemoryToOpen) { _, memory in
        guard let memory else { return }
        path.append(memory)
        onboardingCoordinator.pendingMemoryToOpen = nil
    }
```

Ensure `Memory` is already routed in the existing `.navigationDestination(for: Memory.self)` — if not, add it pointing to `MemoryDetailView(memory: memory)`.

- [ ] **Step 4: Build and manually verify**

```bash
xcodebuild -project "Lumoria App.xcodeproj" -scheme "Lumoria App" \
  -destination "platform=iOS Simulator,name=iPhone 17" build
```

Manual check: on a fresh user, tap Start → create a memory → app should push the new memory's detail view automatically.

- [ ] **Step 5: Commit**

```bash
git add "Lumoria App/views/collections/CollectionsView.swift"
git commit -m "feat(onboarding): auto-push new memory detail during tour"
```

---

## Task 10 — `popoverTip(MemoryTip())` on the Memories "+" button

**Files:**
- Modify: `Lumoria App/views/collections/CollectionsView.swift`

- [ ] **Step 1: Import TipKit at the top of the file**

```swift
import TipKit
```

- [ ] **Step 2: Attach the tip**

Find the `LumoriaIconButton(systemImage: "plus")` around line 189 (the New Memory CTA). Attach:

```swift
    LumoriaIconButton(systemImage: "plus") {
        showNewMemory = true
    }
    .popoverTip(MemoryTip())
```

- [ ] **Step 3: Build**

```bash
xcodebuild -project "Lumoria App.xcodeproj" -scheme "Lumoria App" \
  -destination "platform=iOS Simulator,name=iPhone 17" build
```

Expected: ** BUILD SUCCEEDED **. Manual: fresh tour, after tapping Start on the welcome sheet, a popover should appear anchored to the `+` button.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/views/collections/CollectionsView.swift"
git commit -m "feat(onboarding): MemoryTip on CollectionsView + button"
```

---

## Task 11 — `popoverTip(TicketTip())` on `MemoryDetailView` "new ticket" button

**Files:**
- Modify: `Lumoria App/views/collections/CollectionDetailView.swift`

The "new ticket" entry on `MemoryDetailView` is inside a `LumoriaIconButton` menu (see line 166 area). The tip anchor should be the icon button itself so the popover points at the right element.

- [ ] **Step 1: Import TipKit**

```swift
import TipKit
```

- [ ] **Step 2: Attach the tip**

Find the `LumoriaIconButton` that owns the "New ticket…" menu item (around line 148–166). Attach `.popoverTip(TicketTip())` to that button:

```swift
    LumoriaIconButton(
        systemImage: "plus",
        menu: [
            .init(title: "New ticket…") { showNewTicket = true },
            .init(title: "Add existing ticket…") { ... }
        ]
    )
    .popoverTip(TicketTip())
```

Exact prop shape will match the existing call — copy the current invocation, only add the `.popoverTip` modifier.

- [ ] **Step 3: Build**

```bash
xcodebuild -project "Lumoria App.xcodeproj" -scheme "Lumoria App" \
  -destination "platform=iOS Simulator,name=iPhone 17" build
```

Expected: ** BUILD SUCCEEDED **. Manual: after memory creation during the tour, the popover should appear on the detail view's add button.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/views/collections/CollectionDetailView.swift"
git commit -m "feat(onboarding): TicketTip on MemoryDetailView + button"
```

---

## Task 12 — `popoverTip(ExportTip())` + donations on `SuccessStep`

**Files:**
- Modify: `Lumoria App/views/tickets/new/SuccessStep.swift`

- [ ] **Step 1: Import TipKit + read the coordinator from env**

```swift
import TipKit
```

In the `NewTicketSuccessStep` struct, after existing `@EnvironmentObject` declarations:

```swift
    @EnvironmentObject private var onboardingCoordinator: OnboardingCoordinator
```

- [ ] **Step 2: Donate ticket-created on appear**

On the outer `VStack` of `body`, chain `.onAppear`:

```swift
    .onAppear {
        onboardingCoordinator.donateTicketCreated()
    }
```

(If the coordinator isn't in a tour, `donateTicketCreated` no-ops.)

- [ ] **Step 3: Attach the popover tip to the Export button**

Find the `Button("Export Ticket") { showExport = true }` at line 212. Change to:

```swift
    Button("Export Ticket") {
        showExport = true
        onboardingCoordinator.donateExportOpened()
    }
    .popoverTip(ExportTip())
```

- [ ] **Step 4: Verify `NewTicketFunnelView` passes the coordinator into the `fullScreenCover`**

The funnel is presented via `fullScreenCover` from `ContentView` (for wallet imports) and from `MemoriesView`/`CollectionsView` (for normal creation). `SuccessStep` reads `onboardingCoordinator` from env — verify the presenting views inject it. If any presenter omits `.environmentObject(onboardingCoordinator)`, add it. Search for `NewTicketFunnelView(` and audit each call site.

```bash
grep -n "NewTicketFunnelView(" "Lumoria App"/ -r
```

For each hit, confirm the surrounding view chain passes the coordinator.

- [ ] **Step 5: Build**

```bash
xcodebuild -project "Lumoria App.xcodeproj" -scheme "Lumoria App" \
  -destination "platform=iOS Simulator,name=iPhone 17" build
```

Expected: ** BUILD SUCCEEDED **. Manual: complete the tour ticket → on the success step, the popover appears on the Export button. Tapping Export opens the sheet and marks onboarding complete.

- [ ] **Step 6: Commit**

```bash
git add "Lumoria App/views/tickets/new/SuccessStep.swift" \
        "Lumoria App/views/tickets/new/NewTicketFunnelView.swift"
# plus any other presenter files that were edited in step 4
git commit -m "feat(onboarding): ExportTip + donations on SuccessStep"
```

---

## Task 13 — "Replay onboarding" row in Settings

**Files:**
- Modify: `Lumoria App/views/settings/SettingsView.swift`

- [ ] **Step 1: Read the coordinator from env**

Add at the top of `SettingsView`:

```swift
    @EnvironmentObject private var onboardingCoordinator: OnboardingCoordinator
```

- [ ] **Step 2: Add the row**

Identify the right section (existing patterns in `SettingsView.swift` — probably near Help or a general "About" section). Add a row:

```swift
    Button {
        onboardingCoordinator.reset()
    } label: {
        HStack {
            Text("onboarding.settings.replay")
            Spacer()
            Image(systemName: "arrow.counterclockwise")
                .foregroundStyle(Color.Text.secondary)
        }
    }
    .foregroundStyle(Color.Text.primary)
```

Match the row styling used by neighboring rows (e.g. if the file uses a custom `SettingsRow` helper, use that instead).

- [ ] **Step 3: Build + manual check**

```bash
xcodebuild -project "Lumoria App.xcodeproj" -scheme "Lumoria App" \
  -destination "platform=iOS Simulator,name=iPhone 17" build
```

Manual: finish onboarding → go to Settings → tap "Replay onboarding" → the welcome sheet reappears; tips re-fire on the next memory/ticket/export.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/views/settings/SettingsView.swift"
git commit -m "feat(onboarding): Replay onboarding row in Settings"
```

---

## Task 14 — Full manual QA pass

**Files:** none (verification only).

- [ ] **Step 1: Reset simulator + fresh signup happy path**

In Simulator: Device → Erase All Content and Settings. Launch the app. Sign up with a new email. Expected sequence:

1. Welcome sheet appears.
2. Tap **Start** → sheet dismisses → popover on Memories `+` button.
3. Tap `+` → create a memory ("Paris 2026", any color/emoji). → memory detail view auto-pushes. → popover on `+` button in detail view.
4. Tap the detail `+` → "New ticket…" → complete the funnel (pick any category/template/style). Land on Success step. → popover on "Export Ticket" button.
5. Tap Export → ExportSheet opens. Onboarding complete; no more popovers.

Verify no popover re-appears on relaunch.

- [ ] **Step 2: Skip path**

Erase simulator, fresh signup. On welcome sheet, tap **Skip**. Verify:

- Sheet dismisses.
- No popover appears on the `+` button in Memories.
- Creating a memory doesn't trigger any popover.

- [ ] **Step 3: Returning-user gate**

Erase simulator, fresh signup. In the app, create a memory directly (no welcome path — would need to set `welcomeSeen = true` without `completed` flag; easier to verify with an existing account). Sign out, sign back in. On return: no welcome sheet (coordinator should silently mark `completed = true` because memories > 0).

- [ ] **Step 4: Replay from Settings**

After completing the tour in Step 1, go to Settings → "Replay onboarding". Verify:

- Welcome sheet reappears.
- Popovers re-fire on each step as before.
- `Onboarding Replayed` analytics event fired.

- [ ] **Step 5: Analytics verification**

In Amplitude (or debug console if events are logged locally), verify the following fire during the happy path:

- `Onboarding Shown` (x1)
- `Onboarding Started` (x1)
- `Onboarding Step Completed` step=memory
- `Onboarding Step Completed` step=ticket
- `Onboarding Step Completed` step=export
- `Onboarding Completed` with `duration_seconds` > 0

And during skip:
- `Onboarding Shown` (x1)
- `Onboarding Skipped` step=welcome

- [ ] **Step 6: Add Notion Events DB rows**

Per `AnalyticsEvent.swift` header comment: each new case needs a row in the Notion Events DB. Add the 6 new events there.

- [ ] **Step 7: Final commit — none needed**

All work should already be committed. Close the ticket.

---

## Self-Review

**Spec coverage check:**

| Spec item | Covered by |
|-----------|-----------|
| OnboardingCoordinator (state + events + reset) | Task 4 |
| Three Tip structs with rules | Task 3 |
| Welcome sheet (option A visuals + copy) | Tasks 5, 6 |
| Tips.configure in app bootstrap | Task 7 |
| ContentView eligibility + sheet + auto-push | Tasks 9, 9b |
| MemoriesStore coordinator wiring | Task 8 |
| CollectionsView MemoryTip | Task 10 |
| MemoryDetailView TicketTip | Task 11 |
| SuccessStep ExportTip + donations | Task 12 |
| SettingsView Replay row | Task 13 |
| Analytics events + props | Tasks 1, 2 |
| Localization keys | Task 5 |
| Manual QA including analytics + Notion DB | Task 14 |

**Placeholder scan:** no TBD / TODO / "implement later" patterns in this plan. Edge cases where exact existing code is unknown (`Color.Text.*` token names, `LumoriaIconButton` menu shape) include explicit fallback guidance rather than placeholders.

**Type consistency:**

- `OnboardingCoordinator` is `ObservableObject` throughout (spec + plan + tests).
- `evaluateEligibility(memoriesCount:ticketsCount:)` signature identical across Tasks 4, 9, test suite.
- `donateMemoryCreated(_ memory: Memory)` matches Memory type in `views/collections/Collection.swift`.
- `OnboardingStepProp` raw values are lowercase (`welcome`, `memory`, `ticket`, `export`) — tests assert this in Task 2.
- `Tips.Event` instances on `OnboardingEvents` — referenced identically in `OnboardingTips.swift` and `OnboardingCoordinator.swift`.

Plan is ready for execution.
