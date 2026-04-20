//
//  XRenderView.swift
//  Lumoria App
//
//  Off-screen composition for the X / Twitter (720×1280) social export.
//  Matches Figma frames 1107:25829 (vertical ticket) and 1774:85645
//  (horizontal ticket).
//
//  Layout (canvas-absolute coordinates):
//    - White canvas.
//    - Gray-50 frame: (24, 24) 672 × 1232 radius 32
//        · Vertical ticket:   (76, 161) 520 × 910 (centered)
//        · Horizontal ticket: (52, 454) 568 × 325 (centered)
//

import SwiftUI

struct XRenderView: View {

    let ticket: Ticket

    private let canvas = CGSize(width: 720, height: 1280)

    private let grayFrameOrigin = CGPoint(x: 24, y: 24)
    private let grayFrameSize   = CGSize(width: 672, height: 1232)
    private let cornerRadius: CGFloat = 32

    private var ticketAspect: CGFloat {
        ticket.orientation == .horizontal ? 455.0 / 260.0 : 260.0 / 455.0
    }

    private var ticketSize: CGSize {
        ticket.orientation == .horizontal
            ? CGSize(width: 568, height: 325)
            : CGSize(width: 520, height: 910)
    }

    private var ticketOffset: CGPoint {
        ticket.orientation == .horizontal
            ? CGPoint(x: 52, y: 454)
            : CGPoint(x: 76, y: 161)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.Background.elevated)

                TicketPreview(ticket: ticket)
                    .aspectRatio(ticketAspect, contentMode: .fit)
                    .frame(width: ticketSize.width, height: ticketSize.height)
                    .environment(\.ticketFillsNotchCutouts, false)
                    .offset(x: ticketOffset.x, y: ticketOffset.y)
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

#Preview("X — horizontal") {
    XRenderView(ticket: previewHorizontal)
        .scaleEffect(0.25)
        .frame(width: 180, height: 320)
}

#Preview("X — vertical") {
    XRenderView(ticket: previewVertical)
        .scaleEffect(0.25)
        .frame(width: 180, height: 320)
}
