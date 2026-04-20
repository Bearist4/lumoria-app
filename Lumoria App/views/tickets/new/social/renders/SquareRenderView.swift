//
//  SquareRenderView.swift
//  Lumoria App
//
//  Off-screen composition for the Square (1080×1080) social export.
//  Ticket centered on a white canvas.
//
//  Figma:
//    Vertical ticket:   node 1107:25828
//    Horizontal ticket: node 1774:85646
//

import SwiftUI

struct SquareRenderView: View {

    let ticket: Ticket

    private let canvas = CGSize(width: 1080, height: 1080)
    private let ticketBoundRatio: CGFloat = 0.82

    private var ticketAspect: CGFloat {
        ticket.orientation == .horizontal ? 455.0 / 260.0 : 260.0 / 455.0
    }

    private var ticketSize: CGSize {
        let shorter = min(canvas.width, canvas.height) * ticketBoundRatio
        switch ticket.orientation {
        case .horizontal:
            return CGSize(width: shorter, height: shorter / ticketAspect)
        case .vertical:
            return CGSize(width: shorter * ticketAspect, height: shorter)
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
