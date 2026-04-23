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

enum TicketCategory: String, CaseIterable, Identifiable {
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

    var isAvailable: Bool {
        switch self {
        case .plane, .train, .concert, .publicTransit: return true
        default:                                        return false
        }
    }

    /// Templates offered inside this category.
    var templates: [TicketTemplateKind] {
        switch self {
        case .plane:         return [.afterglow, .studio, .terminal, .heritage, .prism]
        case .train:         return [.express, .orient, .night, .post, .glow]
        case .concert:       return [.concert]
        case .publicTransit: return [.underground]
        default:             return []
        }
    }
}

// MARK: - Step

enum NewTicketStep: Int, CaseIterable, Comparable {
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
}

// MARK: - Form input

/// Unified flight-form input. Holds every field any of the 5 plane templates
/// might need; each template-specific builder reads the subset it cares about.
struct FlightFormInput {
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
struct TrainFormInput {
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
struct EventFormInput {
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
struct UndergroundFormInput {
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
    var plannedRoutes: [[TransitLeg]] = []

    /// Which of `plannedRoutes` the user picked. `replan()` always
    /// resets this to 0. Stays clamped into the range on re-plan.
    var selectedRouteIndex: Int = 0

    /// Convenience — the legs of the currently-selected route.
    var plannedLegs: [TransitLeg] {
        guard plannedRoutes.indices.contains(selectedRouteIndex) else { return [] }
        return plannedRoutes[selectedRouteIndex]
    }

    /// True when at least one route is planned — the router only
    /// returns `[]` for same-station pairs, and `nil` when stations
    /// can't be resolved to catalog entries.
    var isValid: Bool { !plannedRoutes.isEmpty }

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
        selectedRouteIndex = 0
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
    }

    /// One `UndergroundTicket` payload per planned leg. The funnel
    /// creates ticket #1 through the standard persist path; anything
    /// beyond the first is handed to the presenter, which persists
    /// the rest after the first succeeds.
    var legPayloads: [UndergroundTicket] {
        let dateString = Self.dateFormatter.string(from: date)
        return plannedLegs.enumerated().map { idx, leg in
            // Ticket numbers are auto-suffixed per leg so the user
            // can see them as "TRA-…-1", "-2"… without retyping.
            let baseTicket = ticketNumber
                .trimmingCharacters(in: .whitespaces)
            let ticketNum = plannedLegs.count > 1 && !baseTicket.isEmpty
                ? "\(baseTicket)-\(idx + 1)"
                : baseTicket
            return UndergroundTicket(
                lineShortName: leg.line.shortName,
                lineName: leg.line.longName,
                companyName: operatorName,
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
            case .underground:  return undergroundForm.isValid
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
    /// fields are never touched (they're gated by `canAdvance`). Skipped
    /// during edit so a user clearing a field by intent isn't silently
    /// overwritten.
    private func applyAestheticDefaults() {
        autoFilledFields = []
        guard !isEditing, let template else { return }
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

        case .afterglow, .studio, .heritage, .terminal, .prism,
             .express, .orient, .night, .post, .glow:
            // Plane / train templates already fall through to "Class",
            // "Business" etc. defaults inside `buildPayload`. Extend
            // here when a template gains new aesthetic placeholders.
            break

        case .underground:
            if trim(undergroundForm.ticketNumber).isEmpty {
                undergroundForm.ticketNumber = Self.randomRef(prefix: "TRA")
                autoFilledFields.append(String(localized: "Ticket number"))
            }
            if trim(undergroundForm.zones).isEmpty {
                undergroundForm.zones = String(localized: "All zones")
                autoFilledFields.append(String(localized: "Zones"))
            }
            if trim(undergroundForm.fare).isEmpty {
                undergroundForm.fare = "—"
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
        case .underground:
            // The funnel emits one `UndergroundTicket` per planned leg
            // (see `undergroundForm.legPayloads`). `buildPayload` only
            // returns the first so the shared create/update path can
            // round-trip through the existing single-ticket machinery;
            // the presenter persists any additional legs separately.
            return undergroundForm.legPayloads.first.map(TicketPayload.underground)
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

        // Underground journeys can span multiple legs (A→B on U1,
        // B→C on U3…). Each leg becomes its own persisted ticket so
        // the rider keeps every line / colour / stop count on the
        // memory map.
        if template == .underground {
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
            styleId: selectedStyleId ?? template?.defaultStyle.id
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

        let styleId = selectedStyleId ?? TicketTemplateKind.underground.defaultStyle.id

        for (idx, payload) in payloads.enumerated() {
            let pair = idx < locations.count ? locations[idx] : nil
            let ticket = await store.create(
                payload: .underground(payload),
                orientation: .horizontal,
                originLocation: pair?.origin,
                destinationLocation: pair?.destination,
                styleId: styleId
            )
            guard let ticket else {
                errorMessage = store.errorMessage
                    ?? String(localized: "Couldn’t save ticket \(idx + 1) of \(payloads.count).")
                return
            }
            createdTickets.append(ticket)
            if createdTicket == nil {
                createdTicket = ticket
            }
        }
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
            styleId: selectedStyleId ?? template?.defaultStyle.id
        )
    }

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
        case .underground:
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

        case .underground(let t):
            undergroundForm.originStation = ticket.originLocation
            undergroundForm.destinationStation = ticket.destinationLocation
            undergroundForm.date = Self.shortDateFormatter.date(from: t.date) ?? Date()
            undergroundForm.ticketNumber = t.ticketNumber
            undergroundForm.zones = t.zones
            undergroundForm.fare = t.fare
            // Re-plan on prefill so the form shows the line chosen by
            // the original ticket even if the catalog has moved on.
            undergroundForm.replan()
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
        case .underground:
            return .underground(UndergroundTicket(
                lineShortName: "U1",
                lineName: "U1 Leopoldau – Reumannplatz",
                companyName: "Wiener Linien",
                lineColor: "#E3000F",
                originStation: "Stephansplatz",
                destinationStation: "Karlsplatz",
                stopsCount: 1,
                date: "15 Jul 2026",
                ticketNumber: "TRA-2026-000142",
                zones: "All zones",
                fare: "2.50 €"
            ))
        }
    }
}
