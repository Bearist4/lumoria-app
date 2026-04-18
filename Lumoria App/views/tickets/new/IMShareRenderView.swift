//
//  IMShareRenderView.swift
//  Lumoria App
//
//  Off-screen composition rendered to a UIImage and handed to the system
//  activity sheet when the user shares a ticket via instant messaging.
//  Never displayed in the UI — instantiated only inside an `ImageRenderer`.
//
//  Layout: 1200×1200 white canvas → 1040×1040 gray.50 inner frame → ticket
//  centered inside with a drop shadow. A "Made with Lumoria" wordmark sits
//  in the bottom-left of the outer canvas, outside the inner frame. The
//  ticket keeps whatever internal watermark it already renders.
//

import SwiftUI

struct IMShareRenderView: View {

    let ticket: Ticket

    // MARK: - Canvas

    private let canvasSize: CGFloat = 1200
    /// Size of the invisible inner bounding box that drives the ticket's
    /// max dimensions. No longer a drawn frame — templates have cutouts
    /// that look bad on any non-white backdrop.
    private let innerFrameSize: CGFloat = 1040

    // Outer-canvas inset for the bottom-left watermark.
    private let watermarkInset: CGFloat = 24
    private let watermarkScale: CGFloat = 1.5

    // Ticket bounding box inside the inner frame. Vertical tickets get a
    // smaller bound (0.78) so the portrait card has more breathing room;
    // horizontal tickets fill more of the frame (0.85).
    private let horizontalBoundRatio: CGFloat = 0.85
    private let verticalBoundRatio: CGFloat = 0.78

    // Native ticket aspect ratios (match `CameraRollView.previewCard`).
    private var ticketAspect: CGFloat {
        ticket.orientation == .horizontal ? 455.0 / 260.0 : 260.0 / 455.0
    }

    /// Longest side bound for the ticket inside the inner frame. The
    /// shorter side falls out of the fixed aspect ratio.
    private var ticketBound: CGSize {
        let inner = innerFrameSize
        switch ticket.orientation {
        case .horizontal:
            let w = inner * horizontalBoundRatio
            return CGSize(width: w, height: w / ticketAspect)
        case .vertical:
            let h = inner * verticalBoundRatio
            return CGSize(width: h * ticketAspect, height: h)
        }
    }

    var body: some View {
        ZStack {
            Color.white

            // No inner frame fill: ticket templates have shape cutouts
            // (perforations, notches), and any background behind them shows
            // through the cutouts and breaks the silhouette. Ticket sits
            // directly on the white canvas. `innerFrameSize` still drives
            // the ticket bounds math below.

            TicketPreview(ticket: ticket)
                .aspectRatio(ticketAspect, contentMode: .fit)
                .frame(width: ticketBound.width, height: ticketBound.height)
                .environment(\.ticketFillsNotchCutouts, false)
                .shadow(color: Color.black.opacity(0.15), radius: 40, x: 0, y: 20)

            VStack {
                Spacer()
                HStack {
                    MadeWithLumoria(
                        style: .black,
                        version: .small,
                        scale: watermarkScale
                    )
                    .environment(\.colorScheme, .light)
                    Spacer()
                }
            }
            .padding(watermarkInset)
        }
        .frame(width: canvasSize, height: canvasSize)
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

#Preview("IM share — horizontal") {
    IMShareRenderView(ticket: previewHorizontal)
        .scaleEffect(0.3)
        .frame(width: 360, height: 360)
}

#Preview("IM share — vertical") {
    IMShareRenderView(ticket: previewVertical)
        .scaleEffect(0.3)
        .frame(width: 360, height: 360)
}
