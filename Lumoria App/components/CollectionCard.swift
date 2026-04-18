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
        @ViewBuilder slotPreview: @escaping (Int) -> SlotContent
    ) {
        self.title = title
        self.subtitle = subtitle
        self.state = state
        self.emoji = emoji
        self.filledCount = max(0, min(5, filledCount))
        self.colorFamily = colorFamily
        self.slotPreview = slotPreview
    }

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
    }

    // MARK: - Card

    private var cardView: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: cardCorner)
                .fill(Color.Background.elevated)

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
                            .scaleEffect(previewScale, anchor: .top)
                            .allowsHitTesting(false)
                            .offset(y: previewInset)
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

    /// Peek distance from a slot's top edge to its ticket preview — matches
    /// the Figma mini-ticket's `top: 8.7pt` positioning.
    private var previewInset: CGFloat { 8 }

    /// Ticket preview scale inside the slot. 1.1 = 10% larger than the
    /// caller-provided size so the ticket fills the slot with a bit of
    /// bleed clipped by the slot mask.
    private var previewScale: CGFloat { 1.1 }

    /// Total layout height of the 5-slot stack with overlap.
    private var totalStackHeight: CGFloat {
        slotHeight + 4 * (slotHeight - slotOverlap)
    }

    private var slotGradient: some View {
        // Opaque card-bg under the translucent gradient — turns the slot into
        // a "pocket": whatever sits beneath it in z-order (i.e. the bottom of
        // the previous slot's ticket) is hidden cleanly instead of ghosting
        // through the gradient. The enclosing slot clipShape masks the shape.
        Color.Background.elevated
            .overlay {
                LinearGradient(
                    colors: [Color.clear, Color.Background.fieldFill],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.Border.subtle)
                    .frame(height: slotBorder)
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
        case .new:    return "Create"
        case .locked: return "New memory"
        default:      return "Memory name"
        }
    }

    private var resolvedSubtitle: String {
        if let subtitle = subtitle { return subtitle }
        switch state {
        case .new:    return String(localized: "New memory")
        case .locked: return String(localized: "Invite pending")
        default:      return "0 tickets"
        }
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
        colorFamily: String? = nil
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            state: state,
            emoji: emoji,
            filledCount: filledCount,
            colorFamily: colorFamily,
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
