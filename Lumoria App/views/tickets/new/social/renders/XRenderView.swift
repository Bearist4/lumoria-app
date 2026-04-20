//
//  XRenderView.swift
//  Lumoria App
//
//  Off-screen composition for the X / Twitter (720×1280) social export.
//  Ticket centered on a white canvas — the vertical canvas gives
//  vertical tickets room to breathe and a narrow hero for horizontal
//  tickets.
//
//  Figma:
//    Vertical ticket:   node 1107:25829
//    Horizontal ticket: node 1774:85645
//

import SwiftUI

struct XRenderView: View {

    let ticket: Ticket

    private let canvas = CGSize(width: 720, height: 1280)

    private var ticketAspect: CGFloat {
        ticket.orientation == .horizontal ? 455.0 / 260.0 : 260.0 / 455.0
    }

    private var ticketSize: CGSize {
        switch ticket.orientation {
        case .horizontal:
            let w = canvas.width * 0.88
            return CGSize(width: w, height: w / ticketAspect)
        case .vertical:
            let h = canvas.height * 0.62
            return CGSize(width: h * ticketAspect, height: h)
        }
    }

    var body: some View {
        ZStack {
            Color.white

            TicketPreview(ticket: ticket)
                .aspectRatio(ticketAspect, contentMode: .fit)
                .frame(width: ticketSize.width, height: ticketSize.height)
                .environment(\.ticketFillsNotchCutouts, false)
                .shadow(color: Color.black.opacity(0.12), radius: 32, x: 0, y: 16)
        }
        .frame(width: canvas.width, height: canvas.height)
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
