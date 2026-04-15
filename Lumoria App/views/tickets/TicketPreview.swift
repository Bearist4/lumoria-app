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
        switch (ticket.payload, ticket.orientation) {
        case (.afterglow(let t), .horizontal): AfterglowTicketView(ticket: t)
        case (.afterglow(let t), .vertical):   AfterglowTicketVerticalView(ticket: t)

        case (.studio(let t), .horizontal):    StudioTicketView(ticket: t)
        case (.studio(let t), .vertical):      StudioTicketVerticalView(ticket: t)

        case (.heritage(let t), .horizontal):  HeritageTicketView(ticket: t)
        case (.heritage(let t), .vertical):    HeritageTicketVerticalView(ticket: t)

        case (.terminal(let t), .horizontal):  TerminalTicketView(ticket: t)
        case (.terminal(let t), .vertical):    TerminalTicketVerticalView(ticket: t)

        case (.prism(let t), .horizontal):     PrismTicketView(ticket: t)
        case (.prism(let t), .vertical):       PrismTicketVerticalView(ticket: t)
        }
    }
}
