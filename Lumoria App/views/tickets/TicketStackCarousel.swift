//
//  TicketStackCarousel.swift
//  Lumoria App
//
//  Stacked multi-ticket preview used by the new-ticket success step
//  when the funnel emits more than one ticket in a single run (the
//  multi-leg public-transport journey is the only current source,
//  but the view is agnostic).
//
//  Lifecycle:
//   1. On appear, every ticket starts above the frame, rotated and
//      invisible. They "print" in one at a time, bottom-of-stack
//      first, so the last ticket to land is the one the user sees
//      on top at full opacity.
//   2. Rest state — the top ticket is upright + opaque; cards below
//      are tilted left/right with widening angle, slight offsets and
//      lowered opacity so only the front is the hero.
//   3. Swipe — horizontal drag cycles the stack so any ticket can be
//      brought to the front. Indicator dots track the top index.
//
//  Animations are springs (no hard-coded timings) so the motion
//  reads soft and settled even if multiple gestures overlap.
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1760-51149
//

import SwiftUI

struct TicketStackCarousel: View {
    let tickets: [Ticket]

    /// Index of the ticket currently at the front of the stack.
    @State private var topIndex: Int = 0

    /// Horizontal drag offset applied to the front card only.
    @State private var dragOffset: CGFloat = 0

    /// Count of tickets that have finished "printing" and landed at
    /// their rest positions. Drives the drop-in sequence.
    @State private var droppedCount: Int = 0

    @State private var hasAppeared: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Tuning

    /// Delay between each card's drop-in.
    private let printStagger: TimeInterval = 0.18
    /// Drag distance past which the gesture snaps to the next card.
    private let swipeThreshold: CGFloat = 80

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(Array(tickets.enumerated()), id: \.offset) { idx, ticket in
                    card(for: ticket, at: idx, in: geo.size)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .contentShape(Rectangle())
        .gesture(dragGesture)
        .overlay(alignment: .bottom) {
            if tickets.count > 1 {
                pageIndicator
                    .padding(.bottom, 12)
            }
        }
        .onAppear(perform: handleAppear)
    }

    // MARK: - Card

    @ViewBuilder
    private func card(for ticket: Ticket, at idx: Int, in size: CGSize) -> some View {
        let pos = stackPosition(for: idx)
        let rest = restTransform(for: pos, idx: idx)
        let landed = idx < droppedCount

        let targetOffset = landed
            ? CGSize(
                width: rest.offset.width + dragXOffset(pos),
                height: rest.offset.height
            )
            : CGSize(width: rest.offset.width, height: -size.height)

        let targetRotation = landed
            ? rest.rotation + dragRotation(pos)
            : rest.rotation - 18
        let targetOpacity: Double = landed ? rest.opacity : 0

        TicketPreview(ticket: ticket, isCentered: pos == 0)
            .padding(.horizontal, 16)
            .rotationEffect(.degrees(targetRotation), anchor: .center)
            .offset(targetOffset)
            .opacity(targetOpacity)
            .zIndex(rest.zIndex)
            .animation(.spring(response: 0.55, dampingFraction: 0.78), value: droppedCount)
            .animation(.spring(response: 0.5, dampingFraction: 0.78), value: topIndex)
            .animation(.spring(response: 0.35, dampingFraction: 0.9), value: dragOffset)
    }

    // MARK: - Layout math

    /// Distance from the front card (0 = front, 1 = directly
    /// behind, …). Wraps so cycling the stack is stable.
    private func stackPosition(for idx: Int) -> Int {
        let n = tickets.count
        guard n > 0 else { return 0 }
        return (idx - topIndex + n) % n
    }

    /// Rest transform for a card at a given stack position. The
    /// front card is upright and opaque; cards behind alternate
    /// tilt sides with growing magnitude and fade into the stack.
    private func restTransform(
        for stackPos: Int,
        idx: Int
    ) -> (offset: CGSize, rotation: Double, opacity: Double, zIndex: Double) {
        if stackPos == 0 {
            return (offset: .zero, rotation: 0, opacity: 1, zIndex: 100)
        }

        // Deterministic pseudo-random jitter per (idx, stackPos)
        // so swaps look natural but reproducible. Range: ~[-2, 2].
        let seed = Double((idx &* 37 &+ stackPos &* 7) % 17) / 17 - 0.5
        let jitter = seed * 4

        let side: Double = stackPos.isMultiple(of: 2) ? 1 : -1

        let angleBase: Double = 9 + Double(stackPos - 1) * 4
        let angle = angleBase * side + jitter

        let xBase: CGFloat = 18 + CGFloat(stackPos - 1) * 8
        let xOffset = xBase * (stackPos.isMultiple(of: 2) ? 1 : -1)
        let yOffset = CGFloat(stackPos) * 4

        // Top = 1.0, pos 1 = ~0.45, pos 2 = ~0.30, pos 3 = ~0.20.
        let opacity = max(0.18, 0.55 - Double(stackPos - 1) * 0.12)

        return (
            offset: CGSize(width: xOffset, height: yOffset),
            rotation: angle,
            opacity: opacity,
            zIndex: Double(100 - stackPos)
        )
    }

    private func dragXOffset(_ stackPos: Int) -> CGFloat {
        stackPos == 0 ? dragOffset * 0.35 : 0
    }

    private func dragRotation(_ stackPos: Int) -> Double {
        stackPos == 0 ? Double(dragOffset) / 22 : 0
    }

    // MARK: - Gesture

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { val in
                dragOffset = val.translation.width
            }
            .onEnded { val in
                let velocity = val.predictedEndTranslation.width - val.translation.width
                let shouldAdvance = val.translation.width < -swipeThreshold || velocity < -400
                let shouldRewind  = val.translation.width >  swipeThreshold || velocity >  400

                withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                    dragOffset = 0
                    guard tickets.count > 1 else { return }
                    if shouldAdvance {
                        topIndex = (topIndex + 1) % tickets.count
                    } else if shouldRewind {
                        topIndex = (topIndex - 1 + tickets.count) % tickets.count
                    }
                }
            }
    }

    // MARK: - Appear / print

    private func handleAppear() {
        guard !hasAppeared else { return }
        hasAppeared = true

        // The bottom of the stack is the FIRST ticket to be printed,
        // the top is the last. Setting `topIndex` to the last index
        // means ticket[0] sits behind ticket[N-1] when the drop
        // sequence finishes — matching rider-mental-model ("the last
        // one that came out is the one on top of the pile").
        topIndex = max(tickets.count - 1, 0)

        if reduceMotion {
            // Respect the a11y preference — skip the per-card stagger
            // and land every ticket at once, no animation.
            droppedCount = tickets.count
            return
        }

        for i in 0..<tickets.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * printStagger) {
                droppedCount = i + 1
            }
        }
    }

    // MARK: - Page indicator

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(Array(tickets.enumerated()), id: \.offset) { idx, _ in
                let active = idx == topIndex
                Capsule()
                    .fill(active
                          ? Color.Text.primary
                          : Color.Text.primary.opacity(0.25))
                    .frame(width: active ? 16 : 6, height: 6)
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: topIndex)
            }
        }
    }
}
