//
//  InstagramRenderView.swift
//  Lumoria App
//
//  Off-screen composition for the Instagram vertical feed (1080×1350)
//  social export. Matches Figma frames 1107:25830 (vertical ticket)
//  and 1774:85648 (horizontal ticket).
//
//  Layout (canvas-absolute coordinates):
//    - White canvas.
//    - Top gray-50 frame:    (24, 24)  1032 × 773  radius 64
//        · Vertical ticket:  (321, 45) 390 × 683  (centered horizontally)
//        · Horizontal ticket: (64, 48) 1183 × 676 (overflows right, clipped)
//    - Bottom gray-50 frame: (24, 821) 1032 × 505  radius 64 (decorative)
//

import SwiftUI

struct InstagramRenderView: View {

    let ticket: Ticket

    private let canvas = CGSize(width: 1080, height: 1350)

    private let padding: CGFloat = 24
    private let gap: CGFloat = 24
    private let topFrameHeight: CGFloat = 773
    private let cornerRadius: CGFloat = 64

    private var topFrameOrigin: CGPoint { CGPoint(x: padding, y: padding) }
    private var topFrameSize: CGSize {
        CGSize(width: canvas.width - padding * 2, height: topFrameHeight)
    }
    private var bottomFrameOrigin: CGPoint {
        CGPoint(x: padding, y: padding + topFrameHeight + gap)
    }
    private var bottomFrameSize: CGSize {
        let h = canvas.height - padding * 2 - gap - topFrameHeight
        return CGSize(width: canvas.width - padding * 2, height: h)
    }

    private var isVertical: Bool { ticket.orientation == .vertical }
    private var ticketAspect: CGFloat {
        isVertical ? 260.0 / 455.0 : 455.0 / 260.0
    }

    // MARK: - Top ticket (centered)

    private var topTicketSize: CGSize {
        if isVertical {
            let w: CGFloat = 390
            return CGSize(width: w, height: w / ticketAspect)
        } else {
            let w: CGFloat = 892
            return CGSize(width: w, height: w / ticketAspect)
        }
    }

    // MARK: - Bottom ticket (overflows frame, clipped)

    private let bottomTicketPadding: CGFloat = 90

    private var bottomTicketSize: CGSize {
        if isVertical {
            let w: CGFloat = 780
            return CGSize(width: w, height: w / ticketAspect)
        } else {
            let w = bottomFrameSize.width
            return CGSize(width: w, height: w / ticketAspect)
        }
    }

    private var bottomTicketCenter: CGPoint {
        let x = bottomFrameSize.width / 2
        let y: CGFloat
        if isVertical {
            // Bottom-aligned: ticket bottom sits 90pt above frame bottom.
            y = bottomFrameSize.height - bottomTicketPadding - bottomTicketSize.height / 2
        } else {
            // Top-aligned: ticket top sits 90pt below frame top.
            y = bottomTicketPadding + bottomTicketSize.height / 2
        }
        return CGPoint(x: x, y: y)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white

            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.Background.elevated)

                TicketPreview(ticket: ticket)
                    .aspectRatio(ticketAspect, contentMode: .fit)
                    .frame(width: topTicketSize.width, height: topTicketSize.height)
                    .environment(\.ticketFillsNotchCutouts, false)
            }
            .frame(width: topFrameSize.width, height: topFrameSize.height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .offset(x: topFrameOrigin.x, y: topFrameOrigin.y)

            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.Background.elevated)

                TicketPreview(ticket: ticket)
                    .aspectRatio(ticketAspect, contentMode: .fit)
                    .frame(width: bottomTicketSize.width, height: bottomTicketSize.height)
                    .environment(\.ticketFillsNotchCutouts, false)
                    .position(x: bottomTicketCenter.x, y: bottomTicketCenter.y)
            }
            .frame(width: bottomFrameSize.width, height: bottomFrameSize.height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .offset(x: bottomFrameOrigin.x, y: bottomFrameOrigin.y)
        }
        .frame(width: canvas.width, height: canvas.height)
        .clipped()
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

#Preview("Instagram — horizontal") {
    InstagramRenderView(ticket: previewHorizontal)
        .scaleEffect(0.24)
        .frame(width: 259, height: 324)
}

#Preview("Instagram — vertical") {
    InstagramRenderView(ticket: previewVertical)
        .scaleEffect(0.24)
        .frame(width: 259, height: 324)
}
