//
//  SquareRenderView.swift
//  Lumoria App
//
//  Off-screen composition for the Square (1080×1080) social export.
//  Matches Figma frames 1107:25828 (vertical ticket) and 1774:85646
//  (horizontal ticket).
//
//  Layout:
//    - White canvas.
//    - Gray-50 rounded-64 frame at (32, 32) 1016 × 1016.
//    - Ticket centered inside the gray frame.
//        · Vertical ticket: 520 × 910
//        · Horizontal ticket: 910 × 520
//

import SwiftUI

struct SquareRenderView: View {

    let ticket: Ticket

    private let canvas = CGSize(width: 1080, height: 1080)

    private let grayFrameOrigin = CGPoint(x: 32, y: 32)
    private let grayFrameSize   = CGSize(width: 1016, height: 1016)
    private let cornerRadius: CGFloat = 64

    private var ticketAspect: CGFloat {
        ticket.orientation == .horizontal ? 455.0 / 260.0 : 260.0 / 455.0
    }

    private var ticketSize: CGSize {
        ticket.orientation == .horizontal
            ? CGSize(width: 910, height: 520)
            : CGSize(width: 520, height: 910)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white

            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.Background.elevated)

                TicketPreview(ticket: ticket)
                    .aspectRatio(ticketAspect, contentMode: .fit)
                    .frame(width: ticketSize.width, height: ticketSize.height)
                    .environment(\.ticketFillsNotchCutouts, false)
            }
            .frame(width: grayFrameSize.width, height: grayFrameSize.height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .offset(x: grayFrameOrigin.x, y: grayFrameOrigin.y)
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

#Preview("Square — horizontal") {
    SquareRenderView(ticket: previewHorizontal)
        .scaleEffect(0.3)
        .frame(width: 324, height: 324)
}

#Preview("Square — vertical") {
    SquareRenderView(ticket: previewVertical)
        .scaleEffect(0.3)
        .frame(width: 324, height: 324)
}
