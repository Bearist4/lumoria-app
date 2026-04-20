import SwiftUI
import UIKit

/// Printer-style save reveal matching the Figma frames (node-ids
/// 982:28858 → 1760:51575).
///
/// Sequence:
///  1. **Slot.** A horizontal black slot line sits at the top of the
///     preview card. A "Your ticket is being printed…" caption is
///     centred below. The ticket is off-screen above.
///  2. **Emerge.** The ticket slides down from above the slot into
///     view. Horizontal tickets stay rotated 90° (long edge vertical)
///     so the short edge emerges first — like a real printer feed.
///     The save haptic fires as it starts to move.
///  3. **Flip.** Horizontal tickets rotate 90° → 0° to their final
///     display orientation. Slot line and caption fade out in the same
///     beat. Vertical tickets skip the rotation.
///  4. **Slam.** Medium haptic + ~3% overshoot scale, settling on a
///     tight spring.
///
/// Reduce Motion collapses the sequence to the final state + success
/// haptic with no motion.
struct TicketSaveRevealView<Content: View>: View {

    let orientation: TicketOrientation
    @ViewBuilder let content: () -> Content

    /// 0 = ticket fully above slot, 1 = ticket flat at y=0.
    @State private var emergeProgress: Double = 0
    @State private var hasFlipped: Bool = false
    @State private var hasSlammed: Bool = false
    @State private var slotVisible: Bool = true
    @State private var captionVisible: Bool = true
    @State private var announced: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let travel: CGFloat = 400

    var body: some View {
        ZStack {
            // Caption sits at the BOTTOM of the z-stack so the ticket
            // prints over it as it emerges.
            if captionVisible {
                Text("Your ticket is being printed…")
                    .font(.footnote)
                    .foregroundStyle(Color.Text.secondary)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }

            // Ticket — prints over the caption.
            content()
                .rotationEffect(.degrees(ticketRotation))
                .offset(y: ticketOffsetY)
                .scaleEffect(hasSlammed ? 1.03 : 1.0)

            // Slot line sits on top so the ticket appears to emerge from
            // behind it at the leading edge of the preview card.
            if slotVisible {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.Text.primary)
                        .frame(height: 3)
                        .padding(.horizontal, 16)
                    Spacer(minLength: 0)
                }
                .transition(.opacity)
                .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .onAppear(perform: run)
    }

    // MARK: - Animation values

    private var ticketRotation: Double {
        guard orientation == .horizontal else { return 0 }
        return hasFlipped ? 0 : 90
    }

    private var ticketOffsetY: CGFloat {
        guard !reduceMotion else { return 0 }
        return CGFloat(-travel) * CGFloat(1 - emergeProgress)
    }

    // MARK: - Sequence

    /// Timeline:
    ///   t=0.00  slot + caption visible, no ticket
    ///   t=0.35  smooth intro: 0 → 5 % (engage ticks)
    ///   t=0.50  stutter: 6 %, 7 %, 8 %, 9 % in ~80 ms beats
    ///   t=0.82  smooth feed: 9 % → 100 %
    ///   t=1.65  flip 90° → 0° (horizontal only)
    ///   t=2.10  slam (overshoot + medium haptic)
    ///   t=2.40  slot + caption dissolve
    private func run() {
        guard !reduceMotion else {
            emergeProgress = 1
            hasFlipped = true
            slotVisible = false
            captionVisible = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            announce()
            return
        }

        // Smooth intro: 0 → 5 % over 150 ms.
        schedule(0.35) {
            withAnimation(.easeOut(duration: 0.15)) { emergeProgress = 0.05 }
        }
        tick(at: 0.35, intensity: 0.7)
        tick(at: 0.40, intensity: 0.6)

        // Stutter: 6 % / 7 % / 8 % / 9 %, each 40 ms apart. Short
        // `.easeOut` per step makes each jump feel abrupt.
        let stutterStart = 0.52
        let stutterStep = 0.085
        for (i, p) in [0.06, 0.07, 0.08, 0.09].enumerated() {
            let at = stutterStart + Double(i) * stutterStep
            schedule(at) {
                withAnimation(.easeOut(duration: 0.035)) { emergeProgress = p }
            }
            tick(at: at, intensity: 0.55)
        }

        // Smooth feed: 9 % → 100 % over 820 ms.
        let feedStart = stutterStart + 4 * stutterStep + 0.05
        schedule(feedStart) {
            withAnimation(.easeOut(duration: 0.82)) { emergeProgress = 1.0 }
        }
        tick(at: feedStart + 0.15, intensity: 0.4)
        tick(at: feedStart + 0.35, intensity: 0.4)
        tick(at: feedStart + 0.55, intensity: 0.45)
        tick(at: feedStart + 0.75, intensity: 0.5)

        // Flip 90° → 0° for horizontal tickets.
        let flipStart = feedStart + 0.85
        schedule(flipStart) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                hasFlipped = true
            }
        }
        tick(at: flipStart, intensity: 0.55)
        tick(at: flipStart + 0.12, intensity: 0.5)

        // Slam.
        let slamStart = flipStart + 0.45
        schedule(slamStart) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.easeOut(duration: 0.08)) { hasSlammed = true }
            schedule(0.08) {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
                    hasSlammed = false
                }
            }
        }

        // Slot + caption dissolve AFTER the slam settles.
        let dissolveStart = slamStart + 0.30
        schedule(dissolveStart) {
            withAnimation(.easeOut(duration: 0.45)) {
                slotVisible = false
                captionVisible = false
            }
            announce()
        }
    }

    // MARK: - Helpers

    private func schedule(_ delay: TimeInterval, _ action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action)
    }

    private func tick(at delay: TimeInterval, intensity: CGFloat) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            let gen = UIImpactFeedbackGenerator(style: .rigid)
            gen.prepare()
            gen.impactOccurred(intensity: intensity)
        }
    }

    private func announce() {
        guard !announced else { return }
        announced = true
        UIAccessibility.post(notification: .announcement, argument: String(localized: "Saved."))
    }
}

/// Empty-slot placeholder shown in SuccessStep while the Supabase
/// insert is in flight. Matches the first Figma frame: a black slot
/// line at the top and a "being printed" caption centred below.
struct TicketSaveSlotPlaceholder: View {
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.Text.primary)
                    .frame(height: 3)
                    .padding(.horizontal, 16)
                Spacer(minLength: 0)
            }
            Text("Your ticket is being printed…")
                .font(.footnote)
                .foregroundStyle(Color.Text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
