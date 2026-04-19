import SwiftUI
import UIKit
import Combine

/// Overlay that paints a tilt-responsive light effect on top of a ticket
/// canvas. Attach as `.overlay(TicketShimmerView(mode: …))` and mask to
/// the ticket shape from the caller.
///
/// Rendering is gated by:
/// - `isActive` — viewport visibility.
/// - `UIAccessibility.isReduceMotionEnabled` — overlay is static at neutral.
/// - `.increased` color-scheme contrast — overlay hidden entirely.
/// - `ProcessInfo.isLowPowerModeEnabled` — holographic degrades to paperGloss.
struct TicketShimmerView: View {

    let mode: TicketShimmer
    /// Caller raises this when the ticket is the centred/focused card.
    /// Off-screen cards should pass `false` to pause motion reads.
    var isActive: Bool = true

    @StateObject private var motion = TiltMotionManagerObserver()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    /// Last fire time for edge-catch haptic (Task 9 consumes this).
    @State private var lastHapticFire: Date = .distantPast
    @State private var lastEdgeSign: Int = 0

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
            Color.clear
                .onChange(of: motion.roll) { _, newRoll in
                    handleRollEdgeCatch(newRoll)
                }
                .overlay {
                    switch effectiveMode {
                    case .paperGloss:  paperGloss(in: size)
                    case .holographic: holographic(in: size)
                    case .softGlow:    softGlow(in: size)
                    case .none:        EmptyView()
                    }
                }
        }
    }

    // MARK: - Paper gloss

    private func paperGloss(in size: CGSize) -> some View {
        let offset = offsetForRoll(size: size)
        let angle = Angle(radians: -(Double.pi / 4)) // fixed 45°
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

    // MARK: - Holographic

    private func holographic(in size: CGSize) -> some View {
        let rollNorm = CGFloat(motion.roll) / CGFloat(Double.pi / 3)
        let pitchNorm = CGFloat(motion.pitch) / CGFloat(Double.pi / 3)
        let baseAngle = Angle(radians: Double(rollNorm) * Double.pi * 2)
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

    // MARK: - Soft glow

    private func softGlow(in size: CGSize) -> some View {
        let pitchNorm = max(0, CGFloat(abs(motion.pitch)) / CGFloat(Double.pi / 3))
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

    // MARK: - Edge-catch haptic

    private func handleRollEdgeCatch(_ newRoll: Double) {
        guard isActive else { return }
        let sign = newRoll > 0 ? 1 : (newRoll < 0 ? -1 : 0)
        guard sign != 0, sign != lastEdgeSign else {
            if sign != 0 { lastEdgeSign = sign }
            return
        }
        let now = Date()
        if now.timeIntervalSince(lastHapticFire) >= 1.5 {
            HapticPalette.playShimmerTick()
            lastHapticFire = now
        }
        lastEdgeSign = sign
    }

    // MARK: - Geometry + policy

    private func offsetForRoll(size: CGSize) -> CGFloat {
        guard isActive else { return 0 }
        let travel = size.width * 0.6
        return CGFloat(motion.roll) / CGFloat(Double.pi / 3) * travel
    }

    private var shouldDisable: Bool {
        if contrast == .increased { return true }
        if mode == .none { return true }
        return false
    }

    private var effectiveMode: TicketShimmer {
        if reduceMotion {
            return mode == .holographic ? .paperGloss : mode
        }
        if ProcessInfo.processInfo.isLowPowerModeEnabled, mode == .holographic {
            return .paperGloss
        }
        if DeviceTier.current == .low, mode == .holographic {
            return .paperGloss
        }
        return mode
    }

    private func wrap(_ v: Double) -> Double {
        var x = v
        while x < 0 { x += 1 }
        while x > 1 { x -= 1 }
        return x
    }
}

// MARK: - Shimmer modifier

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

// MARK: - Motion observer

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
        self.cancellable = manager.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in
                self?.roll = manager.roll
                self?.pitch = manager.pitch
            }
        }
    }
}

// MARK: - Previews

#Preview("PaperGloss over red") {
    Rectangle()
        .fill(Color(red: 0.9, green: 0.3, blue: 0.3))
        .frame(width: 320, height: 160)
        .overlay(TicketShimmerView(mode: .paperGloss))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
}

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
