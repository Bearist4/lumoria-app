//
//  TicketPreview.swift
//  Lumoria App
//
//  Dispatches to the correct template view for a given ticket + orientation,
//  and applies the tilt-driven shimmer overlay on the outer shape.
//

import SwiftUI

struct TicketPreview: View {

    let ticket: Ticket
    /// `true` when this ticket is the currently focused / hero card on
    /// screen. Drives the shimmer overlay: only the centred card consumes
    /// tilt motion, so off-screen tickets stay static. Callers rendering
    /// in list/scroll surfaces wire this through a viewport check; single
    /// detail surfaces pass `true` directly.
    var isCentered: Bool = false

    var body: some View {
        templateView
            .overlay {
                TicketShimmerView(isActive: isCentered)
                    // Mask the wash using the template view itself so the
                    // overlay inherits every template's cutouts (Prism
                    // notches, perforated edges, rounded corners).
                    .mask {
                        templateView
                            .allowsHitTesting(false)
                    }
                    .allowsHitTesting(false)
            }
    }

    @ViewBuilder
    private var templateView: some View {
        let style = ticket.resolvedStyle

        switch (ticket.payload, ticket.orientation) {
        case (.afterglow(let t), .horizontal): AfterglowTicketView(ticket: t, style: style)
        case (.afterglow(let t), .vertical):   AfterglowTicketVerticalView(ticket: t, style: style)

        case (.studio(let t), .horizontal):    StudioTicketView(ticket: t, style: style)
        case (.studio(let t), .vertical):      StudioTicketVerticalView(ticket: t, style: style)

        case (.heritage(let t), .horizontal):  HeritageTicketView(ticket: t, style: style)
        case (.heritage(let t), .vertical):    HeritageTicketVerticalView(ticket: t, style: style)

        case (.terminal(let t), .horizontal):  TerminalTicketView(ticket: t, style: style)
        case (.terminal(let t), .vertical):    TerminalTicketVerticalView(ticket: t, style: style)

        case (.prism(let t), .horizontal):     PrismTicketView(ticket: t, style: style)
        case (.prism(let t), .vertical):       PrismTicketVerticalView(ticket: t, style: style)

        case (.express(let t), .horizontal):   ExpressTicketView(ticket: t, style: style)
        case (.express(let t), .vertical):     ExpressTicketVerticalView(ticket: t, style: style)

        case (.orient(let t), .horizontal):    OrientTicketView(ticket: t, style: style)
        case (.orient(let t), .vertical):      OrientTicketVerticalView(ticket: t, style: style)

        case (.night(let t), .horizontal):     NightTicketView(ticket: t, style: style)
        case (.night(let t), .vertical):       NightTicketVerticalView(ticket: t, style: style)

        case (.post(let t), .horizontal):      PostTicketView(ticket: t, style: style)
        case (.post(let t), .vertical):        PostTicketVerticalView(ticket: t, style: style)

        case (.glow(let t), .horizontal):      GlowTicketView(ticket: t, style: style)
        case (.glow(let t), .vertical):        GlowTicketVerticalView(ticket: t, style: style)

        case (.concert(let t), .horizontal):      ConcertTicketView(ticket: t, style: style)
        case (.concert(let t), .vertical):        ConcertTicketVerticalView(ticket: t, style: style)

        case (.eurovision(let t), .horizontal):   EurovisionTicketView(ticket: t, style: style)
        case (.eurovision(let t), .vertical):     EurovisionTicketVerticalView(ticket: t, style: style)

        case (.underground(let t), .horizontal):  SignalTicketView(ticket: t)
        case (.underground(let t), .vertical):    SignalTicketVerticalView(ticket: t)

        case (.sign(let t), .horizontal):         SignTicketView(ticket: t)
        case (.sign(let t), .vertical):           SignTicketVerticalView(ticket: t)

        case (.infoscreen(let t), .horizontal):   InfoscreenTicketView(ticket: t)
        case (.infoscreen(let t), .vertical):     InfoscreenTicketVerticalView(ticket: t)

        case (.grid(let t), .horizontal):         GridTicketView(ticket: t)
        case (.grid(let t), .vertical):           GridTicketVerticalView(ticket: t)
        }
    }
}
