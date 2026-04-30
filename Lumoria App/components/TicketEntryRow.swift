//
//  TicketEntryRow.swift
//  Lumoria App
//
//  72pt compact row used by the memory edit-mode list. Shows category
//  pill, a single-line title (city → city / station → station / artist),
//  and a drag handle on the right. Pure visual — drag wiring lives on
//  the parent List/onMove.
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=2027-142068
//

import SwiftUI

struct TicketEntryRow: View {

    let ticket: Ticket

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            LumoriaCategoryTag(category: ticket.kind.categoryStyle)
            title
            Spacer(minLength: 8)
            handle
        }
        .padding(.horizontal, 16)
        .frame(height: 72)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.Text.primary.opacity(0.05))
        )
    }

    @ViewBuilder
    private var title: some View {
        Text(ticket.entryTitle)
            .font(.headline)
            .foregroundStyle(Color.Text.primary)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    private var handle: some View {
        ZStack {
            Circle()
                .fill(Color.Text.primary.opacity(0.05))
                .frame(width: 40, height: 40)
            Image(systemName: "line.3.horizontal")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.Text.primary)
        }
    }
}

// MARK: - Title resolver

extension Ticket {
    /// Single line shown in the edit-mode row. Plane/train/transit use
    /// the location pair (city/city or station/station). Concert shows
    /// the artist. Falls back to a generic label.
    fileprivate var entryTitle: String {
        switch kind.categoryStyle {
        case .plane, .train:
            return cityToCity ?? String(localized: "Trip")
        case .publicTransit:
            return stationToStation ?? String(localized: "Trip")
        case .concert:
            return concertHeadline ?? String(localized: "Concert")
        default:
            return originLocation?.name ?? String(localized: "Ticket")
        }
    }

    private var cityToCity: String? {
        guard
            let from = originLocation?.city ?? originLocation?.name,
            let to   = destinationLocation?.city ?? destinationLocation?.name
        else { return nil }
        return "\(from) " + String(localized: "to") + " \(to)"
    }

    private var stationToStation: String? {
        guard
            let from = originLocation?.name,
            let to   = destinationLocation?.name
        else { return nil }
        return "\(from) " + String(localized: "to") + " \(to)"
    }

    private var concertHeadline: String? {
        if case .concert(let payload) = self.payload {
            let trimmed = payload.artist.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }
}
