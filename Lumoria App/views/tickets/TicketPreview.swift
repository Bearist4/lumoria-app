//
//  TicketPreview.swift
//  Lumoria App
//
//  Dispatches to the correct template view for a given ticket + orientation.
//

import SwiftUI

struct TicketPreview: View {

    let ticket: Ticket

    var body: some View {
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
