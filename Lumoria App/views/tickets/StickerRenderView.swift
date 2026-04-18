//
//  StickerRenderView.swift
//  Lumoria App
//
//  Off-screen view rasterised to a transparent PNG for the iMessage
//  sticker extension. Ticket art only — no canvas, no watermark, no
//  drop shadow. Never displayed in the UI; instantiated inside an
//  `ImageRenderer`.
//
//  Perforation cutouts intentionally show the iMessage background
//  through — that's the look we want as a sticker.
//

import SwiftUI

struct StickerRenderView: View {

    let ticket: Ticket

    /// Native ticket aspect — matches the live `TicketPreview` / card.
    private var aspect: CGFloat {
        ticket.orientation == .horizontal ? 455.0 / 260.0 : 260.0 / 455.0
    }

    /// Render box. 1200 px on the long edge; short edge follows aspect.
    /// `StickerRenderService` may downscale further if the PNG comes in
    /// over 400 KB.
    static func renderSize(
        for orientation: TicketOrientation,
        longEdge: CGFloat = 1200
    ) -> CGSize {
        let aspect: CGFloat = 455.0 / 260.0
        switch orientation {
        case .horizontal: return CGSize(width: longEdge, height: longEdge / aspect)
        case .vertical:   return CGSize(width: longEdge / aspect, height: longEdge)
        }
    }

    var body: some View {
        TicketPreview(ticket: ticket)
            .aspectRatio(aspect, contentMode: .fit)
            .environment(\.ticketFillsNotchCutouts, false)
    }
}

// MARK: - Preview

#Preview("Sticker — horizontal") {
    StickerRenderView(
        ticket: TicketsStore.sampleTickets.first { $0.orientation == .horizontal }
            ?? TicketsStore.sampleTickets[0]
    )
    .frame(width: 360, height: 206)
    .background(Color(white: 0.92))
}

#Preview("Sticker — vertical") {
    StickerRenderView(
        ticket: TicketsStore.sampleTickets.first { $0.orientation == .vertical }
            ?? TicketsStore.sampleTickets[0]
    )
    .frame(width: 206, height: 360)
    .background(Color(white: 0.92))
}
