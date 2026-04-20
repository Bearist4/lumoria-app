//
//  FacebookRenderView.swift
//  Lumoria App
//
//  Off-screen composition for the Facebook vertical feed (1080×1359)
//  social export. Matches Figma frames 1107:25827 (vertical ticket)
//  and 1774:85647 (horizontal ticket).
//
//  Layout:
//    - White canvas.
//    - Hero ticket in the upper ~58%.
//    - Full-width cropped detail band in the lower ~42% — shows the
//      bottom half of the same ticket, blown up, cropped to an inset
//      rounded rectangle so the watermark + airline row are readable.
//

import SwiftUI

struct FacebookRenderView: View {

    let ticket: Ticket

    private let canvas = CGSize(width: 1080, height: 1359)

    private var ticketAspect: CGFloat {
        ticket.orientation == .horizontal ? 455.0 / 260.0 : 260.0 / 455.0
    }

    private var heroSize: CGSize {
        let maxHeight = canvas.height * 0.48
        let maxWidth  = canvas.width * 0.78
        switch ticket.orientation {
        case .horizontal:
            let w = min(maxWidth, maxHeight * ticketAspect)
            return CGSize(width: w, height: w / ticketAspect)
        case .vertical:
            let h = maxHeight
            return CGSize(width: h * ticketAspect, height: h)
        }
    }
    private let heroTopInset: CGFloat = 80

    private let detailHeight: CGFloat = 440
    private let detailSideInset: CGFloat = 40

    var body: some View {
        ZStack(alignment: .top) {
            Color.white

            // Hero
            TicketPreview(ticket: ticket)
                .aspectRatio(ticketAspect, contentMode: .fit)
                .frame(width: heroSize.width, height: heroSize.height)
                .environment(\.ticketFillsNotchCutouts, false)
                .shadow(color: Color.black.opacity(0.12), radius: 32, x: 0, y: 16)
                .position(x: canvas.width / 2,
                          y: heroTopInset + heroSize.height / 2)

            // Detail band (cropped bottom slice)
            TicketPreview(ticket: ticket)
                .aspectRatio(ticketAspect, contentMode: .fit)
                .frame(width: (canvas.width - detailSideInset * 2) * 1.6,
                       height: detailHeight * 1.6)
                .offset(y: detailHeight * 0.55)
                .frame(width: canvas.width - detailSideInset * 2,
                       height: detailHeight, alignment: .top)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 10)
                .position(x: canvas.width / 2,
                          y: canvas.height - detailHeight / 2 - 80)
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

#Preview("Facebook — horizontal") {
    FacebookRenderView(ticket: previewHorizontal)
        .scaleEffect(0.24)
        .frame(width: 259, height: 326)
}

#Preview("Facebook — vertical") {
    FacebookRenderView(ticket: previewVertical)
        .scaleEffect(0.24)
        .frame(width: 259, height: 326)
}
