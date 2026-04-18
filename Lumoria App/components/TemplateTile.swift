//
//  TemplateTile.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=978-7619
//
//  Pick-one tile used to choose a *template* (Afterglow, Studio, …). Shows a
//  horizontal ticket preview above a 20pt label, with a 40pt info button
//  pinned to the bottom-right corner that triggers `onInfoTap`.
//

import SwiftUI

struct TemplateTile: View {

    let title: String
    /// Ticket payload rendered as the tile thumbnail (horizontal orientation).
    let previewPayload: TicketPayload
    var isSelected: Bool = false
    var onTap: () -> Void = {}
    var onInfoTap: () -> Void = {}

    /// Figma thumbnail size: 204×118.
    private let thumbWidth: CGFloat = 204
    private let thumbHeight: CGFloat = 118

    var body: some View {
        Button(action: onTap) {
            SelectionTile(
                isSelected: isSelected,
                verticalPadding: 32
            ) {
                ZStack(alignment: .bottomTrailing) {
                    VStack(spacing: 12) {
                        TicketPreview(
                            ticket: Ticket(
                                orientation: .horizontal,
                                payload: previewPayload
                            )
                        )
                        .frame(width: thumbWidth, height: thumbHeight)

                        SelectionTileLabel(text: title, isSelected: isSelected)
                    }
                    .frame(maxWidth: .infinity)

                    infoButton
                        .padding(isSelected ? 9 : 12)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Info button

    private var infoButton: some View {
        Button(action: onInfoTap) {
            Image(systemName: "info.circle")
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color.Text.primary)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.Background.fieldFill))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Template tiles") {
    VStack(spacing: 16) {
        TemplateTile(
            title: "Studio",
            previewPayload: .studio(TicketsStore.sampleTickets[2].payload.studioOrEmpty)
        )
        TemplateTile(
            title: "Prism",
            previewPayload: TicketsStore.sampleTickets[0].payload,
            isSelected: true
        )
    }
    .padding(24)
    .background(Color.Background.default)
}

// Tiny helper for the preview above — pulls the studio payload cleanly.
private extension TicketPayload {
    var studioOrEmpty: StudioTicket {
        if case .studio(let t) = self { return t }
        return StudioTicket(
            airline: "Airline", flightNumber: "FlightNumber",
            cabinClass: "Class",
            origin: "NRT", originName: "Narita International", originLocation: "Tokyo, Japan",
            destination: "JFK", destinationName: "John F. Kennedy", destinationLocation: "New York, United States",
            date: "8 Jun 2026", gate: "74", seat: "1K", departureTime: "11:05"
        )
    }
}
