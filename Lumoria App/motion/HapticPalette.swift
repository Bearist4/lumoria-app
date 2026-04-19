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
