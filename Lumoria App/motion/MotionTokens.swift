import SwiftUI

/// Reusable animation curves that encode the brand's motion personality.
/// Pair with haptics from `HapticPalette` at call sites.
enum MotionTokens {

    // Documented constants — exposed so tests can verify intent without
    // introspecting an `Animation` value.
    static let editorialDuration: Double = 0.32
    static let exposeDuration: Double = 0.62
    static let settleResponse: Double = 0.45
    static let settleDamping: Double = 0.82
    static let impulseResponse: Double = 0.22
    static let impulseDamping: Double = 0.65

    /// Default transition curve. Ease-out, 320ms. Nav push/pop, title lifts,
    /// most "content arriving" motion.
    static let editorial: Animation = .easeOut(duration: editorialDuration)

    /// Spring for things landing — tickets on save, sheets on present.
    static let settle: Animation = .spring(
        response: settleResponse,
        dampingFraction: settleDamping
    )

    /// Small state changes. Tap scales, toggles, row highlights.
    static let impulse: Animation = .spring(
        response: impulseResponse,
        dampingFraction: impulseDamping
    )

    /// Photographic reveal. Only used for the save print/emboss sequence.
    static let expose: Animation = .easeInOut(duration: exposeDuration)
}
