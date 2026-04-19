import SwiftUI

/// Press styling for ticket cards — tiny depression scale on press plus
/// a selection haptic. Used as `.buttonStyle(TicketCardButtonStyle())`
/// on the `NavigationLink` wrapping each ticket preview.
struct TicketCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(MotionTokens.impulse, value: configuration.isPressed)
            .sensoryFeedback(.selection, trigger: configuration.isPressed)
    }
}

/// Adds long-press inspect behaviour to a ticket card. While held, the
/// ticket lifts (scale 1.06) with a deeper shadow and fires a single
/// stamp haptic. Release returns it. Also exposes an "Inspect ticket"
/// VoiceOver action so the gesture is reachable without long-press.
///
/// Uses SwiftUI's `.onLongPressGesture(…, onPressingChanged:)` so the
/// gesture does not swallow the parent `NavigationLink`'s tap or the
/// enclosing `ScrollView`'s vertical pan — a manually-composed
/// `LongPressGesture.sequenced(before: DragGesture)` would.
struct TicketInspectModifier: ViewModifier {

    @State private var isHolding = false
    @State private var stampTrigger = 0

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHolding ? 1.06 : 1.0)
            .shadow(
                color: .black.opacity(isHolding ? 0.22 : 0.0),
                radius: isHolding ? 24 : 0,
                y: isHolding ? 14 : 0
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
