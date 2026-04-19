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
                TicketShimmerView(
                    mode: ticket.kind.shimmer,
                    isActive: isCentered
                )
                // Mask the shimmer using the template view itself so the
                // overlay inherits every template's cutouts (Prism notches,
                // perforated edges, rounded corners). Template is rendered
                // a second time here with hit-testing off — cost is one
                // extra layout pass; correctness otherwise requires a
                // per-template shape hand-off.
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
        case (.afterglow(let t), .horizontal): AfterglowTicketView(ticket: t)
        case (.afterglow(let t), .vertical):   AfterglowTicketVerticalView(ticket: t)

        case (.studio(let t), .horizontal):    StudioTicketView(ticket: t, style: style)
        case (.studio(let t), .vertical):      StudioTicketVerticalView(ticket: t, style: style)

        case (.heritage(let t), .horizontal):  HeritageTicketView(ticket: t)
        case (.heritage(let t), .vertical):    HeritageTicketVerticalView(ticket: t)

        case (.terminal(let t), .horizontal):  TerminalTicketView(ticket: t)
        case (.terminal(let t), .vertical):    TerminalTicketVerticalView(ticket: t)

        case (.prism(let t), .horizontal):     PrismTicketView(ticket: t)
        case (.prism(let t), .vertical):       PrismTicketVerticalView(ticket: t)

        case (.express(let t), .horizontal):   ExpressTicketView(ticket: t, style: style)
        case (.express(let t), .vertical):     ExpressTicketVerticalView(ticket: t, style: style)

        case (.orient(let t), .horizontal):    OrientTicketView(ticket: t, style: style)
        case (.orient(let t), .vertical):      OrientTicketVerticalView(ticket: t, style: style)

        case (.night(let t), .horizontal):     NightTicketView(ticket: t, style: style)
        case (.night(let t), .vertical):       NightTicketVerticalView(ticket: t, style: style)
        }
    }
}
