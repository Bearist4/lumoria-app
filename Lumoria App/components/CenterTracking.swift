import SwiftUI

extension View {
    /// Writes `binding = id` when the receiver's global vertical midpoint
    /// comes within `threshold` points of the screen's vertical midpoint.
    /// Used to gate per-row ticket shimmer to only the visually-centered card.
    ///
    /// Seeds an initial measurement on appear so the first-visible row is
    /// detected without requiring the user to scroll.
    func trackCenteredRow<ID: Hashable>(
        id: ID,
        into binding: Binding<ID?>,
        threshold: CGFloat = 80
    ) -> some View {
        modifier(CenteredRowTracker(id: id, binding: binding, threshold: threshold))
    }
}

private struct CenteredRowTracker<ID: Hashable>: ViewModifier {
    let id: ID
    let binding: Binding<ID?>
    let threshold: CGFloat

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { evaluate(midY: proxy.frame(in: .global).midY) }
                    .onChange(of: proxy.frame(in: .global).midY) { _, midY in
                        evaluate(midY: midY)
                    }
            }
        )
    }

    private func evaluate(midY: CGFloat) {
        let screenMid = UIScreen.main.bounds.midY
        guard abs(midY - screenMid) < threshold else { return }
        if binding.wrappedValue != id {
            binding.wrappedValue = id
        }
    }
}
