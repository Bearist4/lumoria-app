//
//  StoryRenderView.swift
//  Lumoria App
//
//  Off-screen composition for the Story (1080×1920) social export.
//  Matches Figma frames 1107:25832 (vertical ticket) and 1774:85649
//  (horizontal ticket).
//
//  Layout (canvas-absolute coordinates):
//    - Hero frame:       (32, 64)    1016 × 1323  — gray-50, radius 64,
//                                                   hero ticket centered.
//    - Bottom-left:      (32, 1419)  492 × 469/501 — gray-50, radius 64.
//                        Hero-size ticket pinned so:
//                          · Vertical ticket: bottom-left corner 60pt
//                            from the frame's bottom + left.
//                          · Horizontal ticket: top-left corner 60pt
//                            from the frame's top + left.
//                        Ticket overflows the frame and is clipped by
//                        the frame's corner radius.
//    - Bottom-right:     (556, 1419) 492 × 469/501 — gray-50, radius 64.
//                        Smaller ticket centered with an isometric
//                        transform (rotate 45°, scale y 50%).
//
//  Gray-50 = `Color.Background.elevated` in the design tokens.
//

import SwiftUI

struct StoryRenderView: View {

    let ticket: Ticket

    private let canvas = CGSize(width: 1080, height: 1920)

    private var isVertical: Bool { ticket.orientation == .vertical }
    private var ticketAspect: CGFloat {
        ticket.orientation == .horizontal ? 455.0 / 260.0 : 260.0 / 455.0
    }

    // MARK: - Frame geometry

    private let heroFrameOrigin = CGPoint(x: 32, y: 64)
    private let heroFrameSize   = CGSize(width: 1016, height: 1323)

    private let bottomLeftOrigin  = CGPoint(x: 32,  y: 1419)
    private let bottomRightOrigin = CGPoint(x: 556, y: 1419)

    private var bottomFrameSize: CGSize {
        isVertical
            ? CGSize(width: 492, height: 469)
            : CGSize(width: 492, height: 501)
    }

    // MARK: - Hero ticket

    private var heroTicketSize: CGSize {
        isVertical ? CGSize(width: 650, height: 1138)
                   : CGSize(width: 910, height: 520)
    }

    // MARK: - Bottom-left ticket (same size as hero, clipped)

    private let bottomLeftPadding: CGFloat = 60

    /// Origin of the ticket in the bottom-left frame's local coordinate
    /// space. Vertical tickets pin their bottom-left corner 60pt from the
    /// frame's bottom+left, so the ticket extends UP past the frame top.
    /// Horizontal tickets pin their top-left corner 60pt from the frame's
    /// top+left, so the ticket extends DOWN past the frame bottom.
    private var bottomLeftTicketOffset: CGPoint {
        if isVertical {
            return CGPoint(
                x: bottomLeftPadding,
                y: bottomFrameSize.height - heroTicketSize.height - bottomLeftPadding
            )
        } else {
            return CGPoint(x: bottomLeftPadding, y: bottomLeftPadding)
        }
    }

    // MARK: - Bottom-right ticket (isometric, centered)

    /// Per-user spec: 365pt wide for vertical tickets. Horizontal scales
    /// proportionally (~56% of hero width) to ~511pt.
    private var isometricTicketSize: CGSize {
        if isVertical {
            let w: CGFloat = 400
            return CGSize(width: w, height: w / ticketAspect)
        } else {
            let w: CGFloat = 700
            return CGSize(width: w, height: w / ticketAspect)
        }
    }

    private let cornerRadius: CGFloat = 64

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white

            // Hero
            grayFrame(size: heroFrameSize) {
                TicketPreview(ticket: ticket)
                    .aspectRatio(ticketAspect, contentMode: .fit)
                    .frame(width: heroTicketSize.width,
                           height: heroTicketSize.height)
                    .environment(\.ticketFillsNotchCutouts, false)
                    .position(x: heroFrameSize.width / 2,
                              y: heroFrameSize.height / 2)
            }
            .offset(x: heroFrameOrigin.x, y: heroFrameOrigin.y)

            // Bottom-left — hero-size ticket anchored per orientation, clipped
            grayFrame(size: bottomFrameSize) {
                TicketPreview(ticket: ticket)
                    .aspectRatio(ticketAspect, contentMode: .fit)
                    .frame(width: heroTicketSize.width,
                           height: heroTicketSize.height)
                    .environment(\.ticketFillsNotchCutouts, false)
                    .offset(x: bottomLeftTicketOffset.x,
                            y: bottomLeftTicketOffset.y)
                    .frame(width: bottomFrameSize.width,
                           height: bottomFrameSize.height,
                           alignment: .topLeading)
            }
            .offset(x: bottomLeftOrigin.x, y: bottomLeftOrigin.y)

            // Bottom-right — isometric ticket anchored per orientation:
            // vertical pushes toward bottom-left, horizontal toward
            // top-left (user-confirmed spec).
            grayFrame(size: bottomFrameSize) {
                TicketPreview(ticket: ticket)
                    .aspectRatio(ticketAspect, contentMode: .fit)
                    .frame(width: isometricTicketSize.width,
                           height: isometricTicketSize.height)
                    .environment(\.ticketFillsNotchCutouts, false)
                    .modifier(IsometricViewModifier())
                    .shadow(color: Color.black.opacity(0.12),
                            radius: 24, x: 0, y: 12)
                    .position(x: bottomFrameSize.width * 0.35,
                              y: isVertical
                                  ? bottomFrameSize.height * 0.65
                                  : bottomFrameSize.height * 0.35)
            }
            .offset(x: bottomRightOrigin.x, y: bottomRightOrigin.y)
        }
        .frame(width: canvas.width, height: canvas.height)
        .clipped()
    }

    // MARK: - Gray-50 rounded frame container

    @ViewBuilder
    private func grayFrame<Content: View>(
        size: CGSize,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.Background.elevated)

            content()
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - Isometric projection modifier

/// 45° rotation followed by a 50% vertical squash — classic isometric
/// projection. Applied after the ticket's intrinsic layout so the
/// bounding box is the ticket's own rect, not the transformed footprint.
private struct IsometricViewModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .rotationEffect(Angle(degrees: 45), anchor: .center)
            .scaleEffect(x: 1.0, y: 0.5, anchor: .center)
    }
}

// MARK: - Preview

private var previewHorizontal: Ticket {
    TicketsStore.sampleTickets.first { $0.orientation == .horizontal }
        ?? TicketsStore.sampleTickets[0]
}

private var previewVertical: Ticket {
    TicketsStore.sampleTickets.first { $0.orientation == .vertical }
        ?? TicketsStore.sampleTickets[0]
}

#Preview("Story — vertical") {
    StoryRenderView(ticket: previewVertical)
        .scaleEffect(0.2)
        .frame(width: 216, height: 384)
}

#Preview("Story — horizontal") {
    StoryRenderView(ticket: previewHorizontal)
        .scaleEffect(0.2)
        .frame(width: 216, height: 384)
}
