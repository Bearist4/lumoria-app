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

    @State private var hasEmerged: Bool = false
    @State private var hasFlipped: Bool = false
    @State private var hasSlammed: Bool = false
    @State private var slotVisible: Bool = true
    @State private var captionVisible: Bool = true
    @State private var announced: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            content()
                .rotationEffect(.degrees(ticketRotation))
                .offset(y: ticketOffsetY)
                .scaleEffect(hasSlammed ? 1.03 : 1.0)

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

            if captionVisible {
                Text("Your ticket is being printed…")
                    .font(.footnote)
                    .foregroundStyle(Color.Text.secondary)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 360)
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
        return hasEmerged ? 0 : -380
    }

    // MARK: - Sequence

    private func run() {
        guard !reduceMotion else {
            hasEmerged = true
            hasFlipped = true
            slotVisible = false
            captionVisible = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            announce()
            return
        }

        // Small initial delay so the slot-only state registers visually.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeOut(duration: 0.65)) {
                hasEmerged = true
            }
            HapticPalette.playSavePattern()
        }

        // Hold the rotated-out state, then flip + fade slot/caption.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                hasFlipped = true
            }
            withAnimation(.easeOut(duration: 0.28)) {
                slotVisible = false
                captionVisible = false
            }
        }

        // Slam: tiny overshoot + medium haptic once fully flat.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.85) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.easeOut(duration: 0.08)) {
                hasSlammed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
                    hasSlammed = false
                }
                announce()
            }
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
        .frame(maxWidth: .infinity, minHeight: 360)
    }
}
