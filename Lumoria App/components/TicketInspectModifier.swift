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
struct TicketInspectModifier: ViewModifier {

    @GestureState private var isHolding = false
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
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.30)
                    .sequenced(before: DragGesture(minimumDistance: 0))
                    .updating($isHolding) { value, state, _ in
                        switch value {
                        case .second(true, _): state = true
                        default:               state = false
                        }
                    }
                    .onEnded { _ in
                        stampTrigger &+= 1
                    }
            )
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
