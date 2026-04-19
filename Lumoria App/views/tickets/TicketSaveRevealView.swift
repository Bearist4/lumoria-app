import SwiftUI
import UIKit

/// Hosts the printer-emerge reveal of a freshly saved ticket.
///
/// Sequence:
///  1. **Emerge.** Ticket slides down from a slot at the top of the
///     container while bending slightly (leading edge droops ~14°) —
///     like paper fed out of a printer head. Horizontal tickets start
///     rotated 90° (long edge vertical) so the short edge emerges
///     first.
///  2. **Flip.** Horizontal tickets rotate 90° → 0° after emerging.
///     Vertical tickets skip this phase.
///  3. **Slam.** The ticket settles with a quick overshoot, paired
///     with a medium haptic. Brand voice: paper landing on a desk.
///
/// Reduce Motion collapses the whole sequence to a 300ms crossfade +
/// success haptic.
struct TicketSaveRevealView<Content: View>: View {

    let orientation: TicketOrientation
    @ViewBuilder let content: () -> Content

    @State private var emerged: Bool = false
    @State private var flipped: Bool = false
    @State private var slammed: Bool = false
    @State private var announced: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Tuning constants
    private let emergeDuration: Double = 0.55
    private let flipDuration: Double = 0.35
    private let slamOvershoot: CGFloat = 1.03
    private let slamSettle: Double = 0.18

    var body: some View {
        content()
            .rotationEffect(.degrees(printerRotation), anchor: .center)
            .rotation3DEffect(
                .degrees(bendAngle),
                axis: (1, 0, 0),
                anchor: .top,
                perspective: 0.55
            )
            .scaleEffect(slamScale)
            .offset(y: emergeOffsetY)
            .opacity(emerged ? 1 : 0)
            .onAppear(perform: runSequence)
    }

    // MARK: - Animation values

    private var printerRotation: Double {
        guard orientation == .horizontal else { return 0 }
        return flipped ? 0 : 90
    }

    private var bendAngle: Double {
        guard !reduceMotion else { return 0 }
        return emerged ? 0 : 14
    }

    private var emergeOffsetY: CGFloat {
        guard !reduceMotion else { return 0 }
        return emerged ? 0 : -280
    }

    private var slamScale: CGFloat {
        slammed ? slamOvershoot : 1.0
    }

    // MARK: - Sequence

    private func runSequence() {
        guard !reduceMotion else {
            withAnimation(MotionTokens.editorial) { emerged = true; flipped = true }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            announceSaved()
            return
        }

        withAnimation(.easeOut(duration: emergeDuration)) {
            emerged = true
        }
        HapticPalette.playSavePattern()

        let flipDelay = emergeDuration * 0.85
        DispatchQueue.main.asyncAfter(deadline: .now() + flipDelay) {
            if orientation == .horizontal {
                withAnimation(.spring(response: flipDuration, dampingFraction: 0.78)) {
                    flipped = true
                }
            } else {
                flipped = true
            }
        }

        let slamStart = flipDelay + flipDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + slamStart) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.easeOut(duration: 0.10)) { slammed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                withAnimation(.spring(response: slamSettle, dampingFraction: 0.55)) {
                    slammed = false
                }
                announceSaved()
            }
        }
    }

    private func announceSaved() {
        guard !announced else { return }
        announced = true
        UIAccessibility.post(notification: .announcement, argument: String(localized: "Saved."))
    }
}
