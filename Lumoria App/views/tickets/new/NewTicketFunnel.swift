//
//  NewTicketFunnel.swift
//  Lumoria App
//
//  State model for the multi-step "new ticket" funnel.
//

import Combine
import Foundation
import MapKit
import SwiftUI

// MARK: - Category

enum TicketCategory: String, CaseIterable, Identifiable, Codable {
    case plane
    case train
    case concert
    case event
    case food
    case movie
    case museum
    case sport
    case garden
    case publicTransit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plane:         return String(localized: "Plane ticket")
        case .train:         return String(localized: "Train ticket")
        case .concert:       return String(localized: "Concert")
        case .event:         return String(localized: "Event")
        case .food:          return String(localized: "Food & Drinks")
        case .movie:         return String(localized: "Movies")
        case .museum:        return String(localized: "Museum")
        case .sport:         return String(localized: "Sport")
        case .garden:        return String(localized: "Parks & Gardens")
        case .publicTransit: return String(localized: "Public Transport")
        }
    }

    /// Named asset under `Assets.xcassets/misc`.
    var imageName: String {
        switch self {
        case .plane:         return "plane"
        case .train:         return "train"
        case .concert:       return "concert_stage"
        case .event:         return "concert_stage"
        case .food:          return "concert_stage"
        case .movie:         return "concert_stage"
        case .museum:        return "concert_stage"
        case .sport:         return "concert_stage"
        case .garden:        return "garden"
        case .publicTransit: return "tram_stop"
        }
    }

    /// A category is "available" iff at least one template has
    /// shipped for it. Driving this off `templates` keeps the
    /// category picker in sync as new templates land — add a case
    /// to `templates`, and the tile flips on automatically.
    var isAvailable: Bool {
        !templates.isEmpty
    }

    /// Templates offered inside this category.
    var templates: [TicketTemplateKind] {
        switch self {
        case .plane:         return [.afterglow, .studio, .terminal, .heritage, .prism]
        case .train:         return [.express, .orient, .night, .post, .glow]
        case .concert:       return [.concert]
        case .event:         return [.eurovision]
        case .publicTransit: return [.underground, .sign, .infoscreen, .grid]
        default:             return []
        }
    }
}

// MARK: - Step

enum NewTicketStep: Int, CaseIterable, Comparable, Codable {
    case category    = 0
    case template    = 1
    case orientation = 2
    /// Import slot — only reached when the funnel opens with
    /// `importSource != nil`. Self-dismisses to `.form` once parsing
    /// finishes, or when the user taps "Fill manually".
    case `import`    = 3
    case form        = 4
    case style       = 5
    case success     = 6

    var title: String {
        switch self {
        case .category:    return String(localized: "Select a category")
        case .template:    return String(localized: "Pick a template")
        case .orientation: return String(localized: "Choose an orientation")
        case .import:      return String(localized: "Import your ticket")
        case .form:        return String(localized: "Fill your ticket’s information")
        case .style:       return String(localized: "Choose the style of your ticket")
        case .success:     return ""
        }
    }

    var subtitle: String? {
        switch self {
        case .category:
            return String(localized: "Choose the type of ticket you want to create.")
        case .import:
            return String(localized: "Pick a file and we’ll prefill what we can.")
        default:
            return nil
        }
    }

    /// Whether the step's body should fill the available height instead of
    /// being wrapped in a ScrollView. Used by orientation where both tiles
    /// need to share remaining space.
    var prefersFullHeight: Bool {
        self == .orientation
            || self == .import
            || self == .style
            || self == .success
    }

    static func < (a: NewTicketStep, b: NewTicketStep) -> Bool {
        a.rawValue < b.rawValue
    }
}

// MARK: - Import source

/// Origin of a ticket import. Drives which parser the import step runs
/// and which `TicketSourceProp` fires on save.
enum ImportSource: String, CaseIterable, Hashable {
    case wallet
    case share
}

// MARK: - Form input

/// Unified flight-form input. Holds every field any of the 5 plane templates
/// might need; each template-specific builder reads the subset it cares about.
struct FlightFormInput: Codable {
    var airline: String = ""
    var flightNumber: String = ""
    var aircraft: String = ""
    var cabinClass: String = ""
    var cabinDetail: String = ""

    var originCode: String = ""
    var originName: String = ""
    var originLocation: String = ""
    var departureDate: Date = Date()
    var departureTime: Date = Date()

    var destinationCode: String = ""
    var destinationName: String = ""
    var destinationLocation: String = ""

    var flightDuration: String = ""
    var gate: String = ""
    var seat: String = ""
    var terminal: String = ""

    /// Structured airport picked from MapKit search. When present, the
    /// text fields above are treated as auto-filled from this value — the
    /// user can still edit them to override IATA / name / city copy.
    var originAirport: TicketLocation? = nil
    var destinationAirport: TicketLocation? = nil

    /// Airline picked from `AirlineDatabase`. When set, the flight-number
    /// input locks its leading carrier code prefix and the user types only
    /// the flight digits via a number pad.
    var selectedAirline: Airline? = nil
    /// Just the numeric portion of the flight number (e.g. "7141"). The
    /// composed `flightNumber` string used by payload builders is assembled
    /// from the airline IATA + this field.
    var flightNumberDigits: String = ""

    /// Flight number as it should appear on the ticket — "XX 7141" when a
    /// carrier has been picked and digits entered, otherwise whatever the
    /// user typed manually into the legacy `flightNumber` field.
    var composedFlightNumber: String {
        if let airline = selectedAirline,
           !flightNumberDigits.trimmingCharacters(in: .whitespaces).isEmpty {
            return "\(airline.iata) \(flightNumberDigits)"
        }
        return flightNumber
    }

    /// Every field marked required (*) on the form step must be filled
    /// before Next is enabled. Origin / destination count via typed IATA
    /// or picked airport; airline via typed name or picked carrier; flight
    /// number via the composed "<IATA> <digits>" or a manually typed value.
    var isMinimallyValid: Bool {
        let hasOrigin = !originCode.trimmingCharacters(in: .whitespaces).isEmpty
                        || originAirport != nil
        let hasDestination = !destinationCode.trimmingCharacters(in: .whitespaces).isEmpty
                             || destinationAirport != nil
        let hasAirline = !airline.trimmingCharacters(in: .whitespaces).isEmpty
                         || selectedAirline != nil
        let hasFlightNumber = !composedFlightNumber
            .trimmingCharacters(in: .whitespaces)
            .isEmpty
        return hasAirline
            && hasFlightNumber
            && hasOrigin
            && hasDestination
    }
}

// MARK: - Train form input

/// Pure-text form for the Express (train) template. City names ship in
/// two scripts — Latin entered by the user and CJK auto-suggested by
/// `CityNameTranslator` (and always editable).
struct TrainFormInput: Codable {
    // Shared by both train templates
    var cabinClass: String = ""
    var originCity: String = ""
    var destinationCity: String = ""
    var date: Date = Date()
    var departureTime: Date = Date()
    var car: String = ""
    var seat: String = ""
    var ticketNumber: String = ""

    /// Station picked from MapKit search. Drives origin/destination
    /// city + station text fields downstream, and is forwarded to the
    /// tickets row as `location_primary_enc` / `location_secondary_enc`
    /// so train tickets also appear on the memory map.
    var originStationLocation: TicketLocation? = nil
    var destinationStationLocation: TicketLocation? = nil

    // Express-only — Shinkansen
    var trainType: String = ""
    var trainNumber: String = ""
    var originCityKanji: String = ""
    var destinationCityKanji: String = ""
    var arrivalTime: Date = Date()

    // Orient-only — vintage Orient Express
    var company: String = ""
    var originStation: String = ""
    var destinationStation: String = ""
    var passenger: String = ""

    // Night-only — sleeper trains carry a berth label (Lower / Upper /
    // Single) instead of a seat. Kept separate so it never collides
    // with the `seat` slot that Express / Orient use.
    var berth: String = ""

    /// Express minimum: train type + number + both cities. Kanji slots
    /// auto-suggest and may stay empty for non-Japanese routes.
    var isExpressValid: Bool {
        let trim: (String) -> String = { $0.trimmingCharacters(in: .whitespaces) }
        return !trim(trainType).isEmpty
            && !trim(trainNumber).isEmpty
            && !trim(originCity).isEmpty
            && !trim(destinationCity).isEmpty
    }

    /// Orient minimum: company + both cities. Stations and passenger
    /// are optional — they enrich the rendering but don't block save.
    var isOrientValid: Bool {
        let trim: (String) -> String = { $0.trimmingCharacters(in: .whitespaces) }
        return !trim(company).isEmpty
            && !trim(originCity).isEmpty
            && !trim(destinationCity).isEmpty
    }

    /// Night minimum: company + train type + train code + both cities.
    /// Berth / passenger / ticket no. render blank if left empty.
    var isNightValid: Bool {
        let trim: (String) -> String = { $0.trimmingCharacters(in: .whitespaces) }
        return !trim(company).isEmpty
            && !trim(trainType).isEmpty
            && !trim(trainNumber).isEmpty
            && !trim(originCity).isEmpty
            && !trim(destinationCity).isEmpty
    }

    /// Post / Glow minimum: train type + train number + both cities.
    /// Stations / car / seat are optional — they enrich the render but
    /// never block save.
    var isPostGlowValid: Bool {
        let trim: (String) -> String = { $0.trimmingCharacters(in: .whitespaces) }
        return !trim(trainType).isEmpty
            && !trim(trainNumber).isEmpty
            && !trim(originCity).isEmpty
            && !trim(destinationCity).isEmpty
    }

    /// Compatibility shim — older callers still ask for a generic
    /// `isMinimallyValid`. Defaults to the Express rules.
    var isMinimallyValid: Bool { isExpressValid }
}

// MARK: - Event form input

/// Form input for the Concert template. Single-venue layout, so
/// only one location slot — `venueLocation` is forwarded to the ticket's
/// `originLocation` so concerts appear on the memory map.
struct EventFormInput: Codable {
    var artist: String = ""
    var tourName: String = ""
    var venue: String = ""
    var date: Date = Date()
    var doorsTime: Date = Date()
    var showTime: Date = Date()
    var ticketNumber: String = ""

    var venueLocation: TicketLocation? = nil

    /// Concert minimum: artist + venue. Date/times default to now;
    /// ticket number and tour title are optional.
    var isConcertValid: Bool {
        let trim: (String) -> String = { $0.trimmingCharacters(in: .whitespaces) }
        return !trim(artist).isEmpty && !trim(venue).isEmpty
    }
}

// MARK: - Eurovision form input

/// Form input for the Eurovision template. Date and venue are pinned
/// to the real-world event (16 May 2026 · Wiener Stadthalle Halle D)
/// so the form only collects the supported country plus the user's
/// section / row / seat. The picked country drives the per-country
/// `eurovision-bg-<cc>` + `eurovision-logo-<cc>` artwork at render time.
struct EurovisionFormInput: Codable {
    var country: EurovisionCountry? = nil
    var attendance: EurovisionAttendance = .inPerson
    /// Used when `attendance == .inPerson`.
    var section: String = ""
    var row: String = ""
    var seat: String = ""
    /// Used when `attendance == .atHome`. Defaults to "At home" so
    /// users who don't customise it still get a recognisable label
    /// painted on the rendered ticket.
    var watchLocation: String = String(localized: "At home")
    var ticketNumber: String = ""

    /// Eurovision minimum: a country pick. Everything else is optional —
    /// the form's "auto-fill" pass at advance() will fill blank seat /
    /// section / row / ticket-number with sensible placeholders so the
    /// rendered ticket never has empty cells.
    var isValid: Bool { country != nil }
}

// MARK: - Underground form

/// Form input for the Underground (subway / metro) template. Two
/// station pickers feed a local routing pass over the bundled GTFS
/// catalog (`TransitCatalog` + `TransitRouter`). The router returns
/// one or more `TransitLeg`s; when the rider has to change lines
/// (A → B on U1, B → C on U4…) each leg produces its own ticket.
///
/// `replan()` is called from the form whenever either station
/// changes — it re-runs the router, updates the preview via
/// `plannedLegs`, and surfaces transfer metadata so the form can
/// say things like "Journey · 2 tickets".
struct UndergroundFormInput: Codable {
    /// City whose catalog the station fields search against. The user
    /// picks this first at the top of the form; both station pickers
    /// stay disabled until a city is chosen. Changing the city wipes
    /// any already-picked stations because they'd belong to a
    /// different network anyway.
    var selectedCity: TransitCatalogLoader.City? = nil

    var originStation: TicketLocation? = nil
    var destinationStation: TicketLocation? = nil

    var date: Date = Date()
    var ticketNumber: String = ""
    var zones: String = ""
    var fare: String = ""

    /// Alternative routes returned by the latest `replan()`. Index 0
    /// is the optimal (fewest transfers, then fewest stops); later
    /// entries are different combinations the router considered —
    /// e.g. "subway only" vs "subway + bus transfer".
    /// Not Codable — `TransitLeg` lives in a non-Codable graph. The
    /// onboarding draft re-runs `replan()` on hydrate to rebuild this.
    var plannedRoutes: [[TransitLeg]] = []

    /// Which of `plannedRoutes` the user picked. Starts `nil` so the
    /// route dropdown surfaces its "Select a route…" placeholder
    /// after the stations are chosen; `replan()` auto-picks 0 when
    /// exactly one route is planned so single-route journeys don't
    /// force an extra tap.
    var selectedRouteIndex: Int? = nil

    /// Persisted fields. Excludes `plannedRoutes`, `catalogCity`,
    /// `operatorName` — those are recomputed by `replan()` after
    /// hydrating from a draft.
    private enum CodingKeys: String, CodingKey {
        case selectedCity
        case originStation
        case destinationStation
        case date
        case ticketNumber
        case zones
        case fare
        case selectedRouteIndex
    }

    /// Convenience — the legs of the currently-selected route.
    var plannedLegs: [TransitLeg] {
        guard
            let idx = selectedRouteIndex,
            plannedRoutes.indices.contains(idx)
        else { return [] }
        return plannedRoutes[idx]
    }

    /// True once a route has been picked. Gates the form's Next
    /// button, so the rider can't advance with stations but no
    /// chosen route.
    var isValid: Bool { !plannedLegs.isEmpty }

    /// Catalog currently feeding the router. Resolved from the
    /// origin's city on `replan()` so Vienna picks run against
    /// Vienna.json, not (e.g.) a future Paris.json.
    var catalogCity: TransitCatalogLoader.City? = nil

    /// Operator name resolved alongside the matched catalog.
    var operatorName: String = ""

    /// Re-runs the router whenever the two stations or the catalog
    /// change. Call from `.onChange` on either station binding.
    @MainActor
    mutating func replan() {
        plannedRoutes = []
        selectedRouteIndex = nil
        catalogCity = nil
        operatorName = ""

        guard
            let origin = originStation,
            let destination = destinationStation
        else { return }

        // The user picks the city explicitly via the dropdown at the
        // top of the form; fall back to MapKit-reported city only if
        // the dropdown was never touched (legacy edit path).
        let resolvedCatalog: TransitCatalog?
        if let city = selectedCity {
            resolvedCatalog = TransitCatalogLoader.catalog(for: city)
        } else {
            let cityHint = origin.city ?? destination.city ?? ""
            resolvedCatalog = TransitCatalogLoader.catalog(forCityHint: cityHint)
        }
        guard let catalog = resolvedCatalog else { return }

        catalogCity = selectedCity
            ?? TransitCatalogLoader.City.allCases.first(where: {
                TransitCatalogLoader.catalog(for: $0)?.city == catalog.city
            })
        operatorName = catalog.operatorName

        guard
            let originNode = catalog.resolveStation(
                name: origin.name, lat: origin.lat, lng: origin.lng
            ),
            let destNode = catalog.resolveStation(
                name: destination.name, lat: destination.lat, lng: destination.lng
            )
        else { return }

        plannedRoutes = TransitRouter.routes(
            from: originNode,
            to: destNode,
            in: catalog,
            max: 4
        )

        // When only one route was found, pick it automatically — no
        // decision for the rider to make. Multi-route journeys keep
        // `selectedRouteIndex == nil` so the route dropdown shows
        // its placeholder and forces an explicit pick.
        if plannedRoutes.count == 1 {
            selectedRouteIndex = 0
        }
    }

    /// One `UndergroundTicket` payload per planned leg. The funnel
    /// creates ticket #1 through the standard persist path; anything
    /// beyond the first is handed to the presenter, which persists
    /// the rest after the first succeeds.
    var legPayloads: [UndergroundTicket] {
        let dateString = Self.dateFormatter.string(from: date)
        return plannedLegs.enumerated().map { idx, leg in
            // Ticket numbers are auto-suffixed per leg so the user
            // can see them as "ABC123XYZ-1", "-2"… without retyping.
            let baseTicket = ticketNumber
                .trimmingCharacters(in: .whitespaces)
            let ticketNum = plannedLegs.count > 1 && !baseTicket.isEmpty
                ? "\(baseTicket)-\(idx + 1)"
                : baseTicket
            return UndergroundTicket(
                lineShortName: leg.line.shortName,
                lineName: leg.line.longName,
                // Multi-operator cities (e.g. Tokyo: Metro + Toei) carry
                // a per-line operator on the catalog. Prefer that so a
                // Marunouchi ticket reads "Tokyo Metro" even when the
                // journey also touches a Toei line.
                companyName: leg.line.operator ?? operatorName,
                lineColor: leg.line.color,
                originStation: leg.origin.name,
                destinationStation: leg.destination.name,
                stopsCount: leg.stopsCount,
                date: dateString,
                ticketNumber: ticketNum,
                zones: zones,
                fare: fare,
                mode: leg.line.mode
            )
        }
    }

    /// `(origin, destination)` `TicketLocation` pairs — one per leg —
    /// so each persisted ticket carries the right pin for the memory
    /// map. City / country / countryCode inherit from the user-picked
    /// origin so every leg tags the same metro area.
    var legLocationPairs: [(origin: TicketLocation, destination: TicketLocation)] {
        let city = originStation?.city ?? destinationStation?.city
        let country = originStation?.country ?? destinationStation?.country
        let countryCode = originStation?.countryCode ?? destinationStation?.countryCode
        return plannedLegs.map { leg in
            let o = TicketLocation(
                name: leg.origin.name,
                subtitle: nil,
                city: city,
                country: country,
                countryCode: countryCode,
                lat: leg.origin.lat,
                lng: leg.origin.lng,
                kind: .station
            )
            let d = TicketLocation(
                name: leg.destination.name,
                subtitle: nil,
                city: city,
                country: country,
                countryCode: countryCode,
                lat: leg.destination.lat,
                lng: leg.destination.lng,
                kind: .station
            )
            return (o, d)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        return f
    }()
}

// MARK: - Funnel

@MainActor
final class NewTicketFunnel: ObservableObject {

    // MARK: Navigation

    @Published var step: NewTicketStep = .category

    /// Wall-clock time the funnel opened. Used for Ticket Funnel Abandoned
    /// duration reporting. Not observed — we only read it once on dismiss.
    let startedAt: Date = Date()

    // MARK: Selections

    @Published var category: TicketCategory? = nil
    @Published var template: TicketTemplateKind? = nil {
        didSet {
            // Style ids are namespaced per template ("studio.dark"), so a
            // selection from a previous template never applies to the next
            // one. Clear it whenever the template changes.
            if oldValue != template { selectedStyleId = nil }
        }
    }
    @Published var orientation: TicketOrientation = .horizontal
    @Published var form: FlightFormInput = FlightFormInput()
    @Published var trainForm: TrainFormInput = TrainFormInput()
    @Published var eventForm: EventFormInput = EventFormInput()
    @Published var eurovisionForm: EurovisionFormInput = EurovisionFormInput()
    @Published var undergroundForm: UndergroundFormInput = UndergroundFormInput()
    /// Identifier of the selected style variant for the chosen template.
    /// Resolved against `template.styles`; nil before a template is picked.
    @Published var selectedStyleId: String? = nil

    // MARK: Import

    /// Non-nil when the funnel was launched from an import entry point.
    /// Inserts the `.import` step after orientation and tags the
    /// `TicketCreated` analytics event on save.
    @Published var importSource: ImportSource? = nil
    /// One-shot flag: set by `applyImportFailure()` so the form step can
    /// surface a "couldn't detect fields" banner on first appearance.
    @Published var importFailureBanner: Bool = false
    /// Pre-delivered `.pkpass` payload when the funnel was launched via
    /// the share sheet (Wallet / Mail / AirDrop). The import step
    /// auto-parses this on appear and never shows the file picker.
    /// Consumed once — cleared once the parser runs.
    @Published var pendingPassData: Data? = nil

    /// Parsed share-extension payload pre-loaded into the funnel.
    /// Consumed once by ImportStep, then cleared.
    @Published var pendingShareImport: ShareImportResult? = nil

    // MARK: Persistence

    @Published var isSaving: Bool = false
    @Published var createdTicket: Ticket? = nil
    /// All tickets created in this funnel run. For single-leg
    /// templates this is `[createdTicket]`; for multi-leg underground
    /// journeys it contains one entry per line change.
    @Published var createdTickets: [Ticket] = []
    @Published var errorMessage: String? = nil

    // MARK: Editing

    /// When non-nil, `persist(using:)` updates this ticket in place
    /// instead of inserting a new one. Set via `prefill(from:)`.
    @Published private(set) var editingTicketId: UUID? = nil
    private var editingOriginal: Ticket? = nil

    /// True once the caller has requested an edit flow. The view uses
    /// this to skip the create-analytics fire on appear.
    var isEditing: Bool { editingTicketId != nil }

    // MARK: - Availability

    /// Variants available for the currently chosen template.
    var availableStyles: [TicketStyleVariant] {
        template?.styles ?? []
    }

    /// Style step is only worth showing when there are multiple variants.
    var hasStylesStep: Bool {
        guard let template else { return false }
        return template.hasStyleVariants
    }

    /// Style applied to the live preview — falls back to the template's
    /// default when nothing has been picked yet.
    var resolvedStyle: TicketStyleVariant? {
        template?.resolveStyle(id: selectedStyleId)
    }

    // MARK: - Next / Back logic

    /// Whether the current step's Next button should be enabled.
    var canAdvance: Bool {
        switch step {
        case .category:    return category?.isAvailable == true
        case .template:    return template != nil
        case .orientation: return true
        // Import step advances programmatically once parsing finishes —
        // the bottom "Next" button stays disabled so the user can't skip
        // ahead without picking a file or tapping "Fill manually".
        case .import:      return false
        case .form:
            switch template {
            case .express:      return trainForm.isExpressValid
            case .orient:       return trainForm.isOrientValid
            case .night:        return trainForm.isNightValid
            case .post, .glow:  return trainForm.isPostGlowValid
            case .concert:      return eventForm.isConcertValid
            case .eurovision:   return eurovisionForm.isValid
            case .underground, .sign, .infoscreen, .grid:
                return undergroundForm.isValid
            default:            return form.isMinimallyValid
            }
        case .style:       return true
        case .success:     return true
        }
    }

    func advance() {
        guard canAdvance else { return }

        switch step {
        case .category:    step = .template
        case .template:    step = .orientation
        case .orientation: step = importSource != nil ? .import : .form
        case .import:      step = .form
        case .form:
            // Fill aesthetic placeholders into blank optional fields so
            // the rendered ticket always looks finished. `autoFilledFields`
            // drives a notice on the success step so the user knows what
            // we touched.
            applyAestheticDefaults()
            step = hasStylesStep ? .style : .success
        case .style:       step = .success
        case .success:     return
        }
    }

    // MARK: - Auto-fill

    /// Field labels that were filled with placeholder values in the
    /// current advance() pass, so the success step can surface a tip.
    /// Cleared every time the form step is re-entered.
    @Published var autoFilledFields: [String] = []

    /// Fills blank optional fields with template-appropriate placeholder
    /// values and records the labels in `autoFilledFields`. Required
    /// fields are never touched (they're gated by `canAdvance`). Runs on
    /// both create (from `advance()`) and edit (from `updateExisting`),
    /// so a user who clears Fare / Zones / Ticket on an existing ticket
    /// gets the city-appropriate placeholders back instead of an empty
    /// dash on the rendered ticket.
    private func applyAestheticDefaults() {
        autoFilledFields = []
        guard let template else { return }
        let trim: (String) -> String = { $0.trimmingCharacters(in: .whitespaces) }

        switch template {
        case .concert:
            if trim(eventForm.tourName).isEmpty {
                eventForm.tourName = "World Tour 2026"
                autoFilledFields.append(String(localized: "Tour name"))
            }
            if trim(eventForm.ticketNumber).isEmpty {
                eventForm.ticketNumber = Self.randomRef(prefix: "CON")
                autoFilledFields.append(String(localized: "Ticket number"))
            }

        case .eurovision:
            // Only fill the slot the chosen attendance mode actually
            // renders — leaving the other field blank keeps the
            // payload honest and the success-step "we filled X / Y / Z"
            // banner from listing fields the rendered ticket ignores.
            switch eurovisionForm.attendance {
            case .inPerson:
                if trim(eurovisionForm.section).isEmpty {
                    eurovisionForm.section = String(localized: "Floor")
                    autoFilledFields.append(String(localized: "Area"))
                }
                if trim(eurovisionForm.row).isEmpty {
                    eurovisionForm.row = "GA"
                    autoFilledFields.append(String(localized: "Row"))
                }
                if trim(eurovisionForm.seat).isEmpty {
                    eurovisionForm.seat = String(localized: "OPEN")
                    autoFilledFields.append(String(localized: "Seat"))
                }
            case .atHome:
                if trim(eurovisionForm.watchLocation).isEmpty {
                    eurovisionForm.watchLocation = String(localized: "At home")
                    autoFilledFields.append(String(localized: "Location"))
                }
            }
            if trim(eurovisionForm.ticketNumber).isEmpty {
                eurovisionForm.ticketNumber = Self.randomRef(prefix: "ESC")
                autoFilledFields.append(String(localized: "Ticket number"))
            }

        case .afterglow, .studio, .terminal, .heritage:
            if trim(form.gate).isEmpty {
                form.gate = Self.randomGate()
                autoFilledFields.append(String(localized: "Gate"))
            }
            if trim(form.seat).isEmpty {
                form.seat = Self.randomSeatNumberLetter()
                autoFilledFields.append(String(localized: "Seat"))
            }

        case .prism:
            if trim(form.gate).isEmpty {
                form.gate = Self.randomGate()
                autoFilledFields.append(String(localized: "Gate"))
            }
            if trim(form.seat).isEmpty {
                form.seat = Self.randomSeatNumberLetter()
                autoFilledFields.append(String(localized: "Seat"))
            }
            if trim(form.terminal).isEmpty {
                form.terminal = Self.randomPlaneTerminal()
                autoFilledFields.append(String(localized: "Terminal"))
            }

        case .post, .glow, .orient:
            if trim(trainForm.car).isEmpty {
                trainForm.car = Self.randomCar()
                autoFilledFields.append(String(localized: "Car"))
            }
            if trim(trainForm.seat).isEmpty {
                trainForm.seat = Self.randomSeatNumber()
                autoFilledFields.append(String(localized: "Seat"))
            }

        case .express:
            if trim(trainForm.car).isEmpty {
                trainForm.car = Self.randomCar()
                autoFilledFields.append(String(localized: "Car"))
            }
            if trim(trainForm.seat).isEmpty {
                trainForm.seat = Self.randomSeatNumberLetter()
                autoFilledFields.append(String(localized: "Seat"))
            }

        case .night:
            if trim(trainForm.car).isEmpty {
                trainForm.car = Self.randomCar()
                autoFilledFields.append(String(localized: "Car"))
            }
            if trim(trainForm.berth).isEmpty {
                trainForm.berth = Self.randomBerth()
                autoFilledFields.append(String(localized: "Berth"))
            }

        case .underground, .sign, .infoscreen, .grid:
            if trim(undergroundForm.ticketNumber).isEmpty {
                undergroundForm.ticketNumber = Self.randomTransitTicketNumber()
                autoFilledFields.append(String(localized: "Ticket number"))
            }
            if trim(undergroundForm.zones).isEmpty {
                undergroundForm.zones = String(localized: "All zones")
                autoFilledFields.append(String(localized: "Zones"))
            }
            if trim(undergroundForm.fare).isEmpty {
                undergroundForm.fare = Self.defaultFare(
                    for: undergroundForm.selectedCity
                )
                autoFilledFields.append(String(localized: "Fare"))
            }
        }
    }

    /// Generates a pseudo-realistic ticket reference like "CON-2026-081742".
    /// Seeded from the current Date so identical advances produce different
    /// strings, which keeps demo tickets from looking cloned.
    private static func randomRef(prefix: String) -> String {
        let year = Calendar.current.component(.year, from: Date())
        let suffix = Int.random(in: 10_000...999_999)
        return "\(prefix)-\(year)-\(String(format: "%06d", suffix))"
    }

    /// Pure `[A-Z0-9]` reference for transit tickets — operator-issued
    /// tags rarely embed dates / agency prefixes the way concert tickets
    /// do, so we drop them here for a more authentic look.
    private static func randomTransitTicketNumber(length: Int = 10) -> String {
        let chars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        return String((0..<length).compactMap { _ in chars.randomElement() })
    }

    // MARK: - Plane / train slot generators

    /// Plane gate, e.g. "A12", "F32". Letters A–H × 1…60.
    private static func randomGate() -> String {
        let letter = "ABCDEFGH".randomElement()!
        return "\(letter)\(Int.random(in: 1...60))"
    }

    /// Airline-style seat, e.g. "1A", "14C", "27K". Skips letter "I"
    /// per airline convention.
    private static func randomSeatNumberLetter() -> String {
        let row = Int.random(in: 1...40)
        let letter = "ABCDEFGHJK".randomElement()!
        return "\(row)\(letter)"
    }

    /// European-rail style seat — number only, e.g. "47".
    private static func randomSeatNumber() -> String {
        "\(Int.random(in: 1...80))"
    }

    /// Plane terminal label, e.g. "T3". Range T1…T5 covers the
    /// realistic span for the templates we ship.
    private static func randomPlaneTerminal() -> String {
        "T\(Int.random(in: 1...5))"
    }

    /// Train carriage / car number, e.g. "7", "12". Range 1…18 covers
    /// typical European inter-city consist lengths.
    private static func randomCar() -> String {
        "\(Int.random(in: 1...18))"
    }

    /// Sleeper-train berth label.
    private static func randomBerth() -> String {
        ["Lower", "Upper", "Single", "Cabin"].randomElement()!
    }

    /// Hard-coded single-ride fares per supported city, formatted in the
    /// local currency. Approximate snapshot at time of writing — refresh
    /// when operators raise prices. Used as the auto-filled placeholder
    /// when the user leaves the Fare field empty.
    private static func defaultFare(for city: TransitCatalogLoader.City?) -> String {
        guard let city else { return "—" }
        switch city {
        case .vienna:    return "2.40 €"
        case .newYork:   return "$2.90"
        case .paris:     return "2.15 €"
        case .nantes:    return "1.80 €"
        case .lyon:      return "2.10 €"
        case .bordeaux:  return "1.80 €"
        case .marseille: return "2.10 €"
        case .zurich:    return "2.80 CHF"
        case .berlin:    return "3.80 €"
        case .london:    return "£2.80"
        case .stockholm: return "42 kr"
        case .tokyo:     return "¥180"
        case .melbourne: return "A$5.50"
        }
    }

    func goBack() {
        switch step {
        case .category:    return
        case .template:    step = .category
        case .orientation: step = .template
        case .import:      step = .orientation
        case .form:        step = importSource != nil ? .import : .orientation
        case .style:       step = .form
        case .success:     step = hasStylesStep ? .style : .form
        }
    }

    // MARK: - Onboarding draft snapshot / hydrate

    /// Captures user-facing funnel state for `OnboardingFunnelDraftStore`.
    /// Excludes transient flags (isSaving, errorMessage) and the
    /// multi-leg `createdTickets` (only `createdTicketId` survives —
    /// the resume path re-fetches the row from `TicketsStore`).
    func snapshot(createdTicketId: UUID?) -> OnboardingFunnelDraft {
        OnboardingFunnelDraft(
            step: step,
            category: category,
            template: template,
            orientation: orientation,
            form: form,
            trainForm: trainForm,
            eventForm: eventForm,
            eurovisionForm: eurovisionForm,
            undergroundForm: undergroundForm,
            selectedStyleId: selectedStyleId,
            createdTicketId: createdTicketId
        )
    }

    /// Replays a snapshot onto a freshly-constructed funnel. Caller is
    /// responsible for setting `createdTicket` separately (it requires
    /// fetching the saved row from `TicketsStore` first).
    func hydrate(from draft: OnboardingFunnelDraft) {
        category = draft.category
        template = draft.template
        orientation = draft.orientation
        form = draft.form
        trainForm = draft.trainForm
        eventForm = draft.eventForm
        eurovisionForm = draft.eurovisionForm ?? EurovisionFormInput()
        undergroundForm = draft.undergroundForm
        // Underground routes aren't Codable — recompute them from the
        // restored station/city inputs so the form's route picker has
        // something to show on resume.
        undergroundForm.replan()
        selectedStyleId = draft.selectedStyleId
        step = draft.step
    }

    // MARK: - Import apply

    /// Writes a parsed importer result onto the appropriate form input
    /// and advances to `.form`. Silently ignores kind mismatches — the
    /// import UI layer already guards transit-type vs. template before
    /// calling in, so this is a defensive fallthrough.
    func applyImported(_ result: ImportResult) {
        switch result {
        case .flight(let f):
            form = f
        case .train(let t):
            trainForm = t
            // Train station fields bind to a full `TicketLocation`
            // with lat/lng, but pkpass files only carry station names.
            // Resolve them via MapKit so the picker shows the station
            // and the ticket lands on the memory map.
            Task { await resolveTrainStations() }
        }
        importFailureBanner = false
        step = .form
    }

    /// Apply a parsed share-extension payload to the appropriate form
    /// input and advance to `.form`. Translates primitive fields into
    /// `FlightFormInput` / `EventFormInput` via `ShareImportTranslator`.
    /// Kicks off a MapKit lookup for the venue when one is present so
    /// the form opens with a validated `TicketLocation` (city + map
    /// pin) instead of just a search-field hint.
    func applyShareImport(_ result: ShareImportResult) {
        if let flightFields = result.flight {
            form = ShareImportTranslator.flightInput(from: flightFields)
        }
        if let eventFields = result.event {
            eventForm = ShareImportTranslator.eventInput(from: eventFields)
            Task { await resolveImportedVenue() }
        }
        importFailureBanner = false
        step = .form
    }

    /// Resolves the OCR'd venue name against MapKit so the share
    /// extension's import auto-populates the venue picker (city,
    /// country, lat/lng) when the model returned a real venue. Only
    /// commits the result when the resolved POI's name matches the
    /// query — ambiguous searches leave the seeded query in place
    /// for the user to confirm manually.
    private func resolveImportedVenue() async {
        guard eventForm.venueLocation == nil else { return }
        let query = eventForm.venue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        if let loc = await Self.lookupVenue(named: query) {
            eventForm.venueLocation = loc
            eventForm.venue = loc.name
        }
    }

    private static func lookupVenue(named name: String) async -> TicketLocation? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.resultTypes = [.pointOfInterest]
        // No POI filter — venues span stadiums, theatres, clubs,
        // parks, conference halls. Letting MapKit return any POI
        // mirrors what `LumoriaVenueField` does interactively.
        do {
            let response = try await MKLocalSearch(request: request).start()
            guard let item = response.mapItems.first else { return nil }
            let coord = item.placemark.coordinate
            let resolvedName = (item.name ?? trimmed)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            // Confidence gate: only auto-commit when the resolved
            // name and the query overlap. This avoids stamping the
            // user's form with a totally unrelated POI when MapKit
            // falls back to fuzzy/regional matches.
            let queryLower = trimmed.lowercased()
            let nameLower = resolvedName.lowercased()
            let overlaps = nameLower.contains(queryLower)
                || queryLower.contains(nameLower)
                || queryLower.split(separator: " ").contains {
                    !$0.isEmpty && nameLower.contains($0.lowercased())
                }
            guard overlaps else { return nil }
            return TicketLocation(
                name: resolvedName,
                subtitle: nil,
                city: item.placemark.locality,
                country: item.placemark.country,
                countryCode: item.placemark.isoCountryCode,
                lat: coord.latitude,
                lng: coord.longitude,
                kind: .venue
            )
        } catch {
            return nil
        }
    }

    private func resolveTrainStations() async {
        if trainForm.originStationLocation == nil {
            let query = trainForm.originStation.isEmpty
                ? trainForm.originCity
                : trainForm.originStation
            if let loc = await Self.lookupStation(named: query) {
                trainForm.originStationLocation = loc
                trainForm.originStation = loc.name
                if let city = loc.city, !city.isEmpty {
                    trainForm.originCity = city
                }
            }
        }
        if trainForm.destinationStationLocation == nil {
            let query = trainForm.destinationStation.isEmpty
                ? trainForm.destinationCity
                : trainForm.destinationStation
            if let loc = await Self.lookupStation(named: query) {
                trainForm.destinationStationLocation = loc
                trainForm.destinationStation = loc.name
                if let city = loc.city, !city.isEmpty {
                    trainForm.destinationCity = city
                }
            }
        }
    }

    private static func lookupStation(named name: String) async -> TicketLocation? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.resultTypes = [.pointOfInterest]
        request.pointOfInterestFilter =
            MKPointOfInterestFilter(including: [.publicTransport])
        do {
            let response = try await MKLocalSearch(request: request).start()
            guard let item = response.mapItems.first else { return nil }
            let coord = item.placemark.coordinate
            let clean = StationSearchModel.cleanName(item.name ?? trimmed)
            return TicketLocation(
                name: clean,
                subtitle: nil,
                city: item.placemark.locality,
                country: item.placemark.country,
                countryCode: item.placemark.isoCountryCode,
                lat: coord.latitude,
                lng: coord.longitude,
                kind: .station
            )
        } catch {
            return nil
        }
    }

    /// Called when the user bails on the import (parser returned nil, or
    /// they tapped "Fill manually"). Drops `importSource` so the form
    /// step's Back button returns to orientation rather than re-entering
    /// the import picker, and raises the one-shot banner.
    func applyImportFailure() {
        importFailureBanner = true
        importSource = nil
        step = .form
    }

    // MARK: - Payload build

    /// Converts the current form + selections into a concrete template
    /// payload. Returns nil if no template has been chosen.
    func buildPayload() -> TicketPayload? {
        guard let template else { return nil }
        let f = form
        let dateLong  = Self.longDate(f.departureDate)
        let dateShort = Self.shortDate(f.departureDate)
        let depTime   = Self.time(f.departureTime)
        // Plane templates render a "Boards" field that is always departureTime − 30min.
        // Not user-entered, not read from PKPass — derived here so the form stays
        // simple and the rendered ticket is always internally consistent.
        let boardTime = Self.time(f.departureTime.addingTimeInterval(-30 * 60))
        let flightNumber = f.composedFlightNumber
        let ticketNumber = f.aircraft.isEmpty
            ? flightNumber
            : "\(flightNumber) · \(f.aircraft)"

        switch template {
        case .afterglow:
            return .afterglow(AfterglowTicket(
                airline: f.airline,
                flightNumber: flightNumber,
                origin: f.originCode,
                originCity: f.originName,
                destination: f.destinationCode,
                destinationCity: f.destinationName,
                date: dateLong,
                gate: f.gate,
                seat: f.seat,
                boardingTime: boardTime
            ))
        case .studio:
            return .studio(StudioTicket(
                airline: f.airline,
                flightNumber: flightNumber,
                cabinClass: f.cabinClass.isEmpty ? "Class" : f.cabinClass,
                origin: f.originCode,
                originName: f.originName,
                originLocation: f.originLocation,
                destination: f.destinationCode,
                destinationName: f.destinationName,
                destinationLocation: f.destinationLocation,
                date: dateLong,
                gate: f.gate,
                seat: f.seat,
                departureTime: depTime
            ))
        case .heritage:
            return .heritage(HeritageTicket(
                airline: f.airline,
                ticketNumber: ticketNumber,
                cabinClass: f.cabinClass.isEmpty ? "Class" : f.cabinClass,
                cabinDetail: f.cabinDetail,
                origin: f.originCode,
                originName: f.originName,
                originLocation: f.originLocation,
                destination: f.destinationCode,
                destinationName: f.destinationName,
                destinationLocation: f.destinationLocation,
                flightDuration: f.flightDuration,
                gate: f.gate,
                seat: f.seat,
                boardingTime: boardTime,
                departureTime: depTime,
                date: dateShort,
                fullDate: dateLong
            ))
        case .terminal:
            return .terminal(TerminalTicket(
                airline: f.airline,
                ticketNumber: ticketNumber,
                cabinClass: f.cabinClass.isEmpty ? "Business" : f.cabinClass,
                origin: f.originCode,
                originName: f.originName,
                originLocation: f.originLocation,
                destination: f.destinationCode,
                destinationName: f.destinationName,
                destinationLocation: f.destinationLocation,
                gate: f.gate,
                seat: f.seat,
                boardingTime: boardTime,
                departureTime: depTime,
                date: dateShort,
                fullDate: dateLong
            ))
        case .prism:
            return .prism(PrismTicket(
                airline: f.airline,
                ticketNumber: ticketNumber,
                date: dateLong,
                origin: f.originCode,
                originName: f.originName,
                destination: f.destinationCode,
                destinationName: f.destinationName,
                gate: f.gate,
                seat: f.seat,
                boardingTime: boardTime,
                departureTime: depTime,
                terminal: f.terminal
            ))
        case .express:
            let t = trainForm
            return .express(ExpressTicket(
                trainType: t.trainType,
                trainNumber: t.trainNumber,
                cabinClass: t.cabinClass.isEmpty ? "Class" : t.cabinClass,
                originCity: t.originCity,
                originCityKanji: t.originCityKanji,
                destinationCity: t.destinationCity,
                destinationCityKanji: t.destinationCityKanji,
                date: Self.trainDate(t.date),
                departureTime: Self.time(t.departureTime),
                arrivalTime: Self.time(t.arrivalTime),
                car: t.car,
                seat: t.seat,
                ticketNumber: t.ticketNumber
            ))
        case .orient:
            let t = trainForm
            return .orient(OrientTicket(
                company: t.company,
                cabinClass: t.cabinClass.isEmpty ? "Class" : t.cabinClass,
                originCity: t.originCity,
                originStation: t.originStation,
                destinationCity: t.destinationCity,
                destinationStation: t.destinationStation,
                passenger: t.passenger,
                ticketNumber: t.ticketNumber,
                date: Self.longDate(t.date),
                departureTime: Self.time(t.departureTime),
                carriage: t.car,
                seat: t.seat
            ))
        case .night:
            let t = trainForm
            // Night tickets combine date + time into a single "Departs"
            // string ("14 Mar 2026 · 22:04"). Train "code" reuses the
            // existing trainNumber slot on the shared form input.
            let departs = "\(Self.shortDate(t.date)) · \(Self.time(t.departureTime))"
            return .night(NightTicket(
                company: t.company,
                trainType: t.trainType,
                trainCode: t.trainNumber,
                originCity: t.originCity,
                originStation: t.originStation,
                destinationCity: t.destinationCity,
                destinationStation: t.destinationStation,
                passenger: t.passenger,
                car: t.car,
                berth: t.berth,
                date: departs,
                ticketNumber: t.ticketNumber
            ))
        case .post:
            let t = trainForm
            return .post(PostTicket(
                trainNumber: t.trainNumber,
                trainType: t.trainType,
                originCity: t.originCity,
                originStation: t.originStation,
                destinationCity: t.destinationCity,
                destinationStation: t.destinationStation,
                date: Self.postDate(t.date),
                departureTime: Self.time(t.departureTime),
                car: t.car,
                seat: t.seat
            ))
        case .glow:
            let t = trainForm
            return .glow(GlowTicket(
                trainNumber: t.trainNumber,
                trainType: t.trainType,
                originCity: t.originCity,
                originStation: t.originStation,
                destinationCity: t.destinationCity,
                destinationStation: t.destinationStation,
                date: Self.postDate(t.date),
                departureTime: Self.time(t.departureTime),
                car: t.car,
                seat: t.seat
            ))
        case .concert:
            let e = eventForm
            return .concert(ConcertTicket(
                artist: e.artist,
                tourName: e.tourName,
                venue: e.venue,
                date: Self.longDate(e.date),
                doorsTime: Self.time(e.doorsTime),
                showTime: Self.time(e.showTime),
                ticketNumber: e.ticketNumber
            ))
        case .eurovision:
            // Date and venue are pinned to the real-world Eurovision
            // 2026 final — see `EurovisionFixtures` below. The country
            // string persists as the ISO alpha-2 code so the rendered
            // ticket can resolve `eurovision-bg-<code>` and
            // `eurovision-logo-<code>` without a separate lookup table.
            let e = eurovisionForm
            let country = e.country
            return .eurovision(EurovisionTicket(
                countryCode: country?.isoCode ?? "",
                countryName: country?.displayName ?? "",
                date: Self.eurovisionDateString,
                venue: EurovisionFixtures.venue,
                attendance: e.attendance.rawValue,
                section: e.section,
                row: e.row,
                seat: e.seat,
                watchLocation: e.watchLocation,
                ticketNumber: e.ticketNumber
            ))
        case .underground:
            // The funnel emits one `UndergroundTicket` per planned leg
            // (see `undergroundForm.legPayloads`). `buildPayload` only
            // returns the first so the shared create/update path can
            // round-trip through the existing single-ticket machinery;
            // the presenter persists any additional legs separately.
            return undergroundForm.legPayloads.first.map(TicketPayload.underground)
        case .sign:
            return undergroundForm.legPayloads.first.map(TicketPayload.sign)
        case .infoscreen:
            return undergroundForm.legPayloads.first.map(TicketPayload.infoscreen)
        case .grid:
            return undergroundForm.legPayloads.first.map(TicketPayload.grid)
        }
    }

    /// Wraps an `UndergroundTicket` in the right `TicketPayload`
    /// case for the currently-selected public-transport template.
    static func transitPayload(
        template: TicketTemplateKind,
        ticket: UndergroundTicket
    ) -> TicketPayload? {
        switch template {
        case .underground: return .underground(ticket)
        case .sign:        return .sign(ticket)
        case .infoscreen:  return .infoscreen(ticket)
        case .grid:        return .grid(ticket)
        default:           return nil
        }
    }

    // MARK: - Persistence

    /// Persists the current selections. Creates a new ticket when the
    /// funnel was started fresh, updates in place when started via
    /// `prefill(from:)`. Sets `createdTicket` on success so the
    /// success step's reveal animation runs either way.
    func persist(using store: TicketsStore) async {
        if editingTicketId != nil {
            await updateExisting(using: store)
        } else {
            await createNew(using: store)
        }
    }

    private func createNew(using store: TicketsStore) async {
        guard createdTicket == nil else { return }

        // Public-transport journeys can span multiple legs (A→B on
        // U1, B→C on U3…). Each leg becomes its own persisted
        // ticket so the rider keeps every line / colour / stop
        // count on the memory map. All three template kinds
        // (signal / sign / infoscreen) share the same leg payload,
        // differing only in which `TicketPayload` case they wrap.
        if template == .underground || template == .sign || template == .infoscreen || template == .grid {
            await createUndergroundTickets(using: store)
            return
        }

        guard let payload = buildPayload() else {
            errorMessage = String(localized: "Missing ticket data.")
            return
        }
        isSaving = true
        defer { isSaving = false }

        let (origin, destination) = resolveLocations()
        let ticket = await store.create(
            payload: payload,
            orientation: orientation,
            originLocation: origin,
            destinationLocation: destination,
            styleId: selectedStyleId ?? template?.defaultStyle.id,
            eventDate: currentEventDate
        )
        if let ticket {
            createdTicket = ticket
            createdTickets = [ticket]
            errorMessage = nil
        } else {
            errorMessage = store.errorMessage ?? "Couldn’t save ticket."
        }
    }

    /// Creates one `UndergroundTicket` per planned leg. Stops on the
    /// first failure so the user isn't left with a half-persisted
    /// journey.
    private func createUndergroundTickets(using store: TicketsStore) async {
        let payloads = undergroundForm.legPayloads
        let locations = undergroundForm.legLocationPairs

        guard !payloads.isEmpty else {
            errorMessage = String(localized: "Missing ticket data.")
            return
        }

        isSaving = true
        defer { isSaving = false }

        // Pick the template-specific fallback styleId so an
        // infoscreen ticket persists as `infoscreen.default` rather
        // than `underground.default`.
        let activeTemplate = template ?? .underground
        let styleId = selectedStyleId ?? activeTemplate.defaultStyle.id

        // Collect locally first, then commit all at once. Appending leg-
        // by-leg to `createdTickets` causes the SuccessStep to remount
        // its preview from `TicketSaveRevealView` (count == 1) to
        // `TicketStackCarousel` (count > 1) mid-persist, so the carousel
        // snapshots a partial array and never prints later legs. One
        // atomic assignment means the carousel sees the full set on
        // first render.
        var collected: [Ticket] = []

        for (idx, payload) in payloads.enumerated() {
            let pair = idx < locations.count ? locations[idx] : nil
            guard let wrapped = Self.transitPayload(
                template: activeTemplate,
                ticket: payload
            ) else {
                errorMessage = String(localized: "Unsupported transit template.")
                return
            }
            let ticket = await store.create(
                payload: wrapped,
                orientation: orientation,
                originLocation: pair?.origin,
                destinationLocation: pair?.destination,
                styleId: styleId,
                eventDate: undergroundForm.date
            )
            guard let ticket else {
                errorMessage = store.errorMessage
                    ?? String(localized: "Couldn’t save ticket \(idx + 1) of \(payloads.count).")
                return
            }
            collected.append(ticket)
        }

        createdTickets = collected
        createdTicket = collected.first
        errorMessage = nil
    }

    private func updateExisting(using store: TicketsStore) async {
        guard createdTicket == nil else { return }
        guard let updated = buildUpdatedTicket() else {
            errorMessage = String(localized: "Missing ticket data.")
            return
        }
        isSaving = true
        defer { isSaving = false }

        let ok = await store.update(updated)
        if ok {
            createdTicket = updated
            errorMessage = nil
        } else {
            errorMessage = store.errorMessage ?? "Couldn’t save changes."
        }
    }

    /// Builds the edited ticket struct without touching the store. Used
    /// by the edit flow to hand a prepared ticket back to the presenter
    /// so the save + loader + refresh can run on the host view, not
    /// inside the (possibly already-dismissed) funnel.
    func buildUpdatedTicket() -> Ticket? {
        // Edit flow doesn't go through `advance()`, so re-fill cleared
        // optional fields here — otherwise a user who blanked Fare /
        // Zones / Ticket number would persist with empty meta cells.
        applyAestheticDefaults()
        guard let payload = buildPayload(),
              let original = editingOriginal else { return nil }
        let (origin, destination) = resolveLocations()
        return Ticket(
            id: original.id,
            createdAt: original.createdAt,
            updatedAt: Date(),
            orientation: orientation,
            payload: payload,
            memoryIds: original.memoryIds,
            originLocation: origin,
            destinationLocation: destination,
            styleId: selectedStyleId ?? template?.defaultStyle.id,
            eventDate: currentEventDate,
            addedAtByMemory: original.addedAtByMemory
        )
    }

    /// Canonical event date for the active template. Plane templates use
    /// `form.departureDate`; train templates use `trainForm.date`; concert
    /// uses `eventForm.date`; transit uses `undergroundForm.date`. Returns
    /// nil only if the funnel is in a bad state (no template).
    private var currentEventDate: Date? {
        switch template {
        case .express, .orient, .night, .post, .glow:
            return trainForm.date
        case .concert:
            return eventForm.date
        case .eurovision:
            return EurovisionFixtures.date
        case .underground, .sign, .infoscreen, .grid:
            return undergroundForm.date
        case .afterglow, .studio, .heritage, .terminal, .prism:
            return form.departureDate
        case .none:
            return nil
        }
    }

    /// Pre-formatted "16 May. 2026" string used by both the Eurovision
    /// payload and the form's read-only date field.
    fileprivate static let eurovisionDateString: String = {
        let f = DateFormatter()
        f.dateFormat = "d MMM. yyyy"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: EurovisionFixtures.date)
    }()

    /// Picks the right form's location slots for the current template.
    /// Plane templates use `form.{origin,destination}Airport`; train
    /// templates use `trainForm.{origin,destination}StationLocation`;
    /// single-venue templates (concert) put the venue in the origin
    /// slot and leave destination nil.
    private func resolveLocations() -> (TicketLocation?, TicketLocation?) {
        switch template {
        case .express, .orient, .night, .post, .glow:
            return (trainForm.originStationLocation, trainForm.destinationStationLocation)
        case .concert:
            return (eventForm.venueLocation, nil)
        case .eurovision:
            return (EurovisionFixtures.venueLocation, nil)
        case .underground, .sign, .infoscreen, .grid:
            // For multi-leg journeys, subsequent legs' stations sit
            // inside `legPayloads`. The "primary" leg (first) is what
            // the top-level ticket represents.
            return (undergroundForm.originStation, undergroundForm.destinationStation)
        default:
            return (form.originAirport, form.destinationAirport)
        }
    }

    // MARK: - Prefill (edit flow)

    /// Populates the funnel with an existing ticket's values and lands
    /// the user on the form step. Subsequent `persist` calls update
    /// the ticket in place rather than creating a new one.
    func prefill(from ticket: Ticket) {
        editingTicketId = ticket.id
        editingOriginal = ticket

        template = ticket.kind
        category = TicketCategory.allCases.first { $0.templates.contains(ticket.kind) }
        orientation = ticket.orientation
        selectedStyleId = ticket.styleId

        form = FlightFormInput()
        trainForm = TrainFormInput()
        eventForm = EventFormInput()
        eurovisionForm = EurovisionFormInput()

        switch ticket.payload {
        case .afterglow(let t):
            form.airline = t.airline
            form.flightNumber = t.flightNumber
            form.originCode = t.origin
            form.originName = t.originCity
            form.destinationCode = t.destination
            form.destinationName = t.destinationCity
            form.departureDate = Self.longDateFormatter.date(from: t.date) ?? Date()
            // Afterglow only persists boardingTime (= departure − 30min); add it back
            // so the form's departureTime matches what the user originally entered.
            let afterglowBoard = Self.timeFormatter.date(from: t.boardingTime) ?? Date()
            form.departureTime = afterglowBoard.addingTimeInterval(30 * 60)
            form.gate = t.gate
            form.seat = t.seat
            form.originAirport = ticket.originLocation
            form.destinationAirport = ticket.destinationLocation

        case .studio(let t):
            form.airline = t.airline
            form.flightNumber = t.flightNumber
            form.cabinClass = t.cabinClass
            form.originCode = t.origin
            form.originName = t.originName
            form.originLocation = t.originLocation
            form.destinationCode = t.destination
            form.destinationName = t.destinationName
            form.destinationLocation = t.destinationLocation
            form.departureDate = Self.longDateFormatter.date(from: t.date) ?? Date()
            form.departureTime = Self.timeFormatter.date(from: t.departureTime) ?? Date()
            form.gate = t.gate
            form.seat = t.seat
            form.originAirport = ticket.originLocation
            form.destinationAirport = ticket.destinationLocation

        case .heritage(let t):
            form.airline = t.airline
            form.cabinClass = t.cabinClass
            form.cabinDetail = t.cabinDetail
            form.originCode = t.origin
            form.originName = t.originName
            form.originLocation = t.originLocation
            form.destinationCode = t.destination
            form.destinationName = t.destinationName
            form.destinationLocation = t.destinationLocation
            form.flightDuration = t.flightDuration
            form.gate = t.gate
            form.seat = t.seat
            form.departureDate = Self.longDateFormatter.date(from: t.fullDate) ?? Date()
            form.departureTime = Self.timeFormatter.date(from: t.departureTime) ?? Date()
            Self.unpackTicketNumber(t.ticketNumber, into: &form)
            form.originAirport = ticket.originLocation
            form.destinationAirport = ticket.destinationLocation

        case .terminal(let t):
            form.airline = t.airline
            form.cabinClass = t.cabinClass
            form.originCode = t.origin
            form.originName = t.originName
            form.originLocation = t.originLocation
            form.destinationCode = t.destination
            form.destinationName = t.destinationName
            form.destinationLocation = t.destinationLocation
            form.gate = t.gate
            form.seat = t.seat
            form.departureDate = Self.longDateFormatter.date(from: t.fullDate) ?? Date()
            form.departureTime = Self.timeFormatter.date(from: t.departureTime) ?? Date()
            Self.unpackTicketNumber(t.ticketNumber, into: &form)
            form.originAirport = ticket.originLocation
            form.destinationAirport = ticket.destinationLocation

        case .prism(let t):
            form.airline = t.airline
            form.originCode = t.origin
            form.originName = t.originName
            form.destinationCode = t.destination
            form.destinationName = t.destinationName
            form.gate = t.gate
            form.seat = t.seat
            form.terminal = t.terminal
            form.departureDate = Self.longDateFormatter.date(from: t.date) ?? Date()
            form.departureTime = Self.timeFormatter.date(from: t.departureTime) ?? Date()
            Self.unpackTicketNumber(t.ticketNumber, into: &form)
            form.originAirport = ticket.originLocation
            form.destinationAirport = ticket.destinationLocation

        case .express(let t):
            trainForm.trainType = t.trainType
            trainForm.trainNumber = t.trainNumber
            trainForm.cabinClass = t.cabinClass
            trainForm.originCity = t.originCity
            trainForm.originCityKanji = t.originCityKanji
            trainForm.destinationCity = t.destinationCity
            trainForm.destinationCityKanji = t.destinationCityKanji
            trainForm.date = Self.trainDateFormatter.date(from: t.date) ?? Date()
            trainForm.departureTime = Self.timeFormatter.date(from: t.departureTime) ?? Date()
            trainForm.arrivalTime = Self.timeFormatter.date(from: t.arrivalTime) ?? Date()
            trainForm.car = t.car
            trainForm.seat = t.seat
            trainForm.ticketNumber = t.ticketNumber
            trainForm.originStationLocation = ticket.originLocation
            trainForm.destinationStationLocation = ticket.destinationLocation

        case .orient(let t):
            trainForm.company = t.company
            trainForm.cabinClass = t.cabinClass
            trainForm.originCity = t.originCity
            trainForm.originStation = t.originStation
            trainForm.destinationCity = t.destinationCity
            trainForm.destinationStation = t.destinationStation
            trainForm.passenger = t.passenger
            trainForm.ticketNumber = t.ticketNumber
            trainForm.date = Self.longDateFormatter.date(from: t.date) ?? Date()
            trainForm.departureTime = Self.timeFormatter.date(from: t.departureTime) ?? Date()
            trainForm.car = t.carriage
            trainForm.seat = t.seat
            trainForm.originStationLocation = ticket.originLocation
            trainForm.destinationStationLocation = ticket.destinationLocation

        case .night(let t):
            trainForm.company = t.company
            trainForm.trainType = t.trainType
            trainForm.trainNumber = t.trainCode
            trainForm.originCity = t.originCity
            trainForm.originStation = t.originStation
            trainForm.destinationCity = t.destinationCity
            trainForm.destinationStation = t.destinationStation
            trainForm.passenger = t.passenger
            trainForm.ticketNumber = t.ticketNumber
            trainForm.car = t.car
            trainForm.berth = t.berth
            // Night combines "dd MMM · HH:mm" into the payload's `date`.
            let parts = t.date.components(separatedBy: " · ")
            if let d = parts.first, let parsed = Self.shortDateFormatter.date(from: d) {
                trainForm.date = parsed
            }
            if parts.count >= 2, let parsed = Self.timeFormatter.date(from: parts[1]) {
                trainForm.departureTime = parsed
            }
            trainForm.originStationLocation = ticket.originLocation
            trainForm.destinationStationLocation = ticket.destinationLocation

        case .post(let t):
            trainForm.trainType = t.trainType
            trainForm.trainNumber = t.trainNumber
            trainForm.originCity = t.originCity
            trainForm.originStation = t.originStation
            trainForm.destinationCity = t.destinationCity
            trainForm.destinationStation = t.destinationStation
            trainForm.date = Self.postDateFormatter.date(from: t.date) ?? Date()
            trainForm.departureTime = Self.timeFormatter.date(from: t.departureTime) ?? Date()
            trainForm.car = t.car
            trainForm.seat = t.seat
            trainForm.originStationLocation = ticket.originLocation
            trainForm.destinationStationLocation = ticket.destinationLocation

        case .glow(let t):
            trainForm.trainType = t.trainType
            trainForm.trainNumber = t.trainNumber
            trainForm.originCity = t.originCity
            trainForm.originStation = t.originStation
            trainForm.destinationCity = t.destinationCity
            trainForm.destinationStation = t.destinationStation
            trainForm.date = Self.postDateFormatter.date(from: t.date) ?? Date()
            trainForm.departureTime = Self.timeFormatter.date(from: t.departureTime) ?? Date()
            trainForm.car = t.car
            trainForm.seat = t.seat
            trainForm.originStationLocation = ticket.originLocation
            trainForm.destinationStationLocation = ticket.destinationLocation

        case .concert(let t):
            eventForm.artist = t.artist
            eventForm.tourName = t.tourName
            eventForm.venue = t.venue
            eventForm.date = Self.longDateFormatter.date(from: t.date) ?? Date()
            eventForm.doorsTime = Self.timeFormatter.date(from: t.doorsTime) ?? Date()
            eventForm.showTime = Self.timeFormatter.date(from: t.showTime) ?? Date()
            eventForm.ticketNumber = t.ticketNumber
            eventForm.venueLocation = ticket.originLocation

        case .eurovision(let t):
            eurovisionForm.country = EurovisionCountry.fromIsoCode(t.countryCode)
            eurovisionForm.attendance = t.attendanceMode
            eurovisionForm.section = t.section
            eurovisionForm.row = t.row
            eurovisionForm.seat = t.seat
            eurovisionForm.watchLocation = t.watchLocation
            eurovisionForm.ticketNumber = t.ticketNumber

        case .underground(let t), .sign(let t), .infoscreen(let t), .grid(let t):
            undergroundForm.originStation = ticket.originLocation
            undergroundForm.destinationStation = ticket.destinationLocation
            undergroundForm.date = Self.shortDateFormatter.date(from: t.date) ?? Date()
            undergroundForm.ticketNumber = t.ticketNumber
            undergroundForm.zones = t.zones
            undergroundForm.fare = t.fare

            // Pre-seed `selectedCity` from the station's city so the
            // city dropdown renders populated on edit. `replan()` will
            // refine `catalogCity` from the loaded catalog and we
            // mirror that back below.
            if undergroundForm.selectedCity == nil,
               let hint = ticket.originLocation?.city
                ?? ticket.destinationLocation?.city {
                undergroundForm.selectedCity =
                    TransitCatalogLoader.City.allCases.first {
                        TransitCatalogLoader.catalog(for: $0)?
                            .city.caseInsensitiveCompare(hint) == .orderedSame
                    }
            }

            // Re-plan on prefill so the form shows the line chosen by
            // the original ticket even if the catalog has moved on.
            undergroundForm.replan()

            // Mirror the resolved catalog city back so the dropdown
            // reflects what the router actually used.
            if undergroundForm.selectedCity == nil,
               let resolved = undergroundForm.catalogCity {
                undergroundForm.selectedCity = resolved
            }

            // `replan()` only auto-picks when exactly one route exists.
            // On edit, fall back to the route whose first leg uses the
            // saved line short-name; default to index 0 otherwise so
            // the dropdown isn't left empty.
            if undergroundForm.selectedRouteIndex == nil,
               !undergroundForm.plannedRoutes.isEmpty {
                let savedLine = t.lineShortName
                let match = undergroundForm.plannedRoutes.firstIndex { route in
                    route.contains { $0.line.shortName == savedLine }
                }
                undergroundForm.selectedRouteIndex = match ?? 0
            }
        }

        step = .form
    }

    /// Splits "ABC 1234 · A321" back into `flightNumber` + `aircraft`.
    /// Mirrors `buildPayload`'s composition for the plane templates that
    /// concatenate the two with " · ".
    private static func unpackTicketNumber(
        _ raw: String,
        into form: inout FlightFormInput
    ) {
        let parts = raw.components(separatedBy: " · ")
        form.flightNumber = parts.first ?? raw
        if parts.count > 1 {
            form.aircraft = parts[1]
        }
    }

    // MARK: - Date / time formatting

    private static let longDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()


    static func longDate(_ date: Date)  -> String { longDateFormatter.string(from: date) }
    static func shortDate(_ date: Date) -> String { shortDateFormatter.string(from: date) }
    static func time(_ date: Date)      -> String { timeFormatter.string(from: date) }

    /// Train ticket date format — `dd.MM.yyyy` per the Shinkansen design.
    private static let trainDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    static func trainDate(_ date: Date) -> String { trainDateFormatter.string(from: date) }

    /// Post / Glow date format — `d MMM. yyyy` ("15 Jul. 2026").
    fileprivate static let postDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM. yyyy"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    static func postDate(_ date: Date) -> String { postDateFormatter.string(from: date) }

    // MARK: - Preview payloads

    /// Stock preview payload for a given template, used in the template /
    /// orientation tiles before the user fills out real data.
    static func previewPayload(for template: TicketTemplateKind) -> TicketPayload {
        switch template {
        case .afterglow:
            return .afterglow(AfterglowTicket(
                airline: "Airline", flightNumber: "AG 421",
                origin: "CDG", originCity: "Paris Charles de Gaulle",
                destination: "LAX", destinationCity: "Los Angeles",
                date: "3 May 2026", gate: "F32", seat: "1A",
                boardingTime: "09:40"
            ))
        case .studio:
            return .studio(StudioTicket(
                airline: "Airline", flightNumber: "FlightNumber",
                cabinClass: "Class",
                origin: "NRT", originName: "Narita International", originLocation: "Tokyo, Japan",
                destination: "JFK", destinationName: "John F. Kennedy", destinationLocation: "New York, United States",
                date: "8 Jun 2026", gate: "74", seat: "1K", departureTime: "11:05"
            ))
        case .heritage:
            return .heritage(HeritageTicket(
                airline: "Airline", ticketNumber: "Ticket number · Aircraft",
                cabinClass: "Class", cabinDetail: "Business · The Pier",
                origin: "HKG", originName: "Hong Kong International", originLocation: "Hong Kong",
                destination: "LHR", destinationName: "London Heathrow", destinationLocation: "London, United Kingdom",
                flightDuration: "9h 40m · Non-stop",
                gate: "42", seat: "11A", boardingTime: "22:10", departureTime: "22:55",
                date: "4 Sep", fullDate: "4 Sep 2026"
            ))
        case .terminal:
            return .terminal(TerminalTicket(
                airline: "Airline", ticketNumber: "Ticket number",
                cabinClass: "Business",
                origin: "CDG", originName: "Charles De Gaulle", originLocation: "Paris, France",
                destination: "VIE", destinationName: "Vienna International", destinationLocation: "Vienna, Austria",
                gate: "42", seat: "11A", boardingTime: "22:10", departureTime: "22:55",
                date: "4 Sep", fullDate: "4 Sep 2026"
            ))
        case .prism:
            return .prism(PrismTicket(
                airline: "Airline", ticketNumber: "Ticket number",
                date: "16 Aug 2026",
                origin: "SIN", originName: "Singapore Changi",
                destination: "HND", destinationName: "Tokyo Haneda",
                gate: "C34", seat: "11A", boardingTime: "08:40", departureTime: "09:10",
                terminal: "T3"
            ))
        case .express:
            return .express(ExpressTicket(
                trainType: "Shinkansen", trainNumber: "Hikari 503",
                cabinClass: "Class",
                originCity: "Tokyo", originCityKanji: "東京",
                destinationCity: "Osaka", destinationCityKanji: "大阪",
                date: "14.03.2026",
                departureTime: "06:33", arrivalTime: "09:10",
                car: "7", seat: "14A", ticketNumber: "0000000000"
            ))
        case .orient:
            return .orient(OrientTicket(
                company: "Venice Simplon Orient Express",
                cabinClass: "Class",
                originCity: "Venice",  originStation: "Santa Lucia",
                destinationCity: "Paris", destinationStation: "Gare de Lyon",
                passenger: "Passenger name",
                ticketNumber: "Ticket number",
                date: "4 May 2026",
                departureTime: "19:10",
                carriage: "7", seat: "A"
            ))
        case .night:
            return .night(NightTicket(
                company: "Company",
                trainType: "Train type",
                trainCode: "Train Code",
                originCity: "Vienna", originStation: "Wien Hauptbahnhof",
                destinationCity: "Paris", destinationStation: "Gare de l'Est",
                passenger: "Jane Doe",
                car: "37", berth: "Lower",
                date: "14 Mar 2026 · 22:04",
                ticketNumber: "000000000000"
            ))
        case .post:
            return .post(PostTicket(
                trainNumber: "Train 12345",
                trainType: "TGV Inoui",
                originCity: "Paris", originStation: "Gare du Nord",
                destinationCity: "Lyon", destinationStation: "Part-Dieu",
                date: "15 Jul. 2026",
                departureTime: "07:30",
                car: "12", seat: "E7"
            ))
        case .glow:
            return .glow(GlowTicket(
                trainNumber: "Train 12345",
                trainType: "TGV Inoui",
                originCity: "Paris", originStation: "Gare du Nord",
                destinationCity: "Lyon", destinationStation: "Part-Dieu",
                date: "15 Jul. 2026",
                departureTime: "07:30",
                car: "12", seat: "E7"
            ))
        case .concert:
            return .concert(ConcertTicket(
                artist: "Madison Beer",
                tourName: "The Locket Tour",
                venue: "O2 Arena",
                date: "21 Jun 2026",
                doorsTime: "19:00",
                showTime: "20:30",
                ticketNumber: "CON-2026-000142"
            ))
        case .eurovision:
            return .eurovision(EurovisionTicket(
                countryCode: EurovisionCountry.france.isoCode,
                countryName: EurovisionCountry.france.displayName,
                date: "16 May. 2026",
                venue: EurovisionFixtures.venue,
                attendance: EurovisionAttendance.inPerson.rawValue,
                section: "Floor",
                row: "GA",
                seat: "OPEN",
                watchLocation: "",
                ticketNumber: "ESC-2026-000142"
            ))
        case .underground, .sign, .infoscreen, .grid:
            // Each public-transit template gets its own city so the
            // selection grid showcases the breadth of supported
            // networks rather than four near-identical Vienna cards.
            switch template {
            case .sign:
                return .sign(UndergroundTicket(
                    lineShortName: "1",
                    lineName: "Château de Vincennes – La Défense",
                    companyName: "RATP",
                    lineColor: "#FFCD00",
                    originStation: "Bastille",
                    destinationStation: "Concorde",
                    stopsCount: 4,
                    date: "15 Jul 2026",
                    ticketNumber: "K7Q3X8M2WL",
                    zones: "All zones",
                    fare: "2.10 €"
                ))
            case .infoscreen:
                return .infoscreen(UndergroundTicket(
                    lineShortName: "Central",
                    lineName: "Central line",
                    companyName: "Transport for London",
                    lineColor: "#DC241F",
                    originStation: "Oxford Circus",
                    destinationStation: "Bank",
                    stopsCount: 3,
                    date: "15 Jul 2026",
                    ticketNumber: "K7Q3X8M2WL",
                    zones: "1",
                    fare: "£2.80"
                ))
            case .grid:
                return .grid(UndergroundTicket(
                    lineShortName: "G",
                    lineName: "Ginza Line",
                    companyName: "Tokyo Metro",
                    lineColor: "#FF9500",
                    originStation: "Shibuya",
                    destinationStation: "Asakusa",
                    stopsCount: 18,
                    date: "15 Jul 2026",
                    ticketNumber: "K7Q3X8M2WL",
                    zones: "All zones",
                    fare: "¥210"
                ))
            default:
                return .underground(UndergroundTicket(
                    lineShortName: "1",
                    lineName: "Broadway – 7 Av Local",
                    companyName: "MTA New York City Transit",
                    lineColor: "#EE352E",
                    originStation: "Times Sq – 42 St",
                    destinationStation: "South Ferry",
                    stopsCount: 17,
                    date: "15 Jul 2026",
                    ticketNumber: "K7Q3X8M2WL",
                    zones: "All zones",
                    fare: "$2.90"
                ))
            }
        }
    }
}
