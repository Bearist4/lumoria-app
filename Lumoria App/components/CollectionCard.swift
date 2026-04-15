//
//  CollectionCard.swift
//  Lumoria App
//
//  Centerpiece "folder" card that holds up to 5 ticket previews stacked
//  like a deck. The first 5 tickets fill from the top (index 0 = topmost).
//  Below the card: a title + subtitle label row.
//

import SwiftUI

// MARK: - State

/// Display state of a collection card.
enum CollectionCardState {
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

/// A collection thumbnail card.
///
/// The card renders 5 stacked ticket "slots." Each slot is a soft gradient
/// strip with a bottom rounded edge; successive slots overlap the previous
/// by ~42pt so the top of each slot peeks out — creating the stacked deck
/// effect. Filled slots (index < filledCount) show a caller-supplied
/// preview view on top of the slot; unfilled slots render just the gradient.
struct CollectionCard<SlotContent: View>: View {

    // MARK: Content

    let title: String?
    let subtitle: String?
    let state: CollectionCardState
    /// How many slots (0...5) should render a preview view. Top-down.
    let filledCount: Int
    /// Palette family (e.g. "Blue", "Green") used for the bottom glow.
    /// Resolves to `Colors/<family>/300` at runtime.
    let colorFamily: String?
    let slotPreview: (Int) -> SlotContent

    // MARK: Sizes (from Figma)

    private let cardWidth:   CGFloat = 184
    private let cardHeight:  CGFloat = 260
    private let slotWidth:   CGFloat = 160
    private let slotHeight:  CGFloat = 69.565
    private let slotOverlap: CGFloat = 41.739
    private let slotCorner:  CGFloat = 10.435
    private let cardCorner:  CGFloat = 20
    private let pad:         CGFloat = 12

    // MARK: Init

    init(
        title: String? = nil,
        subtitle: String? = nil,
        state: CollectionCardState = .normal,
        filledCount: Int = 0,
        colorFamily: String? = nil,
        @ViewBuilder slotPreview: @escaping (Int) -> SlotContent
    ) {
        self.title = title
        self.subtitle = subtitle
        self.state = state
        self.filledCount = max(0, min(5, filledCount))
        self.colorFamily = colorFamily
        self.slotPreview = slotPreview
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: state == .empty ? 0 : Spacing.s3) {
            cardView
            if state != .empty {
                labelsView
            }
        }
        .frame(width: cardWidth)
    }

    // MARK: - Card

    private var cardView: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: cardCorner)
                .fill(Color.Background.elevated)

            ticketStack
                .padding(.top, pad)

            stateOverlay
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: cardCorner))
    }

    // MARK: Ticket deck

    private var ticketStack: some View {
        // Manual ZStack so we can interleave slot gradients with their ticket
        // previews and control z-order precisely: gradient(0), preview(0),
        // gradient(1), preview(1), ..., each offset to the right y.
        // Later children render on top, so slot N+1 covers preview N's overflow.
        ZStack(alignment: .top) {
            ForEach(0..<5, id: \.self) { idx in
                slotGradient
                    .offset(y: slotY(idx))

                if idx < filledCount {
                    slotPreview(idx)
                        // Scale each ticket down ~15% so it reads as "inserted"
                        // into the slot with breathing room on the sides.
                        .scaleEffect(previewScale, anchor: .top)
                        .allowsHitTesting(false)
                        .offset(y: slotY(idx) + previewInset)
                }
            }
        }
        .frame(width: slotWidth, height: totalStackHeight, alignment: .top)
    }

    // Vertical offset (within the stack) for slot `idx`'s top edge.
    private func slotY(_ idx: Int) -> CGFloat {
        CGFloat(idx) * (slotHeight - slotOverlap)
    }

    /// Peek distance from a slot's top edge to its ticket preview — matches
    /// the Figma mini-ticket's `top: 8.7pt` positioning.
    private var previewInset: CGFloat { 8 }

    /// Scale applied to each preview so the ticket looks "inserted" into the
    /// slot with a small margin. 0.85 ≈ 15% smaller.
    private var previewScale: CGFloat { 0.85 }

    /// Total layout height of the 5-slot stack with overlap.
    private var totalStackHeight: CGFloat {
        slotHeight + 4 * (slotHeight - slotOverlap)
    }

    private var slotGradient: some View {
        // Opaque card-bg under the translucent gradient — turns the slot into
        // a "pocket": whatever sits beneath it in z-order (i.e. the bottom of
        // the previous slot's ticket) is hidden cleanly instead of ghosting
        // through the gradient.
        Color.Background.elevated
            .overlay {
                LinearGradient(
                    colors: [Color.white.opacity(0), Color.black.opacity(0.03)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(width: slotWidth, height: slotHeight)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.black.opacity(0.05))
                    .frame(height: 0.87)
            }
            .clipShape(
                UnevenRoundedRectangle(
                    bottomLeadingRadius: slotCorner,
                    bottomTrailingRadius: slotCorner
                )
            )
    }

    // MARK: - State overlay

    @ViewBuilder
    private var stateOverlay: some View {
        switch state {

        case .normal:
            glow

        case .empty:
            EmptyView()

        case .locked:
            ZStack(alignment: .topTrailing) {
                glow
                iconBadge(
                    system: "lock.fill",
                    bg: Color.Button.Primary.Background.default,
                    fg: Color.Button.Primary.Label.default
                )
                .padding(pad)
            }

        case .new:
            iconBadge(
                system: "plus",
                bg: Color.Button.Secondary.Background.default,
                fg: Color.Text.primary
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 36)

        case .added:
            ZStack(alignment: .topTrailing) {
                glow
                iconBadge(
                    system: "checkmark",
                    bg: Color("Colors/Green/500"),
                    fg: Color.Text.OnColor.white
                )
                .padding(pad)
            }

        case .removable:
            ZStack(alignment: .bottom) {
                glow
                iconBadge(
                    system: "folder.badge.minus",
                    bg: Color.Button.Danger.Background.default,
                    fg: Color.Button.Danger.Label.default
                )
                .padding(.bottom, 36)
            }

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
                            .font(.system(size: 20, weight: .semibold))
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
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(fg)
            }
    }

    // MARK: - Labels

    private var labelsView: some View {
        VStack(spacing: 4) {
            Text(resolvedTitle)
                .font(.system(size: 17, weight: .regular))
                .tracking(-0.43)
                .foregroundStyle(Color.Text.secondary)
                .lineLimit(1)
            Text(resolvedSubtitle)
                .font(.system(size: 13, weight: .regular))
                .tracking(-0.08)
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
        case .locked: return "New collection"
        default:      return "Collection Name"
        }
    }

    private var resolvedSubtitle: String {
        if let subtitle = subtitle { return subtitle }
        switch state {
        case .new:    return "New collection"
        case .locked: return "Invite pending"
        default:      return "0 tickets"
        }
    }
}

// MARK: - No-preview convenience

extension CollectionCard where SlotContent == EmptyView {
    init(
        title: String? = nil,
        subtitle: String? = nil,
        state: CollectionCardState = .normal,
        filledCount: Int = 0,
        colorFamily: String? = nil
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            state: state,
            filledCount: filledCount,
            colorFamily: colorFamily,
            slotPreview: { _ in EmptyView() }
        )
    }
}

// MARK: - Preview

#Preview("Collection states") {
    ScrollView {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 24
        ) {
            CollectionCard(
                title: "Collection Name",
                subtitle: "2 tickets",
                state: .normal,
                filledCount: 2
            )

            CollectionCard(state: .empty)

            CollectionCard(
                title: "New collection",
                subtitle: "Invite pending",
                state: .locked
            )

            CollectionCard(state: .new)

            CollectionCard(
                title: "Collection Name",
                subtitle: "2 tickets",
                state: .added,
                filledCount: 1
            )

            CollectionCard(
                title: "Collection Name",
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
    CollectionCard(
        title: "Summer trips",
        subtitle: "1 ticket",
        state: .normal,
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
