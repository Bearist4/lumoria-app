//
//  TicketStackCarousel.swift
//  Lumoria App
//
//  Multi-ticket print reveal used by the new-ticket success step when
//  the funnel emits more than one ticket in a single run (multi-leg
//  public-transport journeys are the only current source).
//
//  Each ticket runs the full single-ticket print sequence — stutter,
//  smooth feed, flip, slam — back-to-back. With N tickets at ~2.0 s
//  apiece the user watches the printer cough out each one in turn,
//  not a single batched fall like the previous implementation. Once
//  printed, every ticket is locked at a fixed random landing inside
//  a cone whose vertex is the slot, opening downward — the same
//  pattern paper makes settling on a tray.
//
//  After the last ticket lands the pile crossfades to a horizontal
//  scroller — each ticket renders at full size in its natural
//  orientation, spaced 32 pt apart, snapping into view as the user
//  swipes. The slot + caption dissolve in the same beat.
//
//  Reduce Motion collapses everything to the final state with no motion.
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1760-51149
//

import SwiftUI
import UIKit

struct TicketStackCarousel: View {
    let tickets: [Ticket]

    /// Number of tickets that have completed their full print sequence.
    /// `idx < settledCount` → fixed at landing. `idx == settledCount` →
    /// currently animating in. `idx > settledCount` → not yet rendered.
    @State private var settledCount: Int = 0

    /// Per-ticket landing transforms inside the cone area. Built once
    /// on appear so positions stay stable across re-renders / swipes.
    @State private var landings: [Landing] = []

    /// Slot + caption stay visible across every ticket's print, dissolve
    /// after the last one settles.
    @State private var slotVisible: Bool = true
    @State private var captionVisible: Bool = true

    /// Animation state for the ticket currently in flight (only one at a
    /// time). Reset to 0 / false at the start of each new ticket.
    @State private var currentEmerge: Double = 0
    @State private var currentFlipped: Bool = false
    @State private var currentSlamLift: Bool = false

    /// Set true after the last ticket lands. Triggers the crossfade
    /// from the print pile to the post-print horizontal scroller.
    @State private var allPrinted: Bool = false

    /// Index currently snapped in the post-print scroller. Drives the
    /// page indicator dots. Tracks `scrollPosition(id:)` directly.
    /// Initialised to nil so `defaultScrollAnchor(.trailing)` controls
    /// the opening position; once the scroll mounts an `.onAppear`
    /// seeds it with the last-printed index for the page indicator.
    @State private var visibleIndex: Int? = nil

    /// Shared namespace used by `matchedGeometryEffect` so each ticket
    /// morphs from its cone landing in the print stack to its scroll
    /// cell when `allPrinted` flips, instead of crossfading abruptly.
    @Namespace private var ticketNamespace

    @State private var hasAppeared: Bool = false
    /// Single async task driving the whole sequence — keeps settle and
    /// next-ticket reset atomic so they can't race the way separate
    /// `DispatchQueue.main.asyncAfter` calls did (causing the
    /// 4-of-which-only-2-printed glitch).
    @State private var printTask: Task<Void, Never>? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Tuning

    /// Per-ticket print duration. Total runtime = `tickets.count *
    /// perTicketDuration`. Don't shorten without re-balancing the
    /// stutter / feed / flip / slam sub-timings below.
    private let perTicketDuration: TimeInterval = 2.0

    /// Distance (pt) the ticket travels from above the slot down to its
    /// landing point. Big enough that the start position is fully off
    /// the carousel frame on any reasonable device size.
    private let travel: CGFloat = 380

    var body: some View {
        ZStack {
            // Caption sits below the tickets and fades on its own track
            // so the layout swap (print → scroll) doesn't yank it out
            // mid-fade.
            if captionVisible {
                Text(captionKey)
                    .font(.footnote)
                    .foregroundStyle(Color.Text.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }

            // Ticket pile vs scroll — tickets in both branches share a
            // `matchedGeometryEffect` namespace so each one morphs from
            // its cone landing to its scroll cell on `allPrinted` flip.
            // Both branches use `.transition(.identity)` so the conditional
            // swap is instant — without it the default `.opacity` fade
            // overlaps the print and scroll renders during the
            // transition, which produced the visible ghosting (tickets
            // sliding down at their print positions while their scroll-
            // cell duplicates slid right).
            if allPrinted {
                VStack(spacing: 12) {
                    scrollLayout
                    if tickets.count > 1 {
                        pageIndicator
                    }
                }
                .transition(.identity)
            } else {
                printLayout
                    .transition(.identity)
            }

            // Slot line stays on top so the in-flight ticket appears to
            // emerge from behind it. Owns its own opacity transition.
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
                .zIndex(1000)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: handleAppear)
        .onDisappear { printTask?.cancel() }
    }

    // MARK: - Print layout (during printing)

    private var printLayout: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(Array(tickets.enumerated()), id: \.offset) { idx, ticket in
                    ticketView(idx: idx, ticket: ticket, in: geo.size)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            // Clip ONLY the top edge — the slot doubles as the
            // "printer mouth" so anything above its line should look
            // hidden inside the printer. Bottom and sides stay open
            // so a rotated horizontal ticket can render at full size
            // even when its visual height exceeds the carousel area;
            // the previewCard's own clipShape catches any spill at
            // the card boundary.
            .clipShape(PrintTopClipShape(topInset: 3))
        }
    }

    // MARK: - Scroll layout (after printing)

    /// Horizontal page-snap scroller. Each cell is exactly the
    /// container width so one ticket — horizontal or vertical — fills
    /// the visible area. Internal 16 pt horizontal padding gives
    /// adjacent tickets a 32 pt gap when swiping between pages.
    private var scrollLayout: some View {
        GeometryReader { geo in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    // Reversed order — last-printed sits at the leading
                    // edge of the scroller so it's the first ticket in
                    // line, then earlier prints follow rightward.
                    ForEach(Array(tickets.enumerated()).reversed(), id: \.offset) { idx, ticket in
                        TicketPreview(ticket: ticket, isCentered: idx == visibleIndex)
                            .frame(
                                maxWidth: geo.size.width - 32,
                                maxHeight: geo.size.height
                            )
                            .matchedGeometryEffect(id: idx, in: ticketNamespace)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .id(idx)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $visibleIndex)
            // Leading edge holds the last-printed ticket after the
            // reversal above, so opening at .leading lands the user on
            // the most recent card.
            .defaultScrollAnchor(.leading)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                if visibleIndex == nil {
                    visibleIndex = max(tickets.count - 1, 0)
                }
            }
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            // Reversed to match the scroll's HStack order — leading dot
            // = last-printed ticket = the focused page on first appear.
            ForEach((0..<tickets.count).reversed(), id: \.self) { idx in
                let active = idx == visibleIndex
                Capsule()
                    .fill(active
                          ? Color.Text.primary
                          : Color.Text.primary.opacity(0.25))
                    .frame(width: active ? 16 : 6, height: 6)
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: visibleIndex)
            }
        }
    }

    // MARK: - Caption

    private var captionKey: LocalizedStringKey {
        if tickets.count <= 1 {
            return "Your ticket is being printed…"
        }
        let n = min(settledCount + 1, tickets.count)
        return "Printing ticket \(n) of \(tickets.count)…"
    }

    // MARK: - Ticket views

    @ViewBuilder
    private func ticketView(idx: Int, ticket: Ticket, in size: CGSize) -> some View {
        if idx < settledCount {
            settledTicket(idx: idx, ticket: ticket, in: size)
        } else if idx == settledCount {
            inFlightTicket(idx: idx, ticket: ticket, in: size)
        }
        // idx > settledCount: not rendered yet — waiting its turn.
    }

    private func settledTicket(idx: Int, ticket: Ticket, in size: CGSize) -> some View {
        let l = landing(for: idx)
        let zIdx: Double = Double(idx)
        let scale: CGFloat = ticket.orientation == .vertical ? 0.9 : 1.0

        return TicketPreview(ticket: ticket, isCentered: false)
            .padding(.horizontal, 16)
            .scaleEffect(scale)
            .offset(x: l.dx, y: l.dy)
            .matchedGeometryEffect(id: idx, in: ticketNamespace)
            .zIndex(zIdx)
    }

    private func inFlightTicket(idx: Int, ticket: Ticket, in size: CGSize) -> some View {
        let l = landing(for: idx)
        let p = currentEmerge

        // For horizontal tickets emerging at 90°, anchor visual top at
        // slot during emerge so the ticket appears to come out of the
        // printer mouth instead of sliding through empty space below
        // it. `verticalAnchorOffset` is how far above the carousel
        // center the rotated ticket's center needs to sit so its
        // visual top is just below the slot bar (3 pt). Once the
        // ticket flips flat the anchor relaxes back to 0 and the slam
        // animates it to its final landing.
        let isRotated = ticket.orientation == .horizontal && !currentFlipped
        let topAnchorY: CGFloat = isRotated
            ? slotInsetFromTop - size.height / 2 + (size.width - 32) / 2
            : 0

        let dx = l.dx * p
        // Slide from above the slot down to the anchor + landing.
        let endY = topAnchorY + l.dy
        let dy = -travel + (travel + endY) * p

        let rotation: Double = isRotated ? 90 : 0

        let baseScale: CGFloat = ticket.orientation == .vertical ? 0.9 : 1.0
        let slamScale: CGFloat = currentSlamLift ? 1.03 : 1.0
        let scale = baseScale * slamScale

        return TicketPreview(ticket: ticket, isCentered: true)
            .padding(.horizontal, 16)
            .rotationEffect(.degrees(rotation), anchor: .center)
            .offset(x: dx, y: dy)
            .scaleEffect(scale)
            // Always above every settled ticket — keeps the in-flight
            // ticket on top no matter what the pile underneath looks
            // like.
            .zIndex(2000 + Double(idx))
    }

    /// 3 pt below carousel top — matches the slot bar's bottom edge so
    /// rotated tickets emerging during print line up cleanly with it.
    private let slotInsetFromTop: CGFloat = 3

    private func landing(for idx: Int) -> Landing {
        landings.indices.contains(idx) ? landings[idx] : .zero
    }

    // MARK: - Print sequence

    private func handleAppear() {
        guard !hasAppeared else { return }
        hasAppeared = true

        let lastIdx = tickets.count - 1
        landings = (0..<tickets.count).map { idx in
            // The last-printed ticket sits centered in the container so
            // the print → scroll transition can leave it in place. Only
            // earlier tickets scatter inside the cone.
            idx == lastIdx ? .zero : Landing.cone(seed: idx)
        }

        if reduceMotion {
            // Skip the whole printer choreography — land everything,
            // hide the slot, fire the success haptic.
            settledCount = tickets.count
            allPrinted = true
            slotVisible = false
            captionVisible = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return
        }

        printTask = Task { @MainActor in
            for idx in 0..<tickets.count {
                guard !Task.isCancelled else { return }
                await runPrint(for: idx)
            }
            guard !Task.isCancelled else { return }

            // Final reveal — morph the pile into the horizontal
            // scroller. The scroller opens at its trailing edge via
            // `defaultScrollAnchor(.trailing)`, which corresponds to
            // the last-printed ticket in the natural HStack order, so
            // the user keeps eye contact with the most recent card.
            withAnimation(.easeInOut(duration: 0.45)) {
                allPrinted = true
                slotVisible = false
                captionVisible = false
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    /// Drives one ticket through the full print sequence. Settle and
    /// the next-ticket reset are merged into a single transaction at
    /// the end, which keeps the visual state continuous across the
    /// in-flight → settled handoff.
    @MainActor
    private func runPrint(for idx: Int) async {
        // Reset in-flight state for this ticket — non-animated so the
        // new ticket starts off-screen above the slot rather than
        // springing back from the previous ticket's settled state.
        applyWithoutAnimation {
            currentEmerge = 0
            currentFlipped = false
            currentSlamLift = false
        }

        await sleep(0.20)

        // Stutter — four small jumps engaging the printer teeth.
        for p in [0.05, 0.07, 0.10, 0.13] {
            withAnimation(.easeOut(duration: 0.04)) { currentEmerge = p }
            tickHaptic(intensity: 0.55)
            await sleep(0.075)
        }
        await sleep(0.05)

        // Smooth feed — 13 % → 100 %.
        withAnimation(.easeOut(duration: 0.85)) { currentEmerge = 1.0 }
        await tickHaptic(after: 0.20, intensity: 0.40)
        await tickHaptic(after: 0.25, intensity: 0.45)
        await tickHaptic(after: 0.25, intensity: 0.50)
        await sleep(0.15) // remaining of the 0.85 s feed window

        // Flip 90° → 0° for horizontal tickets, scale springs from 0.6
        // back to 1.0 alongside the rotation so the ticket grows into
        // its full size as it lands flat.
        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
            currentFlipped = true
        }
        await sleep(0.30)

        // Slam — medium haptic + 3 % overshoot springing back.
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.easeOut(duration: 0.08)) { currentSlamLift = true }
        await sleep(0.08)
        withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
            currentSlamLift = false
        }
        await sleep(0.22)

        // Settle + reset for next ticket — atomic to avoid the in-flight
        // ticket flickering between idx and idx+1 rendering.
        applyWithoutAnimation {
            settledCount = idx + 1
            currentEmerge = 0
            currentFlipped = false
            currentSlamLift = false
        }
    }

    // MARK: - Helpers

    private func applyWithoutAnimation(_ block: () -> Void) {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t, block)
    }

    private func sleep(_ seconds: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    private func tickHaptic(intensity: CGFloat) {
        let gen = UIImpactFeedbackGenerator(style: .rigid)
        gen.prepare()
        gen.impactOccurred(intensity: intensity)
    }

    private func tickHaptic(after seconds: TimeInterval, intensity: CGFloat) async {
        await sleep(seconds)
        tickHaptic(intensity: intensity)
    }
}

// MARK: - Top-only clip

/// Clips the top edge of the print stack so an emerging ticket appears
/// to come out from behind the slot bar, but leaves the sides and
/// bottom open — a rotated horizontal ticket can extend past the
/// carousel's natural height during print without being sliced. The
/// previewCard's own clipShape handles bounding any spill at the card
/// boundary.
private struct PrintTopClipShape: Shape {
    let topInset: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(CGRect(
            x: rect.minX - 1000,
            y: rect.minY + topInset,
            width: rect.width + 2000,
            height: rect.height + 2000 - topInset
        ))
    }
}

// MARK: - Cone landing

/// Final transform a ticket settles at, relative to the carousel's
/// visual center. The carousel's slot sits above this center; the cone
/// vertex is at the slot and opens downward, so dy is biased slightly
/// positive (below center) and dx widens with depth.
private struct Landing {
    var dx: CGFloat
    var dy: CGFloat
    var rotation: Double

    static let zero = Landing(dx: 0, dy: 0, rotation: 0)

    /// Picks a deterministic random center inside the cone for ticket
    /// `seed`. Same seed → same landing across re-renders, so swipes
    /// don't shuffle the pile.
    static func cone(seed: Int) -> Landing {
        var rng = SeededRNG(seed: seed)
        let dy = CGFloat.random(in: -12...28, using: &rng)
        // Cone radius scales with depth from the slot — deeper landings
        // can drift further sideways.
        let depth = max(dy + 60, 10)
        let xRange = depth * 0.30
        let dx = CGFloat.random(in: -xRange...xRange, using: &rng)
        let rotation = Double.random(in: -10...10, using: &rng)
        return Landing(dx: dx, dy: dy, rotation: rotation)
    }
}

private struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: Int) {
        let mixed = UInt64(bitPattern: Int64(seed)) &* 0x9E3779B97F4A7C15 &+ 0xC0FFEE
        self.state = mixed == 0 ? 0x9E3779B97F4A7C15 : mixed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
