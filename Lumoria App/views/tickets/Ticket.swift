//
//  Ticket.swift
//  Lumoria App
//
//  Model for a user-created ticket: metadata + a template-specific payload.
//

import Foundation

// MARK: - Template kind

enum TicketTemplateKind: String, Codable, CaseIterable, Identifiable {
    case afterglow
    case studio
    case heritage
    case terminal
    case prism

    var id: String { rawValue }

    /// Human-readable category label for the detail card.
    var displayName: String {
        switch self {
        case .afterglow: return "Afterglow"
        case .studio:    return "Studio"
        case .heritage:  return "Heritage"
        case .terminal:  return "Terminal"
        case .prism:     return "Prism"
        }
    }

    /// Broad category shown with the plane glyph on the detail card.
    var categoryLabel: String { "Plane ticket" }

    /// Data points the template needs to render — shown in the info sheet
    /// launched from the template tile's `i` button.
    var requirements: [TemplateRequirement] {
        var items: [TemplateRequirement] = [
            .init(systemImage: "airplane",            label: "Airport codes"),
            .init(systemImage: "calendar.badge.clock", label: "Date & time of travel"),
            .init(systemImage: "airplane.departure",  label: "Flight details"),
        ]
        if self == .heritage || self == .terminal {
            items.append(.init(systemImage: "airplane.circle", label: "Aircraft details"))
        }
        if self != .afterglow {
            items.append(.init(systemImage: "person.text.rectangle", label: "Passenger details"))
        }
        return items
    }
}

// MARK: - Template requirement (info sheet item)

struct TemplateRequirement: Identifiable {
    let id = UUID()
    let systemImage: String
    let label: String
}

// MARK: - Orientation

enum TicketOrientation: String, Codable {
    case horizontal
    case vertical
}

// MARK: - Payload

/// Template-specific data for a ticket. One case per template, each holding
/// that template's concrete struct.
enum TicketPayload {
    case afterglow(AfterglowTicket)
    case studio(StudioTicket)
    case heritage(HeritageTicket)
    case terminal(TerminalTicket)
    case prism(PrismTicket)

    var kind: TicketTemplateKind {
        switch self {
        case .afterglow: return .afterglow
        case .studio:    return .studio
        case .heritage:  return .heritage
        case .terminal:  return .terminal
        case .prism:     return .prism
        }
    }
}

// MARK: - Ticket

struct Ticket: Identifiable, Hashable {
    let id: UUID
    var createdAt: Date
    var updatedAt: Date
    var orientation: TicketOrientation
    var payload: TicketPayload
    var collectionIds: [UUID]

    var kind: TicketTemplateKind { payload.kind }

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        orientation: TicketOrientation,
        payload: TicketPayload,
        collectionIds: [UUID] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.orientation = orientation
        self.payload = payload
        self.collectionIds = collectionIds
    }

    static func == (lhs: Ticket, rhs: Ticket) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
