import SwiftUI
import UIKit

/// A very subtle whole-surface white wash that shifts opacity with the
/// phone's tilt. Replaces the earlier multi-mode shimmer — the effect
/// is now deliberately restrained so it never competes with the
/// ticket's own artwork.
///
/// Rendering is gated by:
/// - `isActive` — viewport visibility.
/// - `UIAccessibility.isReduceMotionEnabled` — overlay is static.
/// - `.increased` color-scheme contrast — overlay hidden entirely.
struct TicketShimmerView: View {

    /// Caller raises this when the ticket is the currently focused card.
    var isActive: Bool = true

    @ObservedObject private var motion: TiltMotionManager = .shared

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        GeometryReader { geo in
            wash(in: geo.size)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func wash(in size: CGSize) -> some View {
        if shouldDisable {
            EmptyView()
        } else {
            LinearGradient(
                stops: gradientStops,
                startPoint: UnitPoint(x: startPointX, y: 0),
                endPoint: UnitPoint(x: startPointX + 1, y: 1)
            )
            .blendMode(.screen)
            .opacity(effectiveActive ? 1 : 0.25)
        }
    }

    // MARK: - Lighting math

    private var pitchNorm: Double {
        guard effectiveActive else { return 0 }
        return max(-1, min(1, motion.pitch / (Double.pi / 3)))
    }

    private var rollNorm: Double {
        guard effectiveActive else { return 0 }
        return max(-1, min(1, motion.roll / (Double.pi / 3)))
    }

    /// Very faint white peak that slides across the ticket with roll;
    /// pitch adds a touch of warmth to the centre.
    private var gradientStops: [Gradient.Stop] {
        let peak = 0.06 + abs(pitchNorm) * 0.04 // 0.06–0.10
        return [
            .init(color: .white.opacity(0.0),  location: 0.0),
            .init(color: .white.opacity(peak), location: 0.5),
            .init(color: .white.opacity(0.0),  location: 1.0),
        ]
    }

    /// Shifts the gradient's start so the highlight slides left/right
    /// with roll. Range roughly [-0.3, 0.3].
    private var startPointX: Double {
        -0.3 + (rollNorm + 1) * 0.3
    }

    // MARK: - Policy

    private var shouldDisable: Bool {
        contrast == .increased
    }

    private var effectiveActive: Bool {
        isActive && !reduceMotion
    }
}

// MARK: - Previews

#Preview("Wash over red") {
    Rectangle()
        .fill(Color(red: 0.9, green: 0.3, blue: 0.3))
        .frame(width: 320, height: 160)
        .overlay(TicketShimmerView())
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
}
