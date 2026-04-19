import SwiftUI
import UIKit

/// Hosts the print/emboss reveal of a freshly saved ticket. Reveals the
/// ticket content in 4 horizontal bands top-down with a paper-feed
/// haptic, then a single bless sweep marks completion. Falls back to a
/// single crossfade + success haptic when Reduce Motion is enabled.
struct TicketSaveRevealView<Content: View>: View {

    @ViewBuilder let content: () -> Content

    @State private var revealedBands: Int = 0
    @State private var blessSweep: Bool = false
    @State private var announced: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        content()
            .mask(revealMask)
            .overlay(blessOverlay)
            .onAppear(perform: runRevealSequence)
    }

    private var revealMask: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                ForEach(0..<4) { i in
                    Rectangle()
                        .frame(height: geo.size.height / 4)
                        .opacity(i < revealedBands ? 1 : 0)
                }
            }
        }
    }

    @ViewBuilder private var blessOverlay: some View {
        if blessSweep {
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0), location: 0.0),
                    .init(color: .white.opacity(0.35), location: 0.5),
                    .init(color: .white.opacity(0), location: 1.0),
                ],
                startPoint: UnitPoint(x: -0.3, y: 0.5),
                endPoint: UnitPoint(x: 1.3, y: 0.5)
            )
            .blendMode(.screen)
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }

    private func runRevealSequence() {
        guard !reduceMotion else {
            withAnimation(MotionTokens.editorial) {
                revealedBands = 4
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            announceSaved()
            return
        }
        HapticPalette.playSavePattern()
        for i in 1...4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.140) {
                withAnimation(MotionTokens.editorial) {
                    revealedBands = i
                }
                if i == 4 {
                    withAnimation(MotionTokens.expose) { blessSweep = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + MotionTokens.exposeDuration) {
                        withAnimation(.easeOut(duration: 0.2)) { blessSweep = false }
                        announceSaved()
                    }
                }
            }
        }
    }

    private func announceSaved() {
        guard !announced else { return }
        announced = true
        UIAccessibility.post(notification: .announcement, argument: String(localized: "Saved."))
    }
}
