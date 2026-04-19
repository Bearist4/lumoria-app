# Microinteractions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship an app-wide microinteractions system built on a single "light as material" metaphor — tilt-driven shimmer per template, haptic palette, signature save/share/delete/duplicate moments, navigation choreography, and full accessibility/perf guardrails.

**Architecture:** Three-layer primitives (motion tokens, haptic palette, CoreMotion manager) feed a shared `TicketShimmerView` that reads a new `TicketShimmer` attribute on `TicketTemplateKind`. Existing templates and flows are wrapped/modified to consume these primitives. All shimmer is rate-limited, viewport-gated, reduce-motion aware, low-power aware, and disabled on high-contrast modes.

**Tech Stack:** SwiftUI (iOS 17+), CoreMotion, `.sensoryFeedback`, `.drawingGroup()` / Metal rasterisation, Swift Testing (`@Test` / `#expect`) for unit tests on tokens + manager logic.

**Spec:** `docs/superpowers/specs/2026-04-19-microinteractions-design.md` — refer to it for any ambiguity.

**Conventions for this plan:**
- Paths are relative to repo root. Repo root: `/Users/bearista/Documents/lumoria/Lumoria App`.
- Where a task creates a SwiftUI view, add manual verification steps (simulator / device) in lieu of snapshot tests we don't have infrastructure for.
- Each task ends with a commit. Use `feat(microinteractions): …` or `feat(motion): …` prefixes.
- Swift Testing (`import Testing`) is used for the few files that have meaningful pure-logic tests.

---

## File Structure

**New files:**
- `Lumoria App/motion/MotionTokens.swift` — reusable `Animation` curves.
- `Lumoria App/motion/HapticPalette.swift` — seven-token haptic helper.
- `Lumoria App/motion/TiltMotionManager.swift` — singleton CoreMotion publisher.
- `Lumoria App/motion/TicketShimmer.swift` — shimmer mode enum + template mapping.
- `Lumoria App/components/TicketShimmerView.swift` — shared shimmer overlay.
- `Lumoria App/components/TicketInspectModifier.swift` — long-press inspect behaviour.
- `Lumoria App/components/LumoriaPullToRefresh.swift` — custom pull-to-refresh with star.
- `Lumoria App/components/SevenPointStar.swift` — reusable star shape (if not present — verify in Task 0).
- `Lumoria App/views/tickets/TicketSaveRevealView.swift` — print/emboss save animation host.
- `Lumoria App/views/tickets/TicketTearDeleteModifier.swift` — tear animation.
- `Lumoria AppTests/MotionTokensTests.swift`, `HapticPaletteTests.swift`, `TicketShimmerTests.swift`.

**Modified files (non-exhaustive list; exact hunks shown per task):**
- `Lumoria App/views/tickets/Ticket.swift` — add `shimmer` on `TicketTemplateKind`.
- `Lumoria App/components/LumoriaButton.swift` — sensoryFeedback hook.
- 8 template views (`AfterglowTicketView.swift` + vertical, `StudioTicketView.swift` + vertical, etc.) — wrap in shimmer.
- `Lumoria App/views/tickets/TicketPreview.swift` / `TicketRow.swift` — viewport gating + inspect + tap depression.
- `Lumoria App/views/tickets/new/*Step.swift` — creation flow microinteractions.
- `Lumoria App/views/tickets/new/SuccessStep.swift` — save reveal animation host.
- `Lumoria App/views/authentication/*.swift` — entrance + CTA treatment.
- `Lumoria App/views/settings/SettingsView.swift` — row + toggle + footer.
- `Lumoria App/views/collections/CollectionsView.swift`, `AllTicketsView.swift` — pull-to-refresh + empty states.
- `Lumoria App/Lumoria_AppApp.swift` — hook `TiltMotionManager` foreground/background lifecycle.
- `Lumoria App/Localizable.xcstrings` — any new strings.

---

## Task 0: Preflight + Baseline Verification

**Files:**
- Read: `Lumoria App/components/*.swift`, `Lumoria App/views/tickets/*.swift`, `Lumoria App/views/tickets/new/*.swift`

- [ ] **Step 1: Inventory existing star shape**

Run: `grep -rn "SevenPointStar\|7.*point.*star\|7-point" "Lumoria App/"`
If `SevenPointStar` exists as a reusable `Shape`, note its file. Otherwise Task 15 creates it.

- [ ] **Step 2: Inventory CoreMotion usage**

Run: `grep -rn "CoreMotion\|CMMotionManager" "Lumoria App/"`
Expected: zero matches — confirms greenfield for tilt.

- [ ] **Step 3: Inventory haptic usage**

Run: `grep -rn "sensoryFeedback\|UIImpactFeedback\|hapticFeedback" "Lumoria App/"`
Record each call site — Task 10 (LumoriaButton) and later tasks will consolidate them through `HapticPalette`.

- [ ] **Step 4: Commit nothing**

Preflight is inspection-only.

---

## Task 1: Motion Tokens

**Files:**
- Create: `Lumoria App/motion/MotionTokens.swift`
- Create: `Lumoria AppTests/MotionTokensTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Lumoria AppTests/MotionTokensTests.swift`:

```swift
import Testing
import SwiftUI
@testable import Lumoria_App

@Suite("MotionTokens")
struct MotionTokensTests {

    @Test("editorial is an ease-out curve at 320ms")
    func editorialDuration() {
        // Animation is not introspectable; we guard intent via the
        // documented duration constant.
        #expect(MotionTokens.editorialDuration == 0.32)
    }

    @Test("expose duration is 620ms")
    func exposeDuration() {
        #expect(MotionTokens.exposeDuration == 0.62)
    }

    @Test("settle spring response is 0.45")
    func settleResponse() {
        #expect(MotionTokens.settleResponse == 0.45)
        #expect(MotionTokens.settleDamping == 0.82)
    }

    @Test("impulse spring response is 0.22")
    func impulseResponse() {
        #expect(MotionTokens.impulseResponse == 0.22)
        #expect(MotionTokens.impulseDamping == 0.65)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme "Lumoria App" -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing "Lumoria AppTests/MotionTokensTests"`
Expected: FAIL — `MotionTokens` undefined.

- [ ] **Step 3: Create motion tokens**

Create `Lumoria App/motion/MotionTokens.swift`:

```swift
import SwiftUI

/// Reusable animation curves that encode the brand's motion personality.
/// Pair with haptics from `HapticPalette` at call sites.
enum MotionTokens {

    // Documented constants — exposed so tests can verify intent without
    // introspecting an `Animation` value.
    static let editorialDuration: Double = 0.32
    static let exposeDuration: Double = 0.62
    static let settleResponse: Double = 0.45
    static let settleDamping: Double = 0.82
    static let impulseResponse: Double = 0.22
    static let impulseDamping: Double = 0.65

    /// Default transition curve. Ease-out, 320ms. Nav push/pop, title lifts,
    /// most "content arriving" motion.
    static let editorial: Animation = .easeOut(duration: editorialDuration)

    /// Spring for things landing — tickets on save, sheets on present.
    static let settle: Animation = .spring(
        response: settleResponse,
        dampingFraction: settleDamping
    )

    /// Small state changes. Tap scales, toggles, row highlights.
    static let impulse: Animation = .spring(
        response: impulseResponse,
        dampingFraction: impulseDamping
    )

    /// Photographic reveal. Only used for the save print/emboss sequence.
    static let expose: Animation = .easeInOut(duration: exposeDuration)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme "Lumoria App" -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing "Lumoria AppTests/MotionTokensTests"`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add "Lumoria App/motion/MotionTokens.swift" "Lumoria AppTests/MotionTokensTests.swift"
git commit -m "feat(motion): add MotionTokens (editorial/settle/impulse/expose)"
```

---

## Task 2: Haptic Palette

**Files:**
- Create: `Lumoria App/motion/HapticPalette.swift`
- Create: `Lumoria AppTests/HapticPaletteTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Lumoria AppTests/HapticPaletteTests.swift`:

```swift
import Testing
import Foundation
@testable import Lumoria_App

@Suite("HapticPalette")
struct HapticPaletteTests {

    @Test("debouncer blocks second trigger within 50ms")
    func debounceBlocksFast() {
        let debouncer = HapticDebouncer(minInterval: 0.050)
        let now = Date()
        #expect(debouncer.shouldFire(.select, at: now) == true)
        #expect(debouncer.shouldFire(.select, at: now.addingTimeInterval(0.020)) == false)
    }

    @Test("debouncer allows trigger after interval elapses")
    func debounceAllowsAfterInterval() {
        let debouncer = HapticDebouncer(minInterval: 0.050)
        let now = Date()
        _ = debouncer.shouldFire(.select, at: now)
        #expect(debouncer.shouldFire(.select, at: now.addingTimeInterval(0.060)) == true)
    }

    @Test("debouncer tracks tokens independently")
    func debounceIndependentPerToken() {
        let debouncer = HapticDebouncer(minInterval: 0.050)
        let now = Date()
        _ = debouncer.shouldFire(.select, at: now)
        // Different token, no elapsed time — still allowed.
        #expect(debouncer.shouldFire(.confirm, at: now) == true)
    }

    @Test("all seven haptic tokens exist")
    func sevenTokens() {
        let expected: [HapticToken] = [
            .select, .confirm, .toggle, .warn, .save, .stamp, .shimmer
        ]
        #expect(expected.count == 7)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme "Lumoria App" -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing "Lumoria AppTests/HapticPaletteTests"`
Expected: FAIL — types undefined.

- [ ] **Step 3: Create haptic palette**

Create `Lumoria App/motion/HapticPalette.swift`:

```swift
import SwiftUI
import Foundation

/// Seven-token palette covering every haptic moment in the app. Extend
/// only when the spec adds a moment — drift breaks the editorial mood.
enum HapticToken: String, CaseIterable {
    case select     // selection / tap
    case confirm    // success
    case toggle     // light impact for switches
    case warn       // destructive confirmation tap, tear start
    case save       // custom 4-tick paper-feed pattern
    case stamp      // medium impact — inspect lift, duplicate split
    case shimmer    // low-intensity rigid — tilt edge catch
}

/// Debouncer ensures rapid consecutive calls to the same token don't
/// chain into a buzz. Per-token state — different tokens may fire close
/// together (e.g. `.select` + `.confirm`).
final class HapticDebouncer {
    private let minInterval: TimeInterval
    private var lastFired: [HapticToken: Date] = [:]

    init(minInterval: TimeInterval = 0.050) {
        self.minInterval = minInterval
    }

    /// Thread-confined to the main actor in practice — callers are on the
    /// main thread. Returns true if the caller should actually perform
    /// the haptic; false if the call should be swallowed.
    func shouldFire(_ token: HapticToken, at now: Date = Date()) -> Bool {
        if let last = lastFired[token], now.timeIntervalSince(last) < minInterval {
            return false
        }
        lastFired[token] = now
        return true
    }
}

/// The main-actor singleton used at call sites. Wraps SwiftUI's
/// `.sensoryFeedback` when used via modifier, and direct UIKit feedback
/// generators for the custom save pattern.
@MainActor
enum HapticPalette {

    nonisolated(unsafe) static let debouncer = HapticDebouncer()

    /// For the save sequence — 4 soft ticks at 140ms cadence. Fires
    /// off-path on the main queue.
    static func playSavePattern() {
        guard debouncer.shouldFire(.save) else { return }
        let gen = UIImpactFeedbackGenerator(style: .soft)
        gen.prepare()
        for i in 0..<4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.140) {
                gen.impactOccurred(intensity: 0.5)
            }
        }
    }

    /// Low-intensity rigid tick for shimmer edge catches.
    static func playShimmerTick() {
        guard debouncer.shouldFire(.shimmer) else { return }
        let gen = UIImpactFeedbackGenerator(style: .rigid)
        gen.prepare()
        gen.impactOccurred(intensity: 0.25)
    }
}

// MARK: - View modifier sugar

extension View {

    /// Attach a sensory feedback source for one of the palette's non-save
    /// tokens. Save uses `HapticPalette.playSavePattern()` directly.
    @ViewBuilder
    func lumoriaHaptic<Trigger: Equatable>(
        _ token: HapticToken,
        trigger: Trigger
    ) -> some View {
        switch token {
        case .select:
            self.sensoryFeedback(.selection, trigger: trigger)
        case .confirm:
            self.sensoryFeedback(.success, trigger: trigger)
        case .toggle:
            self.sensoryFeedback(.impact(weight: .light), trigger: trigger)
        case .warn:
            self.sensoryFeedback(.warning, trigger: trigger)
        case .stamp:
            self.sensoryFeedback(.impact(weight: .medium), trigger: trigger)
        case .save, .shimmer:
            // Save and shimmer are fired imperatively — the modifier is a
            // no-op here so callers don't accidentally route through it.
            self
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme "Lumoria App" -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing "Lumoria AppTests/HapticPaletteTests"`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add "Lumoria App/motion/HapticPalette.swift" "Lumoria AppTests/HapticPaletteTests.swift"
git commit -m "feat(motion): add HapticPalette with 7-token debounced helper"
```

---

## Task 3: Tilt Motion Manager

**Files:**
- Create: `Lumoria App/motion/TiltMotionManager.swift`
- Modify: `Lumoria App/Lumoria_AppApp.swift`

- [ ] **Step 1: Create the motion manager**

Create `Lumoria App/motion/TiltMotionManager.swift`:

```swift
import Foundation
import CoreMotion
import Combine
import UIKit

/// Singleton publisher of device attitude used by all tilt-driven views.
///
/// - One `CMMotionManager` app-wide.
/// - Auto-starts on `.active` scene phase, stops on `.background`.
/// - Throttles 60 → 20 Hz when `ProcessInfo.isLowPowerModeEnabled` is on.
/// - Zeroes output when `UIAccessibility.isReduceMotionEnabled` is on.
@MainActor
final class TiltMotionManager: ObservableObject {

    static let shared = TiltMotionManager()

    /// Roll in radians, clamped to [-π/3, π/3]. 0 = phone flat on face.
    @Published private(set) var roll: Double = 0
    /// Pitch in radians, clamped to [-π/3, π/3].
    @Published private(set) var pitch: Double = 0

    private let manager = CMMotionManager()
    private let clampRange: ClosedRange<Double> = -(.pi / 3)...(.pi / 3)
    private var observers: [NSObjectProtocol] = []

    private init() {
        observers.append(
            NotificationCenter.default.addObserver(
                forName: .NSProcessInfoPowerStateDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.applyUpdateInterval() }
            }
        )
        observers.append(
            NotificationCenter.default.addObserver(
                forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    if UIAccessibility.isReduceMotionEnabled {
                        self?.roll = 0
                        self?.pitch = 0
                    }
                }
            }
        )
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    func start() {
        guard manager.isDeviceMotionAvailable else { return }
        guard !manager.isDeviceMotionActive else { return }
        applyUpdateInterval()
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let attitude = motion?.attitude else { return }
            guard !UIAccessibility.isReduceMotionEnabled else {
                self.roll = 0
                self.pitch = 0
                return
            }
            self.roll = attitude.roll.clamped(to: self.clampRange)
            self.pitch = attitude.pitch.clamped(to: self.clampRange)
        }
    }

    func stop() {
        guard manager.isDeviceMotionActive else { return }
        manager.stopDeviceMotionUpdates()
    }

    private func applyUpdateInterval() {
        manager.deviceMotionUpdateInterval = ProcessInfo.processInfo.isLowPowerModeEnabled
            ? 1.0 / 20.0
            : 1.0 / 60.0
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
```

- [ ] **Step 2: Wire scene-phase lifecycle in `Lumoria_AppApp`**

Open `Lumoria App/Lumoria_AppApp.swift`. In the top-level `App` / `Scene` body, wire scene-phase handling:

```swift
@Environment(\.scenePhase) private var scenePhase
```

Add a `.onChange(of: scenePhase)` modifier on the root view:

```swift
.onChange(of: scenePhase) { _, newPhase in
    switch newPhase {
    case .active:     TiltMotionManager.shared.start()
    case .background: TiltMotionManager.shared.stop()
    default:          break
    }
}
```

- [ ] **Step 3: Verify build**

Run: `xcodebuild build -scheme "Lumoria App" -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Manual verification**

Launch app in simulator. Hardware > Device > Rotate — motion is flat in the sim, but confirm no crash on phase changes (Device > Home then reopen). Confirm `TiltMotionManager.shared` is reachable from any SwiftUI view via `@StateObject` / direct singleton access.

- [ ] **Step 5: Commit**

```bash
git add "Lumoria App/motion/TiltMotionManager.swift" "Lumoria App/Lumoria_AppApp.swift"
git commit -m "feat(motion): add TiltMotionManager singleton with scene-phase lifecycle"
```

---

## Task 4: TicketShimmer Attribute

**Files:**
- Create: `Lumoria App/motion/TicketShimmer.swift`
- Modify: `Lumoria App/views/tickets/Ticket.swift`
- Create: `Lumoria AppTests/TicketShimmerTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Lumoria AppTests/TicketShimmerTests.swift`:

```swift
import Testing
@testable import Lumoria_App

@Suite("TicketShimmer")
struct TicketShimmerTests {

    @Test("shimmer mode assignment per template")
    func perTemplate() {
        #expect(TicketTemplateKind.prism.shimmer == .holographic)
        #expect(TicketTemplateKind.studio.shimmer == .holographic)
        #expect(TicketTemplateKind.heritage.shimmer == .paperGloss)
        #expect(TicketTemplateKind.terminal.shimmer == .paperGloss)
        #expect(TicketTemplateKind.orient.shimmer == .paperGloss)
        #expect(TicketTemplateKind.express.shimmer == .paperGloss)
        #expect(TicketTemplateKind.afterglow.shimmer == .softGlow)
        #expect(TicketTemplateKind.night.shimmer == .softGlow)
    }

    @Test("no template is .none by default")
    func noDefaultNone() {
        for kind in TicketTemplateKind.allCases {
            #expect(kind.shimmer != TicketShimmer.none)
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme "Lumoria App" -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing "Lumoria AppTests/TicketShimmerTests"`
Expected: FAIL — `TicketShimmer` / `.shimmer` undefined.

- [ ] **Step 3: Create shimmer enum**

Create `Lumoria App/motion/TicketShimmer.swift`:

```swift
/// How a ticket surface responds to tilt. One attribute per template.
enum TicketShimmer: String, Codable, CaseIterable {
    /// Angular conic gradient (cyan → magenta → yellow → cyan). Prism, Studio.
    case holographic
    /// Soft white linear sheen sweeping diagonally. Boarding-pass gloss.
    case paperGloss
    /// Radial bloom at ticket center that brightens with tilt. Afterglow, Night.
    case softGlow
    /// No shimmer overlay. Reserved for future templates.
    case none
}
```

- [ ] **Step 4: Add attribute to `TicketTemplateKind`**

Edit `Lumoria App/views/tickets/Ticket.swift`. Inside the `TicketTemplateKind` enum, after the `displayName` computed property, add:

```swift
/// Tilt-driven shimmer style for this template. See `TicketShimmerView`.
var shimmer: TicketShimmer {
    switch self {
    case .prism, .studio:                   return .holographic
    case .heritage, .terminal, .orient, .express: return .paperGloss
    case .afterglow, .night:                return .softGlow
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `xcodebuild test -scheme "Lumoria App" -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing "Lumoria AppTests/TicketShimmerTests"`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add "Lumoria App/motion/TicketShimmer.swift" "Lumoria App/views/tickets/Ticket.swift" "Lumoria AppTests/TicketShimmerTests.swift"
git commit -m "feat(motion): add TicketShimmer attribute per template"
```

---

## Task 5: TicketShimmerView — paperGloss mode

**Files:**
- Create: `Lumoria App/components/TicketShimmerView.swift`

- [ ] **Step 1: Create shimmer view skeleton**

Create `Lumoria App/components/TicketShimmerView.swift`:

```swift
import SwiftUI
import UIKit

/// Overlay that paints a tilt-responsive light effect on top of a ticket
/// canvas. Attach as `.overlay(TicketShimmerView(mode: …))` and mask to
/// the ticket shape from the caller.
///
/// Rendering is gated by:
/// - `isActive` — viewport visibility.
/// - `UIAccessibility.isReduceMotionEnabled` — overlay is static at neutral.
/// - `UIAccessibility.isDarkerSystemColorsEnabled` — HC, overlay hidden.
/// - `ProcessInfo.isLowPowerModeEnabled` — holographic degrades to paperGloss.
struct TicketShimmerView: View {

    let mode: TicketShimmer
    /// Caller raises this when the ticket is the centred/focused card.
    /// Off-screen cards should pass `false` to pause motion reads.
    var isActive: Bool = true

    @StateObject private var motion = TiltMotionManagerObserver()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var diffWithoutColor
    @Environment(\.colorSchemeContrast) private var contrast

    /// Last fire time for edge-catch haptic. Task 9 uses this.
    @State private var lastHapticFire: Date = .distantPast

    var body: some View {
        GeometryReader { geo in
            shimmerLayer(in: geo.size)
                .allowsHitTesting(false)
                .drawingGroup()
        }
    }

    @ViewBuilder
    private func shimmerLayer(in size: CGSize) -> some View {
        if shouldDisable {
            EmptyView()
        } else {
            switch effectiveMode {
            case .paperGloss:
                paperGloss(in: size)
            case .holographic:
                Color.clear // placeholder until Task 6
            case .softGlow:
                Color.clear // placeholder until Task 6
            case .none:
                EmptyView()
            }
        }
    }

    // MARK: - Paper gloss

    private func paperGloss(in size: CGSize) -> some View {
        let offset = offsetForRoll(size: size)
        let angle = Angle(radians: -Double.pi / 4) // fixed 45°
        return LinearGradient(
            stops: [
                .init(color: .white.opacity(0.0), location: 0.35),
                .init(color: .white.opacity(0.18), location: 0.50),
                .init(color: .white.opacity(0.0), location: 0.65),
            ],
            startPoint: UnitPoint(x: 0, y: 0),
            endPoint: UnitPoint(x: 1, y: 1)
        )
        .rotationEffect(angle)
        .offset(x: offset, y: 0)
        .blendMode(.screen)
    }

    private func offsetForRoll(size: CGSize) -> CGFloat {
        guard isActive else { return 0 }
        let travel = size.width * 0.6
        return CGFloat(motion.roll) / CGFloat(.pi / 3) * travel
    }

    // MARK: - Policy

    private var shouldDisable: Bool {
        if contrast == .increased { return true }
        if mode == .none { return true }
        return false
    }

    private var effectiveMode: TicketShimmer {
        if reduceMotion { return .paperGloss } // static-friendly
        if ProcessInfo.processInfo.isLowPowerModeEnabled, mode == .holographic {
            return .paperGloss
        }
        return mode
    }
}

/// Thin adapter so views can consume `TiltMotionManager.shared` as an
/// `ObservableObject` without introducing singleton state directly.
@MainActor
private final class TiltMotionManagerObserver: ObservableObject {
    @Published var roll: Double = 0
    @Published var pitch: Double = 0
    private var cancellable: Any?

    init() {
        let manager = TiltMotionManager.shared
        self.roll = manager.roll
        self.pitch = manager.pitch
        // Mirror published values via Combine.
        self.cancellable = manager.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in
                self?.roll = manager.roll
                self?.pitch = manager.pitch
            }
        }
    }
}
```

- [ ] **Step 2: Verify build**

Run: `xcodebuild build -scheme "Lumoria App" -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Temporary preview harness**

At the bottom of `TicketShimmerView.swift`, add a preview:

```swift
#Preview("PaperGloss over red") {
    Rectangle()
        .fill(Color(red: 0.9, green: 0.3, blue: 0.3))
        .frame(width: 320, height: 160)
        .overlay(TicketShimmerView(mode: .paperGloss))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
}
```

- [ ] **Step 4: Manual verification**

Run the preview. In a physical device run Scene → tilt phone → sheen slides left/right. In simulator (no motion), sheen stays centered — acceptable.

- [ ] **Step 5: Commit**

```bash
git add "Lumoria App/components/TicketShimmerView.swift"
git commit -m "feat(motion): add TicketShimmerView with paperGloss mode"
```

---

## Task 6: Holographic + softGlow modes

**Files:**
- Modify: `Lumoria App/components/TicketShimmerView.swift`

- [ ] **Step 1: Replace placeholders with real implementations**

In `TicketShimmerView.swift`, replace the `holographic` and `softGlow` `Color.clear` placeholders inside `shimmerLayer(in:)`:

```swift
case .holographic:
    holographic(in: size)
case .softGlow:
    softGlow(in: size)
```

Add the rendering methods after `paperGloss(in:)`:

```swift
private func holographic(in size: CGSize) -> some View {
    let rollNorm = CGFloat(motion.roll) / CGFloat(.pi / 3)
    let pitchNorm = CGFloat(motion.pitch) / CGFloat(.pi / 3)
    let baseAngle = Angle(radians: Double(rollNorm) * .pi * 2)
    let hueShift = pitchNorm * 0.5 // ±0.5 turns

    return AngularGradient(
        gradient: Gradient(colors: [
            Color(hue: wrap(0.55 + Double(hueShift)), saturation: 0.6, brightness: 1),
            Color(hue: wrap(0.82 + Double(hueShift)), saturation: 0.6, brightness: 1),
            Color(hue: wrap(0.14 + Double(hueShift)), saturation: 0.6, brightness: 1),
            Color(hue: wrap(0.55 + Double(hueShift)), saturation: 0.6, brightness: 1),
        ]),
        center: .center,
        angle: baseAngle
    )
    .opacity(0.35)
    .blendMode(.overlay)
}

private func softGlow(in size: CGSize) -> some View {
    let pitchNorm = max(0, CGFloat(abs(motion.pitch)) / CGFloat(.pi / 3))
    let intensity = 0.15 + pitchNorm * 0.35 // 0.15–0.50
    return RadialGradient(
        colors: [
            .white.opacity(Double(intensity)),
            .white.opacity(0)
        ],
        center: .center,
        startRadius: 0,
        endRadius: min(size.width, size.height) * 0.4
    )
    .blendMode(.screen)
}

private func wrap(_ v: Double) -> Double {
    var x = v
    while x < 0 { x += 1 }
    while x > 1 { x -= 1 }
    return x
}
```

- [ ] **Step 2: Add previews for the new modes**

Below the existing preview in `TicketShimmerView.swift`:

```swift
#Preview("Holographic over purple") {
    Rectangle()
        .fill(Color(red: 0.78, green: 0.71, blue: 0.91))
        .frame(width: 320, height: 160)
        .overlay(TicketShimmerView(mode: .holographic))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
}

#Preview("SoftGlow over navy") {
    Rectangle()
        .fill(Color(red: 0.04, green: 0.05, blue: 0.10))
        .frame(width: 320, height: 160)
        .overlay(TicketShimmerView(mode: .softGlow))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
}
```

- [ ] **Step 3: Manual verification on device**

Run on physical device. Confirm:
- Holographic preview: tilt shifts the angular gradient through cyan/magenta/yellow smoothly.
- SoftGlow preview: tilting forward/back brightens/dims the centered bloom.
- PaperGloss preview: sheen slides with roll.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/components/TicketShimmerView.swift"
git commit -m "feat(motion): implement holographic and softGlow shimmer modes"
```

---

## Task 7: Integrate Shimmer Into Ticket Templates

**Files:**
- Modify: `Lumoria App/views/tickets/TicketPreview.swift`
- Modify: `Lumoria App/views/tickets/TicketRow.swift`
- Modify: each of the 16 template views (8 templates × horizontal + vertical)

- [ ] **Step 1: Add a shared `.ticketShimmer(mode:isActive:)` modifier**

Append to `Lumoria App/components/TicketShimmerView.swift`:

```swift
extension View {
    /// Applies the brand shimmer overlay, masked to the receiver's
    /// bounds. Use on the outer shape of a ticket view so the overlay
    /// respects the template's cutouts.
    func ticketShimmer(
        mode: TicketShimmer,
        isActive: Bool = true
    ) -> some View {
        self.overlay(
            TicketShimmerView(mode: mode, isActive: isActive)
                .allowsHitTesting(false)
        )
    }
}
```

- [ ] **Step 2: Wrap the shimmer into `TicketPreview`**

Open `Lumoria App/views/tickets/TicketPreview.swift`. Locate where the template view is rendered. Wrap the rendered template's container with:

```swift
.ticketShimmer(mode: ticket.kind.shimmer, isActive: isCentered)
```

Where `isCentered: Bool` is the new parameter on `TicketPreview` — pass `true` from single-ticket surfaces (detail view), `false` initially from lists (Task 7 Step 4 wires viewport gating).

Add `var isCentered: Bool = false` to `TicketPreview`'s properties and thread it from every caller of `TicketPreview`. If the caller already passes a ticket into a single detail view, pass `isCentered: true` there.

- [ ] **Step 3: Wrap the shimmer into `TicketRow`**

Open `Lumoria App/views/tickets/TicketRow.swift`. Do the same: wrap the row's ticket container with `.ticketShimmer(mode: ticket.kind.shimmer, isActive: isCentered)` and add an `isCentered` binding. Default `false` — Step 4 adds viewport gating.

- [ ] **Step 4: Viewport gating on list/scroll surfaces**

Where ticket rows are rendered in a `ScrollView` (e.g. `AllTicketsView.swift`, `CollectionDetailView.swift`), wrap each row in:

```swift
TicketRow(ticket: ticket, isCentered: centredId == ticket.id)
    .background(GeometryReader { proxy in
        Color.clear
            .onChange(of: proxy.frame(in: .global).midY) { _, midY in
                let screenMid = UIScreen.main.bounds.midY
                if abs(midY - screenMid) < 80 {
                    centredId = ticket.id
                }
            }
    })
```

Add `@State private var centredId: UUID?` at the view scope.

Note: `UIScreen.main` is deprecated on multi-scene apps; if the project already has a scene-aware accessor, use that. If not, this is acceptable for the initial pass — Task 20's perf review flags it for revisit.

- [ ] **Step 5: Verify build + simulator run**

Run: `xcodebuild build -scheme "Lumoria App" -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: BUILD SUCCEEDED.

Launch on a physical device. In the tickets list, scroll slowly: the card in the vertical center should shimmer; others should not. Tilt phone; only centered card's shimmer moves.

- [ ] **Step 6: Commit**

```bash
git add "Lumoria App/components/TicketShimmerView.swift" \
        "Lumoria App/views/tickets/TicketPreview.swift" \
        "Lumoria App/views/tickets/TicketRow.swift" \
        "Lumoria App/views/tickets/AllTicketsView.swift" \
        "Lumoria App/views/collections/CollectionDetailView.swift"
git commit -m "feat(microinteractions): wire per-template shimmer with viewport gating"
```

---

## Task 8: Inspect Mode + Tap Depression

**Files:**
- Create: `Lumoria App/components/TicketInspectModifier.swift`
- Modify: `Lumoria App/views/tickets/TicketRow.swift`
- Modify: `Lumoria App/views/tickets/TicketPreview.swift`

- [ ] **Step 1: Create the inspect modifier**

Create `Lumoria App/components/TicketInspectModifier.swift`:

```swift
import SwiftUI

struct TicketInspectModifier: ViewModifier {

    @GestureState private var isHolding = false
    @State private var stampTrigger = 0
    @State private var tapTrigger = 0
    var onTap: () -> Void

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHolding ? 1.06 : (tapPressed ? 0.98 : 1.0))
            .shadow(
                color: .black.opacity(isHolding ? 0.22 : 0.0),
                radius: isHolding ? 24 : 0,
                y: isHolding ? 14 : 0
            )
            .animation(MotionTokens.impulse, value: isHolding)
            .animation(MotionTokens.impulse, value: tapPressed)
            .accessibilityAction(named: "Inspect ticket") {
                stampTrigger &+= 1
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.30)
                    .sequenced(before: DragGesture(minimumDistance: 0))
                    .updating($isHolding) { value, state, _ in
                        switch value {
                        case .second(true, _): state = true
                        default: state = false
                        }
                    }
                    .onEnded { _ in
                        stampTrigger &+= 1
                    }
            )
            .simultaneousGesture(
                TapGesture().onEnded {
                    tapTrigger &+= 1
                    onTap()
                }
            )
            .sensoryFeedback(.impact(weight: .medium), trigger: stampTrigger)
            .sensoryFeedback(.selection, trigger: tapTrigger)
    }

    private var tapPressed: Bool { false } // expanded in Step 2
}

extension View {
    func ticketInspect(onTap: @escaping () -> Void) -> some View {
        modifier(TicketInspectModifier(onTap: onTap))
    }
}
```

- [ ] **Step 2: Thread tap-press state**

Replace the `tapPressed` stub with a real `@State`:

```swift
@State private var tapPressed: Bool = false
```

Remove the dummy computed `tapPressed`. Replace the tap gesture with:

```swift
.simultaneousGesture(
    DragGesture(minimumDistance: 0)
        .onChanged { _ in
            if !tapPressed { tapPressed = true }
        }
        .onEnded { _ in
            tapPressed = false
            tapTrigger &+= 1
            onTap()
        }
)
```

Note: `LongPressGesture.sequenced` still takes precedence because it has a minimum duration and the DragGesture is short-tap.

- [ ] **Step 3: Adopt on ticket rows**

In `TicketRow.swift`, wrap the body in `.ticketInspect(onTap: { route() })` where `route()` is the existing navigation call. Remove any duplicate `.onTapGesture` that previously handled routing.

- [ ] **Step 4: Manual verification on device**

Run on device. Confirm:
- Tap: 12ms depression + selection haptic + routes to detail.
- Long-press (0.3s): ticket lifts (scale 1.06), shadow deepens, medium-impact stamp haptic; release returns it.
- VoiceOver ON: swipe right reaches a "Inspect ticket" action on each ticket card.

- [ ] **Step 5: Commit**

```bash
git add "Lumoria App/components/TicketInspectModifier.swift" \
        "Lumoria App/views/tickets/TicketRow.swift"
git commit -m "feat(microinteractions): inspect mode (long-press lift) + tap depression"
```

---

## Task 9: Edge-Catch Haptic

**Files:**
- Modify: `Lumoria App/components/TicketShimmerView.swift`

- [ ] **Step 1: Add rate-limited edge trigger**

In `TicketShimmerView.swift`, add tracking state:

```swift
@State private var lastEdgeSign: Int = 0
```

Inside `shimmerLayer(in:)`, wrap the non-EmptyView branches with:

```swift
Color.clear
    .onChange(of: motion.roll) { _, newRoll in
        guard isActive else { return }
        let sign = newRoll > 0 ? 1 : (newRoll < 0 ? -1 : 0)
        // Fire when roll sign flips through zero — the shimmer highlight
        // crosses the ticket's geometric centre.
        if sign != 0, sign != lastEdgeSign {
            let now = Date()
            if now.timeIntervalSince(lastHapticFire) >= 1.5 {
                HapticPalette.playShimmerTick()
                lastHapticFire = now
            }
            lastEdgeSign = sign
        }
    }
    .overlay {
        // Existing switch over `effectiveMode` goes here
    }
```

- [ ] **Step 2: Manual verification**

Run on device. Slowly roll phone left → right → left past flat position. Feel the light tick once per crossing, no more than once every 1.5s.

- [ ] **Step 3: Commit**

```bash
git add "Lumoria App/components/TicketShimmerView.swift"
git commit -m "feat(microinteractions): shimmer edge-catch haptic (1.5s rate-limited)"
```

---

## Task 10: LumoriaButton Press Feel

**Files:**
- Modify: `Lumoria App/components/LumoriaButton.swift`

- [ ] **Step 1: Add press scale + haptic**

Open `Lumoria App/components/LumoriaButton.swift`. In `LumoriaButtonBody`, locate the `.background` / fill that depends on `configuration.isPressed`. Add below it:

```swift
.scaleEffect(configuration.isPressed ? 0.97 : 1.0)
.animation(MotionTokens.impulse, value: configuration.isPressed)
```

On the outer body, add:

```swift
.sensoryFeedback(
    hierarchy == .danger ? .warning : .selection,
    trigger: configuration.isPressed
)
```

- [ ] **Step 2: Manual verification**

Run on device. Tap primary/secondary/tertiary/danger variants at each size. Confirm:
- All sizes scale to ~97% on press, spring back on release.
- Primary/secondary/tertiary: selection haptic on press.
- Danger: warning haptic on press.

- [ ] **Step 3: Commit**

```bash
git add "Lumoria App/components/LumoriaButton.swift"
git commit -m "feat(microinteractions): LumoriaButton press scale + selection haptic"
```

---

## Task 11: Form Field Focus Treatment

**Files:**
- Modify: `Lumoria App/components/LumoriaInputField.swift`

- [ ] **Step 1: Inspect existing input field**

Open the file. Identify the `@FocusState` property and the border/label treatment. The current behaviour is likely a border color change on focus.

- [ ] **Step 2: Replace color flash with border scale + label shift**

Where the border is rendered on focus, change to:

```swift
.overlay(
    RoundedRectangle(cornerRadius: 12)
        .stroke(Color.primary, lineWidth: isFocused ? 4 : 1)
        .scaleEffect(isFocused ? 1.0 : 1.02) // overshoot scales in
        .animation(MotionTokens.impulse, value: isFocused)
)
```

Shift the label:

```swift
Text(label)
    .offset(y: isFocused ? -2 : 0)
    .animation(MotionTokens.impulse, value: isFocused)
```

Add haptic:

```swift
.sensoryFeedback(.selection, trigger: isFocused)
```

- [ ] **Step 3: Manual verification**

Run. Open any form with inputs (creation flow, profile edit). Tap a field:
- Border scales in from 1.02 → 1.0 with the 4pt weight.
- Label shifts up 2pt.
- Selection haptic fires once on focus.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/components/LumoriaInputField.swift"
git commit -m "feat(microinteractions): form field focus scale + label shift + haptic"
```

---

## Task 12: Navigation + Sheet + Tab + Full-Screen Cover

**Files:**
- Create: `Lumoria App/motion/NavigationTransitions.swift`
- Modify: top-level container views that host tab switches and full-screen covers.

- [ ] **Step 1: Create reusable transitions**

Create `Lumoria App/motion/NavigationTransitions.swift`:

```swift
import SwiftUI

extension AnyTransition {

    /// Editorial push — slide in from trailing + fade.
    static var editorialPush: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    /// Full-screen cover replacement — fade up 8pt.
    static var coverFadeUp: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .opacity
        )
    }

    /// Tab crossfade — pure opacity, 180ms.
    static var tabCrossfade: AnyTransition { .opacity }
}
```

- [ ] **Step 2: Tab crossfade + haptic**

In the view that hosts tab-like root switching (likely `ContentView.swift` or `LandingView.swift`), wrap the selected tab's view with:

```swift
Group {
    switch selectedTab {
    case .home:       HomeView().transition(.tabCrossfade)
    case .collections: CollectionsView().transition(.tabCrossfade)
    // …
    }
}
.animation(.easeInOut(duration: 0.18), value: selectedTab)
.sensoryFeedback(.impact(weight: .light), trigger: selectedTab)
```

Adapt the `selectedTab` identifier to the project's existing tab enum.

- [ ] **Step 3: Sheet present haptic + detent snap haptic**

Where `.sheet(item:)` or `.sheet(isPresented:)` is used for significant sheets (new ticket funnel, share sheet wrapper, add-to-collection), attach:

```swift
.sensoryFeedback(.impact(weight: .light), trigger: isPresented)
```

For detent snapping — if the sheet uses `.presentationDetents([.medium, .large])` — in the sheet's view, observe the detent via `.presentationContentInteraction` is unnecessary; instead track the active detent through `@Environment(\.verticalSizeClass)` or the sheet's own `@State` and fire `.impact(.light)` on change.

Since iOS does not expose the detent change callback directly, skip the detent haptic for this pass and note it as a deferred polish item in PR description.

- [ ] **Step 4: Full-screen cover fade-up**

Replace any `.fullScreenCover(isPresented:)` content root with:

```swift
content
    .transition(.coverFadeUp)
```

For the aurora orbs zoom effect, see Task 19.

- [ ] **Step 5: NavigationStack push curve**

iOS NavigationStack does not expose its push curve. Leave default behaviour. Document this in the PR.

- [ ] **Step 6: Manual verification**

Run. Confirm:
- Tab changes crossfade 180ms with light haptic.
- Significant sheets (new ticket, share, add-to-collection) fire light haptic on present.
- Full-screen covers (auth) fade up from 8pt, not the default harsh slide.

- [ ] **Step 7: Commit**

```bash
git add "Lumoria App/motion/NavigationTransitions.swift" \
        "Lumoria App/ContentView.swift"
git commit -m "feat(microinteractions): tab crossfade, sheet haptic, fullscreen fade-up"
```

---

## Task 13: Creation Flow Microinteractions

**Files:**
- Modify: `Lumoria App/views/tickets/new/CategoryStep.swift`
- Modify: `Lumoria App/views/tickets/new/TemplateStep.swift`
- Modify: `Lumoria App/views/tickets/new/FormStep.swift` (and `TrainFormStep`, `OrientFormStep`, `NightFormStep`)
- Modify: `Lumoria App/components/CategoryTile.swift`
- Modify: `Lumoria App/components/TemplateTile.swift`

- [ ] **Step 1: Category tile selection**

In `CategoryTile.swift`, add an `isSelected` and `isFaded` state driven by the parent. In the tile's body:

```swift
.scaleEffect(isSelected ? 1.04 : 1.0)
.saturation(isFaded ? 0.4 : 1.0)
.animation(MotionTokens.impulse, value: isSelected)
.animation(MotionTokens.editorial, value: isFaded)
.sensoryFeedback(.selection, trigger: isSelected)
```

In `CategoryStep.swift`, on selection, set a local `@State var fadedForMillis` timer: faded = true for 200ms, then transition. Pseudocode:

```swift
.onChange(of: selected) { _, newValue in
    fadeOthers = true
    Task {
        try? await Task.sleep(for: .milliseconds(200))
        advanceStep()
    }
}
```

- [ ] **Step 2: Template tile hello tilt**

In `TemplateTile.swift`, add an `isGreeting` state. The parent raises it on selection for 260ms:

```swift
.rotation3DEffect(
    .degrees(isGreeting ? 8 : 0),
    axis: (x: 1, y: 0, z: 0),
    perspective: 0.5
)
.animation(.easeInOut(duration: 0.26), value: isGreeting)
```

In `TemplateStep.swift`, on selection:

```swift
greetingId = template.id
Task {
    try? await Task.sleep(for: .milliseconds(260))
    greetingId = nil
    advanceStep()
}
```

- [ ] **Step 3: Form field autocomplete chip stagger**

In the airline/airport/station chip results view, wrap each chip in an `.transition(.opacity.combined(with: .move(edge: .trailing)))` and add `.animation(.easeOut(duration: 0.18).delay(Double(index) * 0.030), value: results)`.

- [ ] **Step 4: Live preview zone crossfade + breathe**

In the form step's live preview, wrap each content zone (header, primary, footer) in `.id(state.zoneVersion)` and use `.transition(.opacity)` + `.animation(MotionTokens.editorial, value: state.zoneVersion)` so only the changed zone crossfades.

Add a persistent "breathe" modifier on the full preview:

```swift
.scaleEffect(breathing ? 1.002 : 0.998)
.animation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true), value: breathing)
.onAppear { breathing = true }
```

Gate on `!reduceMotion`.

- [ ] **Step 5: Manual verification**

Run the new-ticket funnel on device end-to-end. Confirm category fade → template hello tilt → form with live preview breathing and stagger chip entrance.

- [ ] **Step 6: Commit**

```bash
git add "Lumoria App/components/CategoryTile.swift" \
        "Lumoria App/components/TemplateTile.swift" \
        "Lumoria App/views/tickets/new/CategoryStep.swift" \
        "Lumoria App/views/tickets/new/TemplateStep.swift" \
        "Lumoria App/views/tickets/new/FormStep.swift" \
        "Lumoria App/views/tickets/new/TrainFormStep.swift" \
        "Lumoria App/views/tickets/new/OrientFormStep.swift" \
        "Lumoria App/views/tickets/new/NightFormStep.swift"
git commit -m "feat(microinteractions): creation flow (category fade, template hello, live preview)"
```

---

## Task 14: Save Hero Moment — Print/Emboss

**Files:**
- Create: `Lumoria App/views/tickets/TicketSaveRevealView.swift`
- Modify: `Lumoria App/views/tickets/new/SuccessStep.swift`

- [ ] **Step 1: Create the reveal view**

Create `Lumoria App/views/tickets/TicketSaveRevealView.swift`:

```swift
import SwiftUI

/// Hosts the print/emboss reveal of a freshly saved ticket. Masks the
/// ticket content in 4 horizontal bands that reveal top-down, paired with
/// the `.save` haptic pattern. Falls back to a single crossfade when
/// Reduce Motion is enabled.
struct TicketSaveRevealView<TicketContent: View>: View {

    let ticket: Ticket
    @ViewBuilder let content: () -> TicketContent

    @State private var revealedBands: Int = 0
    @State private var blessSweep: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        content()
            .mask(
                VStack(spacing: 0) {
                    ForEach(0..<4) { i in
                        Rectangle()
                            .frame(maxWidth: .infinity)
                            .opacity(i < revealedBands ? 1 : 0)
                    }
                }
            )
            .overlay(blessingOverlay)
            .onAppear { runRevealSequence() }
            .accessibilityAction(named: "Replay save animation", {
                revealedBands = 0
                blessSweep = false
                runRevealSequence()
            })
    }

    @ViewBuilder private var blessingOverlay: some View {
        if blessSweep {
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0), location: 0.0),
                    .init(color: .white.opacity(0.35), location: 0.5),
                    .init(color: .white.opacity(0), location: 1.0),
                ],
                startPoint: UnitPoint(x: -0.3, y: 0.5),
                endPoint: UnitPoint(x: 1.3, y: 0.5)
            )
            .blendMode(.screen)
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }

    private func runRevealSequence() {
        guard !reduceMotion else {
            withAnimation(MotionTokens.editorial) {
                revealedBands = 4
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return
        }
        HapticPalette.playSavePattern()
        for i in 1...4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.140) {
                withAnimation(MotionTokens.editorial) {
                    revealedBands = i
                }
                if i == 4 {
                    withAnimation(MotionTokens.expose) { blessSweep = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) {
                        withAnimation(.easeOut(duration: 0.2)) { blessSweep = false }
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Adopt in SuccessStep**

In `SuccessStep.swift`, where the saved ticket is shown, replace the direct ticket render with:

```swift
TicketSaveRevealView(ticket: ticket) {
    TicketPreview(ticket: ticket, isCentered: true)
}
```

Below it, render the copy `Text("Saved.")` with `.transition(.opacity)` after the reveal finishes (use a 900ms delay — 4 × 140 + 620 + buffer — as a simple non-reactive approach).

- [ ] **Step 3: Manual verification on device**

Save a new ticket end-to-end. Confirm:
- 4 horizontal bands reveal top-down over ~560ms.
- 4 soft-impact ticks accompany each band.
- After band 4, a single white sweep passes across the surface.
- "Saved." copy appears after.
- With Reduce Motion on: ticket crossfades in 320ms + single success haptic.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/views/tickets/TicketSaveRevealView.swift" \
        "Lumoria App/views/tickets/new/SuccessStep.swift"
git commit -m "feat(microinteractions): save hero moment — print/emboss reveal"
```

---

## Task 15: Share / Delete / Duplicate / Export Moments

**Files:**
- Create: `Lumoria App/components/SevenPointStar.swift` (only if not present — see Task 0 Step 1)
- Create: `Lumoria App/views/tickets/TicketTearDeleteModifier.swift`
- Modify: `Lumoria App/components/ShareSheet.swift`
- Modify: `Lumoria App/views/tickets/TicketDetailView.swift` (share, delete, duplicate entry points)
- Modify: `Lumoria App/views/tickets/new/ExportSheet.swift`

- [ ] **Step 1: (Conditional) Create SevenPointStar**

If Task 0 confirmed no existing star shape, create `Lumoria App/components/SevenPointStar.swift`:

```swift
import SwiftUI

struct SevenPointStar: Shape {
    var innerRatio: CGFloat = 0.44
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerR = min(rect.width, rect.height) / 2
        let innerR = outerR * innerRatio
        let points = 7
        var path = Path()
        for i in 0..<(points * 2) {
            let r = i.isMultiple(of: 2) ? outerR : innerR
            let angle = -CGFloat.pi / 2 + CGFloat(i) * (.pi / CGFloat(points))
            let p = CGPoint(
                x: center.x + cos(angle) * r,
                y: center.y + sin(angle) * r
            )
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }
}
```

If a star shape already exists, skip this step and import the existing one.

- [ ] **Step 2: Share — star-ghost**

In `TicketDetailView.swift` (or wherever share is invoked), add ephemeral state:

```swift
@State private var shareStarTrigger = UUID()
@State private var showShareStar = false
```

Wrap the ticket with an overlay:

```swift
.overlay(alignment: .center) {
    if showShareStar {
        SevenPointStar()
            .fill(Color.primary)
            .frame(width: 24, height: 24)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.8).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            ))
    }
}
```

When the share button is tapped:

```swift
withAnimation(MotionTokens.impulse) { showShareStar = true }
DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
    withAnimation(MotionTokens.editorial) { showShareStar = false }
    presentShareSheet()
}
```

Apply ticket `.scaleEffect(showShareStar ? 0.94 : 1.0)` + `.sensoryFeedback(.success, trigger: shareStarTrigger)` bound to successful presentation.

- [ ] **Step 3: Delete — tear modifier**

Create `Lumoria App/views/tickets/TicketTearDeleteModifier.swift`:

```swift
import SwiftUI

struct TicketTearDeleteModifier: ViewModifier {
    /// Call `.trigger()` to run the tear. The caller removes the ticket
    /// from the store on completion via `onCompleted`.
    @Binding var tearing: Bool
    let onCompleted: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        GeometryReader { geo in
            ZStack {
                if !tearing {
                    content
                } else if reduceMotion {
                    content.opacity(0)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onCompleted() }
                        }
                } else {
                    TornHalves(content: content, size: geo.size, onCompleted: onCompleted)
                }
            }
        }
    }
}

private struct TornHalves<Content: View>: View {
    let content: Content
    let size: CGSize
    let onCompleted: () -> Void
    @State private var fell = false

    var body: some View {
        ZStack {
            content
                .mask(Rectangle().frame(width: size.width, height: size.height / 2).offset(y: -size.height / 4))
                .offset(y: fell ? -40 : 0)
                .rotationEffect(.degrees(fell ? -6 : 0), anchor: .bottom)
                .opacity(fell ? 0 : 1)
            content
                .mask(Rectangle().frame(width: size.width, height: size.height / 2).offset(y: size.height / 4))
                .offset(y: fell ? 60 : 0)
                .rotationEffect(.degrees(fell ? 4 : 0), anchor: .top)
                .opacity(fell ? 0 : 1)
        }
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            withAnimation(.easeIn(duration: 0.45)) { fell = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.46) { onCompleted() }
        }
    }
}

extension View {
    func ticketTearOnDelete(
        tearing: Binding<Bool>,
        onCompleted: @escaping () -> Void
    ) -> some View {
        modifier(TicketTearDeleteModifier(tearing: tearing, onCompleted: onCompleted))
    }
}
```

Adopt in `TicketDetailView`: confirmation dialog's destructive action sets `tearing = true`, `onCompleted` calls the store's delete + pop.

- [ ] **Step 4: Duplicate — slide-out**

In `TicketDetailView` (or row swipe action), on duplicate tap:

```swift
@State private var duplicateOffset: CGFloat = 0
@State private var showGhost = false
```

```swift
.overlay {
    if showGhost {
        TicketPreview(ticket: ticket, isCentered: false)
            .offset(x: duplicateOffset, y: duplicateOffset)
            .opacity(0.8)
            .transition(.opacity)
    }
}
.onChange(of: duplicateRequested) { _, _ in
    withAnimation(MotionTokens.settle) {
        showGhost = true
        duplicateOffset = 16
    }
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
        showGhost = false
        store.duplicate(ticket) { newId in
            route(to: newId)
        }
    }
}
```

- [ ] **Step 5: Export shimmer sweep**

In `ExportSheet.swift`, while the file is writing (spinner state), overlay the preview with a one-pass sweep gradient (same linear overlay as `blessingOverlay` in Task 14 but 420ms). On completion:

```swift
.sensoryFeedback(.success, trigger: exportDoneTick)
```

And briefly show a star badge in a corner:

```swift
.overlay(alignment: .topTrailing) {
    if exportDoneTick > 0, showStarBadge {
        SevenPointStar()
            .fill(Color.accentColor)
            .frame(width: 16, height: 16)
            .padding(12)
            .transition(.opacity)
    }
}
```

Hide after 800ms.

- [ ] **Step 6: Manual verification**

Run. Share/Delete/Duplicate/Export each ticket — confirm visuals match the spec (§5).

- [ ] **Step 7: Commit**

```bash
git add "Lumoria App/components/SevenPointStar.swift" \
        "Lumoria App/views/tickets/TicketTearDeleteModifier.swift" \
        "Lumoria App/views/tickets/TicketDetailView.swift" \
        "Lumoria App/views/tickets/new/ExportSheet.swift"
git commit -m "feat(microinteractions): share star-ghost, tear delete, duplicate slide, export sweep"
```

---

## Task 16: Pull-to-Refresh Star

**Files:**
- Create: `Lumoria App/components/LumoriaPullToRefresh.swift`
- Modify: `Lumoria App/views/tickets/AllTicketsView.swift`
- Modify: `Lumoria App/views/collections/CollectionsView.swift`

- [ ] **Step 1: Create the custom control**

Create `Lumoria App/components/LumoriaPullToRefresh.swift`:

```swift
import SwiftUI

/// Wraps `.refreshable` but replaces the default spinner with a
/// 7-point star that rotates with pull distance and pulses when the
/// threshold is crossed.
struct LumoriaPullToRefresh<Content: View>: View {

    @ViewBuilder let content: () -> Content
    let onRefresh: () async -> Void

    @State private var pullOffset: CGFloat = 0
    @State private var crossedThreshold = false
    private let threshold: CGFloat = 100

    var body: some View {
        ScrollView {
            GeometryReader { geo in
                let offset = max(0, geo.frame(in: .named("pullspace")).minY)
                Color.clear
                    .preference(key: PullOffsetKey.self, value: offset)
            }
            .frame(height: 0)

            VStack(spacing: 0) {
                starHeader
                    .frame(height: pullOffset)
                    .opacity(min(1, Double(pullOffset / threshold)))
                content()
            }
        }
        .coordinateSpace(name: "pullspace")
        .onPreferenceChange(PullOffsetKey.self) { value in
            pullOffset = value
            let crossing = value >= threshold
            if crossing != crossedThreshold {
                crossedThreshold = crossing
                if crossing {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    Task {
                        await onRefresh()
                        withAnimation(MotionTokens.editorial) { pullOffset = 0 }
                        crossedThreshold = false
                    }
                }
            }
        }
    }

    private var starHeader: some View {
        SevenPointStar()
            .fill(Color.primary)
            .frame(width: 28, height: 28)
            .rotationEffect(.degrees(Double(pullOffset / 60) * 360))
            .scaleEffect(crossedThreshold ? 1.2 : 1.0)
            .animation(MotionTokens.impulse, value: crossedThreshold)
    }
}

private struct PullOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
```

- [ ] **Step 2: Adopt in list views**

In `AllTicketsView.swift` and `CollectionsView.swift`, replace the outer `ScrollView` / `.refreshable` with:

```swift
LumoriaPullToRefresh(
    content: { ticketsList },
    onRefresh: { await store.reload() }
)
```

- [ ] **Step 3: Manual verification**

Run on device. Pull each list down:
- Star appears at center of pull area.
- Rotates 1 full turn per ~60pt pulled.
- At threshold, star scales up and a success haptic fires.
- List refreshes; star fades.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/components/LumoriaPullToRefresh.swift" \
        "Lumoria App/views/tickets/AllTicketsView.swift" \
        "Lumoria App/views/collections/CollectionsView.swift"
git commit -m "feat(microinteractions): custom 7-point-star pull-to-refresh"
```

---

## Task 17: Auth Polish

**Files:**
- Modify: `Lumoria App/views/authentication/AuthView.swift`
- Modify: `Lumoria App/views/authentication/LogInView.swift`
- Modify: `Lumoria App/views/authentication/SignUpView.swift`
- Modify: `Lumoria App/views/settings/SettingsView.swift` (for log-out confirm)

- [ ] **Step 1: AuthView entrance**

In `AuthView.swift`, the root container:

```swift
@State private var logoAppeared = false
@State private var taglineAppeared = false
@State private var starPulse = false
```

```swift
LumoriaLogo()
    .offset(y: logoAppeared ? 0 : -12)
    .opacity(logoAppeared ? 1 : 0)
    .scaleEffect(starPulse ? 1.15 : 1.0, anchor: .center) // apply to the star subview
    .animation(MotionTokens.settle, value: logoAppeared)

Text(tagline)
    .opacity(taglineAppeared ? 1 : 0)

// …

.onAppear {
    logoAppeared = true
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.50) { withAnimation(.easeInOut(duration: 0.18)) { starPulse = true } }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) { withAnimation(.easeInOut(duration: 0.18)) { starPulse = false } }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.68) { withAnimation(MotionTokens.editorial) { taglineAppeared = true } }
}
```

If `LumoriaLogo` doesn't expose a way to target only the star, apply `starPulse` to the whole logo — acceptable for this pass.

- [ ] **Step 2: CTA success — star crossfade**

In `LogInView.swift` and `SignUpView.swift`, the primary button:

```swift
@State private var ctaState: CTAState = .idle
enum CTAState { case idle, loading, success }
```

In the button label:

```swift
Group {
    switch ctaState {
    case .idle:    Text("Log in")
    case .loading: ProgressView()
    case .success: SevenPointStar().fill(.white).frame(width: 20, height: 20)
                     .scaleEffect(pulse ? 1.15 : 1.0)
    }
}
.transition(.opacity)
.animation(MotionTokens.editorial, value: ctaState)
```

On auth success, set `ctaState = .success`, fire `.notificationOccurred(.success)`, 350ms later route.

- [ ] **Step 3: Log-out confirmation — warn haptic**

In `SettingsView.swift`, the log-out dialog's destructive button:

```swift
Button("Log out", role: .destructive) {
    UINotificationFeedbackGenerator().notificationOccurred(.warning)
    logOut()
}
```

- [ ] **Step 4: Manual verification**

Run. Launch cold, view AuthView entrance. Log in — watch CTA succeed with star crossfade. Settings → log out → warn haptic on destructive button tap.

- [ ] **Step 5: Commit**

```bash
git add "Lumoria App/views/authentication/AuthView.swift" \
        "Lumoria App/views/authentication/LogInView.swift" \
        "Lumoria App/views/authentication/SignUpView.swift" \
        "Lumoria App/views/settings/SettingsView.swift"
git commit -m "feat(microinteractions): auth entrance + CTA star + log-out warn haptic"
```

---

## Task 18: Settings Row, Toggle, Footer Star

**Files:**
- Modify: `Lumoria App/views/settings/SettingsView.swift`
- Modify: `Lumoria App/components/LumoriaListItem.swift`
- Modify: `Lumoria App/components/MadeWithLumoria.swift`

- [ ] **Step 1: Row tap highlight**

In `LumoriaListItem.swift`, the tappable row:

```swift
@State private var pressed = false
```

```swift
.background(pressed ? Color.gray.opacity(0.08) : Color.clear)
.animation(.easeOut(duration: 0.06), value: pressed)
.sensoryFeedback(.selection, trigger: pressed)
.simultaneousGesture(
    DragGesture(minimumDistance: 0)
        .onChanged { _ in pressed = true }
        .onEnded { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { pressed = false }
        }
)
```

- [ ] **Step 2: Toggle haptic + spring**

Wherever `Toggle(…)` appears in settings, wrap with:

```swift
Toggle(isOn: $value) { … }
    .sensoryFeedback(.impact(weight: .light), trigger: value)
```

SwiftUI handles the thumb spring already — no extra work needed.

- [ ] **Step 3: "Made with Lumoria" footer star rotation**

In `MadeWithLumoria.swift`, locate the star subview. Add:

```swift
@State private var rotated = false
```

```swift
SevenPointStar()
    .rotationEffect(.degrees(rotated ? 360 : 0))
    .animation(.linear(duration: 8).repeatForever(autoreverses: false), value: rotated)
    .onAppear { if !UIAccessibility.isReduceMotionEnabled { rotated = true } }
    .accessibilityHidden(true)
```

Ensure the rotation only starts `.onAppear` and uses `.linear(duration: 8).repeatForever(autoreverses: false)`.

- [ ] **Step 4: Manual verification**

Run. Settings: tap any row → selection haptic + 60ms gray wash. Flip a toggle → light impact. Scroll to footer → star rotates slowly and continuously.

- [ ] **Step 5: Commit**

```bash
git add "Lumoria App/components/LumoriaListItem.swift" \
        "Lumoria App/views/settings/SettingsView.swift" \
        "Lumoria App/components/MadeWithLumoria.swift"
git commit -m "feat(microinteractions): settings rows, toggles, footer star rotation"
```

---

## Task 19: Empty States + Aurora Ticket-Aware Slowdown

**Files:**
- Modify: `Lumoria App/views/tickets/AllTicketsView.swift`
- Modify: `Lumoria App/views/collections/CollectionsView.swift`
- Modify: `Lumoria App/LandingView.swift` (aurora orbs)

- [ ] **Step 1: Empty-state star**

In each empty list view, replace the current empty placeholder with:

```swift
VStack(spacing: 20) {
    SevenPointStar()
        .fill(Color.primary)
        .frame(width: 64, height: 64)
        .overlay(TicketShimmerView(mode: .softGlow, isActive: true))
    Text("Your memories start here.")
        .font(.headline)
}
.contentShape(Rectangle())
.onTapGesture {
    routeToCreation()
}
```

The softGlow shimmer over a 7-point star needs the star to act as a mask. Use `.mask(SevenPointStar())` on the shimmer view rather than `.overlay` if the star is drawn behind. For this pass, `.overlay` on the fill shape is acceptable since the softGlow spreads anyway.

Tap anywhere routes to creation; add a quick scale pulse:

```swift
.scaleEffect(pulse ? 1.08 : 1.0)
.animation(MotionTokens.impulse, value: pulse)
```

Set `pulse = true` then `false` then route.

- [ ] **Step 2: Aurora orbs ticket-aware slowdown**

In `LandingView.swift` (or wherever aurora orbs animate), add a `tickerHero: Bool` property, default false. Multiply the orbs' drift speed by `tickerHero ? 0.4 : 1.0`.

Raise `tickerHero` when a ticket is displayed in hero context (e.g. single-ticket detail screen open, or sheet preview). Use a simple `@Environment(\.ticketHeroMode)` custom key, or pass explicitly from the parent where applicable.

If propagating via environment is too invasive for this pass, skip the automatic detection and expose `tickerHero` as a setter called by `TicketDetailView.onAppear { … }` via NotificationCenter. Note the decision in the PR.

- [ ] **Step 3: Manual verification**

Run. Sign in with a fresh account (or delete all tickets): empty state shows star + "Your memories start here." Tap routes to creation. Open an existing ticket detail from a list: aurora orbs (if visible behind) slow to 40% speed.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/views/tickets/AllTicketsView.swift" \
        "Lumoria App/views/collections/CollectionsView.swift" \
        "Lumoria App/LandingView.swift"
git commit -m "feat(microinteractions): empty-state star + aurora ticket-aware slowdown"
```

---

## Task 20: Accessibility + Performance Guardrails

**Files:**
- Modify: `Lumoria App/motion/TiltMotionManager.swift` (verify)
- Modify: `Lumoria App/components/TicketShimmerView.swift` (verify)
- Modify: `Lumoria App/views/tickets/TicketSaveRevealView.swift` (verify)
- Add: `Lumoria App/motion/DeviceTier.swift`

- [ ] **Step 1: Device tier helper**

Create `Lumoria App/motion/DeviceTier.swift`:

```swift
import UIKit

/// Coarse device-tier gate used to degrade expensive shimmer modes on
/// older silicon. Current rule: A12 and below → no holographic.
enum DeviceTier {
    case high   // A13 and newer
    case low

    static var current: DeviceTier {
        var info = utsname()
        uname(&info)
        let model = withUnsafePointer(to: &info.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
        // A12 devices: iPhone 11 series uses A13 — so A12 cutoff is:
        // iPhone XS/XS Max/XR ("iPhone11,x"), iPad Pro 2018, iPad Air 3.
        let lowerModels = ["iPhone11,", "iPad8,", "iPad11,3", "iPad11,4"]
        if lowerModels.contains(where: { model.hasPrefix($0) }) {
            return .low
        }
        return .high
    }
}
```

- [ ] **Step 2: Gate holographic in shimmer view**

In `TicketShimmerView.swift` `effectiveMode`:

```swift
private var effectiveMode: TicketShimmer {
    if reduceMotion { return mode == .holographic ? .paperGloss : mode }
    if ProcessInfo.processInfo.isLowPowerModeEnabled, mode == .holographic {
        return .paperGloss
    }
    if DeviceTier.current == .low, mode == .holographic {
        return .paperGloss
    }
    return mode
}
```

- [ ] **Step 3: VoiceOver audit**

For each new animation host added (TicketSaveRevealView, TicketTearDeleteModifier, LumoriaPullToRefresh), ensure:
- Hidden decorative elements use `.accessibilityHidden(true)`.
- State transitions announce via `.accessibilityValue` or `UIAccessibility.post(notification: .announcement, argument: "Saved")` where semantically meaningful.

Add to `TicketSaveRevealView.runRevealSequence`, after the final band:

```swift
UIAccessibility.post(notification: .announcement, argument: String(localized: "Saved."))
```

Add to tear completion:

```swift
UIAccessibility.post(notification: .announcement, argument: String(localized: "Deleted."))
```

- [ ] **Step 4: Low-power verification**

Enable Low Power Mode in device Settings. Launch app. Confirm:
- Tilt shimmer freezes (paperGloss only, no dynamic on holographic templates).
- Aurora orbs freeze (observe from `LandingView`).
- Haptics and transitions still fire.

- [ ] **Step 5: Reduce Motion verification**

Enable Reduce Motion in Accessibility settings. Confirm:
- Tickets show paperGloss / softGlow at neutral (no tilt response).
- Save moment is a single 300ms crossfade + success haptic.
- Pull-to-refresh star does not rotate (add a gate: `rotationEffect(.degrees(reduceMotion ? 0 : angle))`).
- Empty-state softGlow renders static.
- Log-out dialog warn haptic still fires.

- [ ] **Step 6: High Contrast verification**

Enable Increase Contrast in Accessibility. Confirm shimmer disappears entirely on tickets.

- [ ] **Step 7: Performance smoke test**

Run on an iPhone 12 (baseline). Open the tickets list with ~20 tickets. Scroll quickly. Open Instruments > Animation Hitches. Confirm hitches under 1% duration.

If hitches exceed budget, consider: reducing `.drawingGroup()` usage, lowering CoreMotion rate to 30 Hz for low-tier devices, or rendering shimmer only for the centred card (already done — confirm).

- [ ] **Step 8: Commit**

```bash
git add "Lumoria App/motion/DeviceTier.swift" \
        "Lumoria App/components/TicketShimmerView.swift" \
        "Lumoria App/views/tickets/TicketSaveRevealView.swift" \
        "Lumoria App/views/tickets/TicketTearDeleteModifier.swift" \
        "Lumoria App/components/LumoriaPullToRefresh.swift"
git commit -m "feat(microinteractions): a11y and perf guardrails (device tier, VO, low power)"
```

---

## Task 21: Localization Updates

**Files:**
- Modify: `Lumoria App/Localizable.xcstrings`

- [ ] **Step 1: Add new strings**

Open `Lumoria App/Localizable.xcstrings` in Xcode. Add:

| Key | Value (en) |
|-----|-----------|
| `microinteractions.save.toast` | "Saved." |
| `microinteractions.share.done` | "Shared." |
| `microinteractions.delete.done` | "Deleted." |
| `microinteractions.empty.start` | "Your memories start here." |
| `microinteractions.inspect.action` | "Inspect ticket" |
| `microinteractions.save.replay` | "Replay save animation" |

Replace any literal strings in `TicketSaveRevealView`, `TicketTearDeleteModifier`, empty-state views, and inspect modifier with `String(localized: "…")` referencing these keys.

- [ ] **Step 2: Verify build**

Run: `xcodebuild build -scheme "Lumoria App" -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add "Lumoria App/Localizable.xcstrings" \
        "Lumoria App/views/tickets/TicketSaveRevealView.swift" \
        "Lumoria App/views/tickets/TicketTearDeleteModifier.swift" \
        "Lumoria App/components/TicketInspectModifier.swift" \
        "Lumoria App/views/tickets/AllTicketsView.swift" \
        "Lumoria App/views/collections/CollectionsView.swift"
git commit -m "l10n: add microinteractions strings to catalog"
```

---

## Final Verification

- [ ] **Step 1: Run all tests**

Run: `xcodebuild test -scheme "Lumoria App" -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: ALL PASS.

- [ ] **Step 2: Build for device**

Run: `xcodebuild build -scheme "Lumoria App" -destination 'generic/platform=iOS'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Smoke test on device**

On a physical iPhone 12 or newer, walk through:
1. Cold-launch → AuthView entrance.
2. Sign in → CTA success star.
3. Tickets list → scroll → tilt → centered card shimmers only.
4. Tap a ticket → depression + selection haptic + route.
5. Long-press → inspect lift + stamp haptic.
6. Create a new ticket end-to-end → category fade → template hello → form → Save reveal.
7. Share → star-ghost + success haptic.
8. Delete → warn haptic + tear fall.
9. Duplicate → slide-out + stamp haptic.
10. Export → sweep + star badge.
11. Pull-to-refresh → star rotation + success on threshold.
12. Settings → row tap + toggle + footer star.
13. Empty state (create, delete, view list) → star + copy.
14. Enable Reduce Motion → re-test 3, 6, 7, 8, 11 — all fall back correctly.
15. Enable Low Power Mode → re-test 3 — holographic templates downgrade to paperGloss.
16. Enable Increase Contrast → re-test 3 — shimmer disappears.

- [ ] **Step 4: Open PR**

```bash
git push -u origin <branch>
gh pr create --title "feat: Lumoria microinteractions system" --body "…"
```

PR body should reference the spec at `docs/superpowers/specs/2026-04-19-microinteractions-design.md`.

---

## Spec Coverage Self-Review

- §3.1 Motion tokens → Task 1 ✓
- §3.2 Haptic palette → Task 2 ✓
- §3.3 Template shimmer attribute → Task 4 ✓
- §4.1 Tilt shimmer → Tasks 3, 5, 6, 7 ✓
- §4.2 Inspect mode → Task 8 ✓
- §4.3 Edge catch → Task 9 ✓
- §4.4 Tap on card → Task 8 ✓
- §5.1 Save print → Task 14 ✓
- §5.2 Share → Task 15 ✓
- §5.3 Delete tear → Task 15 ✓
- §5.4 Duplicate → Task 15 ✓
- §5.5 Export → Task 15 ✓
- §6 Navigation → Task 12 (with NavigationStack limitation noted) ✓
- §6.6 Pull-to-refresh → Task 16 ✓
- §7 Creation flow → Task 13 ✓
- §8 Auth → Task 17 ✓
- §9 Settings → Task 18 ✓
- §10 Empty states → Task 19 ✓
- §11 Aurora slowdown → Task 19 ✓
- §12 Accessibility + perf → Task 20 ✓
- §13 Copy + l10n → Task 21 ✓

No gaps.
