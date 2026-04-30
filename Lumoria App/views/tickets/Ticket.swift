//
//  Ticket.swift
//  Lumoria App
//
//  Model for a user-created ticket: metadata + a template-specific payload.
//

import CoreLocation
import Foundation

// MARK: - Template kind

enum TicketTemplateKind: String, Codable, CaseIterable, Identifiable {
    case afterglow
    case studio
    case heritage
    case terminal
    case prism
    case express
    case orient
    case night
    case post
    case glow
    case concert
    /// Public-transport "Signal" template (dark card, line-colour
    /// spine). Enum raw value stays `"underground"` so tickets
    /// created before the public-transport template family split
    /// into signal / sign / infoscreen decode cleanly.
    case underground
    case sign
    case infoscreen
    case grid

    var id: String { rawValue }

    /// Human-readable category label for the detail card.
    var displayName: String {
        switch self {
        case .afterglow:   return "Afterglow"
        case .studio:      return "Studio"
        case .heritage:    return "Heritage"
        case .terminal:    return "Terminal"
        case .prism:       return "Prism"
        case .express:     return "Express"
        case .orient:      return "Orient"
        case .night:       return "Night"
        case .post:        return "Post"
        case .glow:        return "Glow"
        case .concert:     return "Concert"
        case .underground: return "Signal"
        case .sign:        return "Sign"
        case .infoscreen:  return "Infoscreen"
        case .grid:        return "Grid"
        }
    }

    /// Broad category shown with the glyph on the detail card.
    var categoryLabel: String {
        switch self {
        case .express, .orient, .night, .post, .glow:            return String(localized: "Train ticket")
        case .afterglow, .studio, .heritage, .terminal, .prism:  return String(localized: "Plane ticket")
        case .concert:                                              return String(localized: "Concert ticket")
        case .underground, .sign, .infoscreen, .grid:           return String(localized: "Public transport ticket")
        }
    }

    /// Data points the template needs to render — shown in the info sheet
    /// launched from the template tile's `i` button.
    var requirements: [TemplateRequirement] {
        switch self {
        case .express:
            return [
                .init(systemImage: "tram.fill",            label: "Departing & arrival cities"),
                .init(systemImage: "calendar.badge.clock", label: "Date & travel times"),
                .init(systemImage: "ticket.fill",          label: "Train details"),
                .init(systemImage: "person.text.rectangle", label: "Car & seat"),
            ]
        case .orient:
            return [
                .init(systemImage: "tram.fill",            label: "Departing & arrival cities"),
                .init(systemImage: "building.columns",     label: "Station names"),
                .init(systemImage: "calendar.badge.clock", label: "Date & departure time"),
                .init(systemImage: "person.text.rectangle", label: "Passenger, carriage & seat"),
            ]
        case .night:
            return [
                .init(systemImage: "tram.fill",            label: "Departing & arrival cities"),
                .init(systemImage: "ticket.fill",          label: "Train type & code"),
                .init(systemImage: "calendar.badge.clock", label: "Departure date & time"),
                .init(systemImage: "bed.double.fill",      label: "Car, berth & passenger"),
            ]
        case .post, .glow:
            return [
                .init(systemImage: "tram.fill",            label: "Departing & arrival cities"),
                .init(systemImage: "building.columns",     label: "Station names"),
                .init(systemImage: "calendar.badge.clock", label: "Date & departure time"),
                .init(systemImage: "ticket.fill",          label: "Train details, car & seat"),
            ]
        case .concert:
            return [
                .init(systemImage: "music.mic",            label: "Artist & tour name"),
                .init(systemImage: "building.2.fill",      label: "Venue"),
                .init(systemImage: "calendar.badge.clock", label: "Date, doors & showtime"),
                .init(systemImage: "ticket.fill",          label: "Ticket number"),
            ]
        case .underground, .sign, .infoscreen, .grid:
            return [
                .init(systemImage: "tram.fill",            label: "Origin & destination stations"),
                .init(systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                                                             label: "Line (auto-detected)"),
                .init(systemImage: "calendar",             label: "Date of travel"),
                .init(systemImage: "ticket.fill",          label: "Ticket number, zones, fare"),
            ]
        default:
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

// MARK: - Location

/// A physical place attached to a ticket.
/// Plane/train tickets use `origin` (departure) + `destination` (arrival).
/// Single-venue tickets (dining, movie, event) use `origin` only.
///
/// City is the grouping key for round-trip inference on the memory map:
/// two tickets A→B and B→A sharing city pairs collapse to a round trip.
enum TicketLocationKind: String, Codable, Hashable {
    case airport
    case station
    case venue
}

struct TicketLocation: Codable, Hashable {
    /// Display name. For airports: "Charles De Gaulle Airport".
    /// For stations: "Gare de Lyon". For venues: "Le Méridien".
    var name: String
    /// Short identifier shown on the ticket — IATA code for airports,
    /// station code for stations, optional subtitle for venues.
    var subtitle: String?
    /// City as reported by the search provider.
    var city: String?
    /// Country name as reported by the search provider (e.g. "France").
    var country: String?
    /// ISO 3166-1 alpha-2 country code (e.g. "FR"). Used to render the
    /// country's flag emoji as a selection affordance.
    var countryCode: String?
    var lat: Double
    var lng: Double
    var kind: TicketLocationKind

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    /// The country's flag emoji, derived from `countryCode` via regional
    /// indicator symbols. Nil if no country code is set.
    var flagEmoji: String? {
        guard let code = countryCode, code.count == 2 else { return nil }
        let base: UInt32 = 127397
        var scalars = ""
        for scalar in code.uppercased().unicodeScalars {
            guard let paired = UnicodeScalar(base + scalar.value) else { return nil }
            scalars.unicodeScalars.append(paired)
        }
        return scalars
    }

    // MARK: - Encrypt / decrypt

    /// Encrypts a location to base64 ciphertext for storage in
    /// `location_primary_enc` / `location_secondary_enc`.
    static func encrypt(_ location: TicketLocation) throws -> String {
        let data = try JSONEncoder().encode(location)
        let cipher = try EncryptionService.encrypt(data)
        return cipher.base64EncodedString()
    }

    /// Decrypts a location from base64 ciphertext. Returns nil if the input
    /// is nil; throws if the ciphertext is present but malformed.
    static func decrypt(_ base64: String?) throws -> TicketLocation? {
        guard let base64 else { return nil }
        guard let cipher = Data(base64Encoded: base64) else {
            throw EncryptionServiceError.invalidBase64
        }
        let plain = try EncryptionService.decrypt(cipher)
        return try JSONDecoder().decode(TicketLocation.self, from: plain)
    }
}

// MARK: - Payload

/// Template-specific data for a ticket. One case per template, each holding
/// that template's concrete struct.
enum TicketPayload: Encodable {
    case afterglow(AfterglowTicket)
    case studio(StudioTicket)
    case heritage(HeritageTicket)
    case terminal(TerminalTicket)
    case prism(PrismTicket)
    case express(ExpressTicket)
    case orient(OrientTicket)
    case night(NightTicket)
    case post(PostTicket)
    case glow(GlowTicket)
    case concert(ConcertTicket)
    // All three public-transport templates share the same
    // `UndergroundTicket` payload shape; only the rendered view
    // differs. Splitting into separate cases lets the template
    // picker offer Signal / Sign / Infoscreen as distinct tiles
    // the way train offers Post + Glow.
    case underground(UndergroundTicket)
    case sign(UndergroundTicket)
    case infoscreen(UndergroundTicket)
    case grid(UndergroundTicket)

    func encode(to encoder: Encoder) throws {
        switch self {
        case .afterglow(let v):   try v.encode(to: encoder)
        case .studio(let v):      try v.encode(to: encoder)
        case .heritage(let v):    try v.encode(to: encoder)
        case .terminal(let v):    try v.encode(to: encoder)
        case .prism(let v):       try v.encode(to: encoder)
        case .express(let v):     try v.encode(to: encoder)
        case .orient(let v):      try v.encode(to: encoder)
        case .night(let v):       try v.encode(to: encoder)
        case .post(let v):        try v.encode(to: encoder)
        case .glow(let v):        try v.encode(to: encoder)
        case .concert(let v):     try v.encode(to: encoder)
        case .underground(let v): try v.encode(to: encoder)
        case .sign(let v):        try v.encode(to: encoder)
        case .infoscreen(let v):  try v.encode(to: encoder)
        case .grid(let v):        try v.encode(to: encoder)
        }
    }

    var kind: TicketTemplateKind {
        switch self {
        case .afterglow:   return .afterglow
        case .studio:      return .studio
        case .heritage:    return .heritage
        case .terminal:    return .terminal
        case .prism:       return .prism
        case .express:     return .express
        case .orient:      return .orient
        case .night:       return .night
        case .post:        return .post
        case .glow:        return .glow
        case .concert:     return .concert
        case .underground: return .underground
        case .sign:        return .sign
        case .infoscreen:  return .infoscreen
        case .grid:        return .grid
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
    var memoryIds: [UUID]
    /// Primary location — single venue, or origin for a trip.
    var originLocation: TicketLocation?
    /// Destination for a trip (plane/train). Nil for single-venue templates.
    var destinationLocation: TicketLocation?
    /// Identifier of the chosen style variant from `TicketStyleCatalog`.
    /// Nil means: render with the template's default variant.
    var styleId: String?
    /// Canonical event date for sort-by-event in `MemoryDetailView`.
    /// Plane/train: departure. Concert/transit: the single date field.
    /// Nil for tickets created before the column existed.
    var eventDate: Date?
    /// When this ticket was added to each memory (memory_tickets.added_at).
    /// Sourced per row from the embedded junction; missing keys mean the
    /// embedded query did not return the row (e.g. ticket not in memory).
    var addedAtByMemory: [UUID: Date]

    var kind: TicketTemplateKind { payload.kind }

    /// Style variant resolved against the template's catalog. Always
    /// returns a renderable variant — falls back to the template's
    /// default if `styleId` is nil or no longer present in the catalog.
    var resolvedStyle: TicketStyleVariant { kind.resolveStyle(id: styleId) }

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        orientation: TicketOrientation,
        payload: TicketPayload,
        memoryIds: [UUID] = [],
        originLocation: TicketLocation? = nil,
        destinationLocation: TicketLocation? = nil,
        styleId: String? = nil,
        eventDate: Date? = nil,
        addedAtByMemory: [UUID: Date] = [:]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.orientation = orientation
        self.payload = payload
        self.memoryIds = memoryIds
        self.originLocation = originLocation
        self.destinationLocation = destinationLocation
        self.styleId = styleId
        self.eventDate = eventDate
        self.addedAtByMemory = addedAtByMemory
    }

    /// Equality includes `updatedAt` so SwiftUI's view diff re-renders
    /// `TicketPreview` (and any wrapping cards) when the payload changes
    /// on save — id-only equality made edits invisible until a full view
    /// rebuild. Hash stays id-only; the resulting collisions on edit are
    /// fine since equality is checked separately by Set / Dictionary.
    static func == (lhs: Ticket, rhs: Ticket) -> Bool {
        lhs.id == rhs.id && lhs.updatedAt == rhs.updatedAt
    }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
