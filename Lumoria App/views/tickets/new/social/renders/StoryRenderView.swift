//
//  StoryRenderView.swift
//  Lumoria App
//
//  Off-screen composition for the Story (1080×1920) social export.
//  Matches Figma frames 1107:25832 (vertical ticket) and 1774:85649
//  (horizontal ticket).
//
//  Layout:
//    - White canvas.
//    - Hero ticket in the upper ~55% of the frame.
//    - Two supplementary compositions in the lower ~35%:
//        · cropped bottom-slice of the same ticket (shows perforation
//          + "Made with" pill detail)
//        · rotated isometric mini-ticket (decorative, ~12° tilt)
//    - Watermark is embedded in the hero ticket's own template.
//

import SwiftUI

struct StoryRenderView: View {

    let ticket: Ticket

    private let canvas = CGSize(width: 1080, height: 1920)

    private var ticketAspect: CGFloat {
        ticket.orientation == .horizontal ? 455.0 / 260.0 : 260.0 / 455.0
    }

    private var heroSize: CGSize {
        let maxHeight = canvas.height * 0.55
        let maxWidth  = canvas.width * 0.82
        switch ticket.orientation {
        case .horizontal:
            let w = min(maxWidth, maxHeight * ticketAspect)
            return CGSize(width: w, height: w / ticketAspect)
        case .vertical:
            let h = maxHeight
            return CGSize(width: h * ticketAspect, height: h)
        }
    }
    private let heroTopInset: CGFloat = 140

    private let detailSize  = CGSize(width: 520, height: 300)
    private let rotatedSize = CGSize(width: 440, height: 260)
    private let supplementaryTop: CGFloat = 1320
    private let rotatedAngle: Double = -12

    var body: some View {
        ZStack(alignment: .top) {
            Color.white

            // Hero
            TicketPreview(ticket: ticket)
                .aspectRatio(ticketAspect, contentMode: .fit)
                .frame(width: heroSize.width, height: heroSize.height)
                .environment(\.ticketFillsNotchCutouts, false)
                .shadow(color: Color.black.opacity(0.12), radius: 40, x: 0, y: 20)
                .position(x: canvas.width / 2,
                          y: heroTopInset + heroSize.height / 2)

            // Cropped detail (bottom slice)
            TicketPreview(ticket: ticket)
                .aspectRatio(ticketAspect, contentMode: .fit)
                .frame(width: detailSize.width * 1.6,
                       height: detailSize.height * 1.6)
                .offset(y: detailSize.height * 0.55)
                .frame(width: detailSize.width, height: detailSize.height, alignment: .top)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 8)
                .position(x: canvas.width * 0.34,
                          y: supplementaryTop + detailSize.height / 2)

            // Rotated isometric mini
            TicketPreview(ticket: ticket)
                .aspectRatio(ticketAspect, contentMode: .fit)
                .frame(width: rotatedSize.width, height: rotatedSize.height)
                .rotationEffect(.degrees(rotatedAngle))
                .shadow(color: Color.black.opacity(0.12), radius: 20, x: 0, y: 10)
                .position(x: canvas.width * 0.72,
                          y: supplementaryTop + rotatedSize.height / 2 + 20)
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

#Preview("Story — horizontal") {
    StoryRenderView(ticket: previewHorizontal)
        .scaleEffect(0.2)
        .frame(width: 216, height: 384)
}

#Preview("Story — vertical") {
    StoryRenderView(ticket: previewVertical)
        .scaleEffect(0.2)
        .frame(width: 216, height: 384)
}
