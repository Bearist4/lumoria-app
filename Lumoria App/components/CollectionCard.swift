//
//  MemoryCard.swift
//  Lumoria App
//
//  Centerpiece "folder" card that holds up to 5 ticket previews stacked
//  like a deck. The first 5 tickets fill from the top (index 0 = topmost).
//  Below the card: a title + subtitle label row.
//

import SwiftUI

// MARK: - Slot sizing

/// Sizing helpers for tickets rendered inside a `MemoryCard` slot.
enum MemoryCardSlot {
    /// Horizontal ticket aspect (455 × 260 in template space).
    private static let horizontalAspect: CGFloat = 455.0 / 260.0

    /// Applies the right frame for a ticket preview inside a memory card
    /// slot. Horizontal tickets get `.frame(width: 160)` and let the slot's
    /// 70pt height-limit the aspect-fit render. Vertical tickets are given
    /// an explicit width AND height (≈91.43 × 160) so their
    /// `aspectRatio(.fit)` is not shrunk by the slot's 70pt height — the
    /// overflowing bottom is clipped by the slot mask. Result: vertical
    /// ticket width matches horizontal ticket's natural height.
    @ViewBuilder
    static func frameForSlot<V: View>(
        _ content: V,
        orientation: TicketOrientation
    ) -> some View {
        switch orientation {
        case .horizontal:
            content.frame(width: 160)
        case .vertical:
            let w: CGFloat = 160 / horizontalAspect   // ≈ 91.43
            let h: CGFloat = 160
            content.frame(width: w, height: h)
        }
    }
}

// MARK: - State

/// Display state of a memory card.
enum MemoryCardState {
    /// Normal — labels shown, soft bottom glow.
    case normal
    /// Empty (no labels, bare frame).
    case empty
    /// Locked / shared-pending — lock badge top-right.
    case locked
    /// "Create new" — plus badge centered near the bottom.
    case new
    /// Success / added — green checkmark badge top-right.
    case added
    /// Selectable for removal — red `folder.badge.minus` badge near bottom.
    case removable
    /// Pre-delete — red frosted overlay with folder-delete icon.
    case deleting
}

// MARK: - View

/// A memory thumbnail card.
///
/// The card renders 5 stacked ticket "slots." Each slot is a soft gradient
/// strip with a bottom rounded edge; successive slots overlap the previous
/// by ~42pt so the top of each slot peeks out — creating the stacked deck
/// effect. Filled slots (index < filledCount) show a caller-supplied
/// preview view on top of the slot; unfilled slots render just the gradient.
struct MemoryCard<SlotContent: View>: View {

    // MARK: Content

    let title: String?
    let subtitle: String?
    let state: MemoryCardState
    /// Optional emoji shown to the left of the title under the card.
    let emoji: String?
    /// How many slots (0...5) should render a preview view. Top-down.
    let filledCount: Int
    /// Palette family (e.g. "Blue", "Green") used for the bottom glow.
    /// Resolves to `Colors/<family>/300` at runtime.
    let colorFamily: String?
    /// Stable seed used to scatter ticket previews horizontally inside
    /// their slots. Same memory → same jitter across renders. 0 by
    /// default keeps existing call sites compatible.
    let cardSeed: UInt64
    /// Delay (seconds) before the card plays its first-load intro:
    /// fade + rise from below, then tickets pop into their slots.
    /// `nil` skips the intro and renders steady (default — keeps
    /// callers like TicketDetailsCard / previews unchanged).
    let introDelay: Double?
    let slotPreview: (Int) -> SlotContent

    // MARK: Sizes (from Figma)

    // Card frame.
    private let cardWidth:   CGFloat = 184
    private let cardHeight:  CGFloat = 260
    private let cardCorner:  CGFloat = 20
    private let pad:         CGFloat = 12

    // Atomic `_TicketSlot` component in Figma is 184 × 80 with 12pt bottom
    // corners. Here the slot is inset by `pad` on each side so it fits
    // inside the card with breathing room — that yields a ~0.87 scale,
    // which is applied uniformly to height / overlap / corner to preserve
    // Figma proportions.
    private var slotWidth:   CGFloat { cardWidth - pad * 2 }          // 160
    private var slotHeight:  CGFloat { 80  * slotScale }              // ≈ 69.6
    private var slotOverlap: CGFloat { 48  * slotScale }              // ≈ 41.7
    private var slotCorner:  CGFloat { 12  * slotScale }              // ≈ 10.4
    private var slotBorder:  CGFloat { 1   * slotScale }              // ≈ 0.87
    private var slotScale:   CGFloat { slotWidth / 184 }

    // MARK: Init

    init(
        title: String? = nil,
        subtitle: String? = nil,
        state: MemoryCardState = .normal,
        emoji: String? = nil,
        filledCount: Int = 0,
        colorFamily: String? = nil,
        cardSeed: UInt64 = 0,
        introDelay: Double? = nil,
        @ViewBuilder slotPreview: @escaping (Int) -> SlotContent
    ) {
        self.title = title
        self.subtitle = subtitle
        self.state = state
        self.emoji = emoji
        self.filledCount = max(0, min(5, filledCount))
        self.colorFamily = colorFamily
        self.cardSeed = cardSeed
        self.introDelay = introDelay
        self.slotPreview = slotPreview
        // Single-state intro: false = pre-animation pose, true = final
        // pose. Animations are layered on top via `.animation(...,
        // value:)` modifiers below — that lets SwiftUI's animation
        // engine schedule the springs (with their delays) at frame
        // level instead of us spinning up Tasks with `Task.sleep`,
        // which creates a swarm of concurrent animation drivers when
        // many cards intro at once and chokes the navigation push.
        _introDone = State(initialValue: introDelay == nil)
    }

    // MARK: Intro state

    /// Animates from pre-pose (hidden, lowered, tickets shrunk) to
    /// final pose. `.animation(value: introDone)` modifiers downstream
    /// pick up the change and apply per-element springs / delays.
    @State private var introDone: Bool

    // MARK: Body

    /// Intrinsic height of the card + labels at reference width (184pt).
    /// Used with `aspectRatio` so the card scales to fit whatever width the
    /// parent allocates while keeping its Figma proportions.
    private var referenceHeight: CGFloat {
        state == .empty ? cardHeight : cardHeight + Spacing.s3 + 44
    }

    var body: some View {
        GeometryReader { proxy in
            let scale = max(0, proxy.size.width / cardWidth)
            ZStack(alignment: .topLeading) {
                Color.clear
                VStack(spacing: state == .empty ? 0 : Spacing.s3) {
                    cardView
                    if state != .empty {
                        labelsView
                    }
                }
                .frame(width: cardWidth)
                .scaleEffect(scale, anchor: .topLeading)
            }
        }
        .aspectRatio(cardWidth / referenceHeight, contentMode: .fit)
        .opacity(introDone ? 1 : 0)
        .offset(y: introDone ? 0 : 24)
        // Card-level spring with the caller's stagger delay baked in.
        .animation(
            .spring(response: 0.55, dampingFraction: 0.78)
                .delay(introDelay ?? 0),
            value: introDone
        )
        .task { introDone = true }
    }

    // MARK: - Card

    private var cardView: some View {
        ZStack(alignment: .top) {
            // 3% black tint per the latest Figma (Opacity/Black/inverse/3),
            // not the elevated #fafafa fill we used before — slots inside
            // now get to drag the card bg darker via their own gradients.
            RoundedRectangle(cornerRadius: cardCorner)
                .fill(Color.Background.fieldFill)

            if showsGlow { glow }

            ticketStack
                .padding(.top, pad)

            stateOverlay
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: cardCorner))
    }

    /// States that show the palette-colored bottom aura behind the tickets.
    private var showsGlow: Bool {
        switch state {
        case .normal, .locked, .added, .removable: return true
        case .empty, .new, .deleting:              return false
        }
    }

    // MARK: Ticket deck

    private var ticketStack: some View {
        // Each slot is its own clipped container: gradient + ticket preview
        // composed inside the slot's shape, so the ticket is masked by the
        // slot (rounded bottom corners, flat top) rather than bleeding past
        // its bounds. Slot N+1 is drawn on top of slot N and covers the
        // lower part of slot N's gradient.
        ZStack(alignment: .top) {
            ForEach(0..<5, id: \.self) { idx in
                ZStack(alignment: .top) {
                    slotGradient
                    if idx < filledCount {
                        slotPreview(idx)
                            .scaleEffect(
                                previewScale * (introDone ? 1 : 0.6),
                                anchor: .top
                            )
                            // Ticket pop runs slightly after the card
                            // has begun rising — a 160 ms offset on
                            // top of the card's stagger delay. Same
                            // `introDone` toggle drives both, so
                            // SwiftUI animates them on a single
                            // CADisplayLink tick instead of via two
                            // separate Tasks.
                            .animation(
                                .spring(response: 0.42, dampingFraction: 0.66)
                                    .delay((introDelay ?? 0) + 0.16),
                                value: introDone
                            )
                            // Drop shadow behind each ticket so the
                            // slot above lifts off the slot below.
                            // Clipped to the slot bounds by the
                            // enclosing `clipShape`.
                            .shadow(
                                color: Color.black.opacity(0.22),
                                radius: 6,
                                x: 0,
                                y: 3
                            )
                            .allowsHitTesting(false)
                            // Slight horizontal jitter so tickets in
                            // the pile don't all line up dead-centre.
                            // Bound by `slotJitterRange` so they can't
                            // graze the slot edge.
                            .offset(x: slotJitterX(idx: idx), y: previewInset)
                    }
                }
                .frame(width: slotWidth, height: slotHeight, alignment: .top)
                .clipShape(slotShape)
                .offset(y: slotY(idx))
            }
        }
        .frame(width: slotWidth, height: totalStackHeight, alignment: .top)
    }

    private var slotShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            bottomLeadingRadius: slotCorner,
            bottomTrailingRadius: slotCorner
        )
    }

    // Vertical offset (within the stack) for slot `idx`'s top edge.
    private func slotY(_ idx: Int) -> CGFloat {
        CGFloat(idx) * (slotHeight - slotOverlap)
    }

    /// Peek distance from a slot's top edge to its ticket preview.
    /// Lower than the Figma's 8.7pt baseline so the ticket sits a bit
    /// further down inside the slot — gives the upper edge a stronger
    /// "tab" feel and frees up vertical room for the ticket's drop
    /// shadow to read.
    private var previewInset: CGFloat { 12 }

    /// Ticket preview scale inside the slot. Slightly under 1 so the
    /// ticket is a few points narrower than the slot — leaves margin
    /// for the random horizontal jitter applied per slot without ever
    /// reaching the slot edge.
    private var previewScale: CGFloat { 0.96 }

    /// Half of the slot's free horizontal margin after `previewScale`
    /// — capped so the random jitter never visibly crops the ticket.
    /// `slotWidth × (1 - previewScale) / 2` ≈ 3.2pt on a 160pt slot.
    private var slotJitterRange: CGFloat {
        max(0, slotWidth * (1 - previewScale) / 2)
    }

    /// Deterministic horizontal jitter for ticket at `idx`. Stable
    /// across renders (so swipes and re-loads don't reshuffle the
    /// pile) and seeded by the optional `cardSeed` so different
    /// memories don't all jitter the same way at idx 0.
    private func slotJitterX(idx: Int) -> CGFloat {
        guard slotJitterRange > 0 else { return 0 }
        let seed = (cardSeed &* 2_654_435_761) &+ UInt64(idx) &+ 1
        var rng = SeededJitter(seed: seed)
        return CGFloat.random(in: -slotJitterRange...slotJitterRange, using: &rng)
    }

    /// Total layout height of the 5-slot stack with overlap.
    private var totalStackHeight: CGFloat {
        slotHeight + 4 * (slotHeight - slotOverlap)
    }

    private var slotGradient: some View {
        // Per the latest Figma _TicketSlot: just a transparent →
        // Opacity/Black/inverse/3 gradient over whatever's beneath
        // (the card's own 3 % tint) plus a 5 %-black bottom hairline.
        // No opaque underlay this time — each slot is already
        // clipShape'd to its own bounds, so prior slots' content can't
        // bleed through.
        LinearGradient(
            colors: [Color.clear, Color.Background.fieldFill],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay {
            // Bottom-only 1pt INSIDE stroke that traces the slot's
            // rounded bl/br corners. Matches Figma `_TicketSlot`.
            slotShape
                .strokeBorder(Color.Border.subtle, lineWidth: slotBorder)
                .mask {
                    VStack(spacing: 0) {
                        Color.clear
                        Color.black.frame(height: slotCorner + slotBorder)
                    }
                }
        }
    }

    // MARK: - State overlay

    @ViewBuilder
    private var stateOverlay: some View {
        switch state {

        case .normal, .empty:
            EmptyView()

        case .locked:
            iconBadge(
                system: "lock.fill",
                bg: Color.Button.Primary.Background.default,
                fg: Color.Button.Primary.Label.default
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(pad)

        case .new:
            iconBadge(
                system: "plus",
                bg: Color.Button.Secondary.Background.default,
                fg: Color.Text.primary
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 36)

        case .added:
            iconBadge(
                system: "checkmark",
                bg: Color("Colors/Green/500"),
                fg: Color.Text.OnColor.white
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(pad)

        case .removable:
            iconBadge(
                system: "folder.badge.minus",
                bg: Color.Button.Danger.Background.default,
                fg: Color.Button.Danger.Label.default
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 36)

        case .deleting:
            ZStack {
                Color.Button.Danger.Background.default
                    .opacity(0.3)
                    .background(.ultraThinMaterial)
                Circle()
                    .fill(Color.Button.Danger.Background.default)
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: "folder.badge.minus")
                            .font(.title3)
                            .foregroundStyle(Color.Button.Danger.Label.default)
                    }
            }
        }
    }

    /// 300-weight palette color used for the card's bottom glow.
    private var glowColor: Color {
        if let family = colorFamily {
            return Color("Colors/\(family)/300")
        }
        return Color(hex: "6F9BFF")
    }

    /// Shared bottom aura rendered underneath state badges so selecting or
    /// tagging a card doesn't wipe out the palette color.
    private var glow: some View {
        RadialGradient(
            colors: [glowColor.opacity(0.55), .clear],
            center: .bottom,
            startRadius: 0,
            endRadius: 140
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .allowsHitTesting(false)
    }

    private func iconBadge(system: String, bg: Color, fg: Color) -> some View {
        Circle()
            .fill(bg)
            .frame(width: 32, height: 32)
            .overlay {
                Image(systemName: system)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(fg)
            }
    }

    // MARK: - Labels

    private var labelsView: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                if let emoji = emoji, !emoji.isEmpty {
                    Text(emoji)
                        .font(.body)
                }
                Text(resolvedTitle)
                    .font(.body)
                    .foregroundStyle(Color.Text.secondary)
                    .lineLimit(1)
            }
            Text(resolvedSubtitle)
                .font(.footnote)
                .foregroundStyle(Color.Text.tertiary)
                .lineLimit(1)
        }
        .multilineTextAlignment(.center)
        .frame(width: cardWidth)
    }

    private var resolvedTitle: String {
        if let title = title { return title }
        switch state {
        case .new:    return String(localized: "Create")
        case .locked: return String(localized: "New memory")
        default:      return String(localized: "Memory name")
        }
    }

    private var resolvedSubtitle: String {
        if let subtitle = subtitle { return subtitle }
        switch state {
        case .new:    return String(localized: "New memory")
        case .locked: return String(localized: "Invite pending")
        default:      return String(localized: "0 tickets")
        }
    }
}

// MARK: - Seeded RNG (slot jitter)

/// splitmix64 wrapper used for the per-slot horizontal jitter — same
/// shape as the one in the print carousel. Stable across renders
/// because `MemoryCard` re-seeds it from `(cardSeed, idx)` each call.
private struct SeededJitter: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// MARK: - No-preview convenience

extension MemoryCard where SlotContent == EmptyView {
    init(
        title: String? = nil,
        subtitle: String? = nil,
        state: MemoryCardState = .normal,
        emoji: String? = nil,
        filledCount: Int = 0,
        colorFamily: String? = nil,
        cardSeed: UInt64 = 0
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            state: state,
            emoji: emoji,
            filledCount: filledCount,
            colorFamily: colorFamily,
            cardSeed: cardSeed,
            slotPreview: { _ in EmptyView() }
        )
    }
}

// MARK: - Preview

#Preview("Memory states") {
    ScrollView {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 24
        ) {
            MemoryCard(
                title: "Japan 2026",
                subtitle: "2 tickets",
                state: .normal,
                emoji: "🗾",
                filledCount: 2
            )

            MemoryCard(state: .empty)

            MemoryCard(
                title: "New memory",
                subtitle: "Invite pending",
                state: .locked
            )

            MemoryCard(state: .new)

            MemoryCard(
                title: "Summer trip",
                subtitle: "2 tickets",
                state: .added,
                emoji: "🌴",
                filledCount: 1
            )

            MemoryCard(
                title: "Old memory",
                subtitle: "2 tickets",
                state: .deleting,
                filledCount: 2
            )
        }
        .padding(24)
    }
    .background(Color.Background.default)
}

#Preview("With Afterglow ticket previews") {
    MemoryCard(
        title: "Summer trips",
        subtitle: "1 ticket",
        state: .normal,
        emoji: "🌴",
        filledCount: 1
    ) { _ in
        AfterglowTicketView(ticket: AfterglowTicket(
            airline: "Airline",
            flightNumber: "AG 421",
            origin: "CDG",
            originCity: "Paris",
            destination: "LAX",
            destinationCity: "Los Angeles",
            date: "3 May 2026",
            gate: "F32",
            seat: "1A",
            boardingTime: "09:40"
        ))
        // scale to slot width: ticket is 455 wide, slot is 160 wide
        .frame(width: 160)
    }
    .padding(24)
    .background(Color.Background.default)
}
