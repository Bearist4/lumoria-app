import SwiftUI

extension AnyTransition {

    /// Editorial push — slide in from trailing + fade.
    static var editorialPush: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    /// Full-screen cover replacement — fade up 8pt.
    static var coverFadeUp: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .opacity
        )
    }

    /// Tab crossfade — pure opacity.
    static var tabCrossfade: AnyTransition { .opacity }
}
