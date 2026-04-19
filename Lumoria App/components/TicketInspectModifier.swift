import SwiftUI

/// Press styling for ticket cards — paper-like wiggle on press plus a
/// selection haptic. Used as `.buttonStyle(TicketCardButtonStyle())`
/// on the `NavigationLink` wrapping each ticket preview.
///
/// Physical feel: tiny scale dip + a two-beat rotation that feels like
/// a sheet of paper being pressed into and releasing. Subtle enough to
/// never compete with the ticket's own artwork.
struct TicketCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        WiggleBody(configuration: configuration)
    }

    private struct WiggleBody: View {
        let configuration: ButtonStyleConfiguration
        @State private var wiggleAngle: Double = 0

        var body: some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .rotationEffect(.degrees(wiggleAngle), anchor: .center)
                .animation(MotionTokens.impulse, value: configuration.isPressed)
                .sensoryFeedback(.selection, trigger: configuration.isPressed)
                .onChange(of: configuration.isPressed) { _, pressed in
                    guard pressed, !UIAccessibility.isReduceMotionEnabled else {
                        wiggleAngle = 0
                        return
                    }
                    // Two-beat paper wiggle: +0.8° → -0.6° → 0°.
                    withAnimation(.spring(response: 0.10, dampingFraction: 0.55)) {
                        wiggleAngle = 0.8
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                        withAnimation(.spring(response: 0.14, dampingFraction: 0.55)) {
                            wiggleAngle = -0.6
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
                            wiggleAngle = 0
                        }
                    }
                }
        }
    }
}

/// Adds long-press inspect behaviour to a ticket card. While held, the
/// ticket lifts slightly with a deeper shadow and fires a single stamp
/// haptic. Release returns it. Exposes an "Inspect ticket" VoiceOver
/// action so the gesture is reachable without long-press.
///
/// Uses SwiftUI's `.onLongPressGesture(onPressingChanged:)` so the
/// gesture does not swallow the parent `NavigationLink`'s tap or the
/// enclosing `ScrollView`'s vertical pan.
struct TicketInspectModifier: ViewModifier {

    @State private var isHolding = false
    @State private var stampTrigger = 0

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHolding ? 1.04 : 1.0)
            .shadow(
                color: .black.opacity(isHolding ? 0.18 : 0.0),
                radius: isHolding ? 20 : 0,
                y: isHolding ? 10 : 0
            )
            .animation(MotionTokens.impulse, value: isHolding)
            .accessibilityAction(named: Text("Inspect ticket")) {
                stampTrigger &+= 1
            }
            .onLongPressGesture(minimumDuration: 0.30) {
                stampTrigger &+= 1
            } onPressingChanged: { pressing in
                isHolding = pressing
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: stampTrigger)
    }
}

extension View {
    /// Apply inspect behaviour (long-press lift + VoiceOver action) to
    /// a ticket card.
    func ticketInspect() -> some View {
        modifier(TicketInspectModifier())
    }
}
