//
//  NewTicketFunnel.swift
//  Lumoria App
//
//  State model for the multi-step "new ticket" funnel.
//

import Combine
import Foundation
import SwiftUI

// MARK: - Category

enum TicketCategory: String, CaseIterable, Identifiable {
    case train, plane, parksGardens, publicTransit, concert

    var id: String { rawValue }

    var title: String {
        switch self {
        case .train:         return String(localized: "Train ticket")
        case .plane:         return String(localized: "Plane ticket")
        case .parksGardens:  return String(localized: "Park & Gardens")
        case .publicTransit: return String(localized: "Public Transit")
        case .concert:       return String(localized: "Concert")
        }
    }

    /// Named asset under `Assets.xcassets/misc`.
    var imageName: String {
        switch self {
        case .train:         return "train"
        case .plane:         return "plane"
        case .parksGardens:  return "garden"
        case .publicTransit: return "tram_stop"
        case .concert:       return "concert_stage"
        }
    }

    var isAvailable: Bool {
        switch self {
        case .plane, .train: return true
        default:             return false
        }
    }

    /// Templates offered inside this category.
    var templates: [TicketTemplateKind] {
        switch self {
        case .plane: return [.afterglow, .studio, .terminal, .heritage, .prism]
        case .train: return [.express, .orient, .night]
        default:     return []
        }
    }
}

// MARK: - Step

enum NewTicketStep: Int, CaseIterable, Comparable {
    case category, template, orientation, form, style, success

    var title: String {
        switch self {
        case .category:    return String(localized: "Select a category")
        case .template:    return String(localized: "Pick a template")
        case .orientation: return String(localized: "Choose an orientation")
        case .form:        return String(localized: "Fill your ticket’s information")
        case .style:       return String(localized: "Choose the style of your ticket")
        case .success:     return ""
        }
    }

    var subtitle: String? {
        self == .category
            ? String(localized: "Choose the type of ticket you want to create.")
            : nil
    }

    /// Whether the step's body should fill the available height instead of
    /// being wrapped in a ScrollView. Used by orientation where both tiles
    /// need to share remaining space.
    var prefersFullHeight: Bool {
        self == .orientation
    }

    static func < (a: NewTicketStep, b: NewTicketStep) -> Bool {
        a.rawValue < b.rawValue
    }
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

    /// Compatibility shim — older callers still ask for a generic
    /// `isMinimallyValid`. Defaults to the Express rules.
    var isMinimallyValid: Bool { isExpressValid }
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
    /// Identifier of the selected style variant for the chosen template.
    /// Resolved against `template.styles`; nil before a template is picked.
    @Published var selectedStyleId: String? = nil

    // MARK: Persistence

    @Published var isSaving: Bool = false
    @Published var createdTicket: Ticket? = nil
    @Published var errorMessage: String? = nil

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
        case .form:
            switch template {
            case .express: return trainForm.isExpressValid
            case .orient:  return trainForm.isOrientValid
            case .night:   return trainForm.isNightValid
            default:       return form.isMinimallyValid
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
        case .orientation: step = .form
        case .form:        step = hasStylesStep ? .style : .success
        case .style:       step = .success
        case .success:     return
        }
    }

    func goBack() {
        switch step {
        case .category:    return
        case .template:    step = .category
        case .orientation: step = .template
        case .form:        step = .orientation
        case .style:       step = .form
        case .success:     step = hasStylesStep ? .style : .form
        }
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
                boardingTime: depTime
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
                boardingTime: depTime,
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
                boardingTime: depTime,
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
                boardingTime: depTime,
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
        }
    }

    // MARK: - Persistence

    /// Persists the current selections as a ticket in the store. Sets
    /// `createdTicket` on success; `errorMessage` on failure.
    func persist(using store: TicketsStore) async {
        guard createdTicket == nil else { return }
        guard let payload = buildPayload() else {
            errorMessage = "Missing ticket data."
            return
        }
        isSaving = true
        defer { isSaving = false }

        let isTrainTemplate = template == .express || template == .orient
        let ticket = await store.create(
            payload: payload,
            orientation: orientation,
            originLocation: isTrainTemplate
                ? trainForm.originStationLocation
                : form.originAirport,
            destinationLocation: isTrainTemplate
                ? trainForm.destinationStationLocation
                : form.destinationAirport,
            styleId: selectedStyleId ?? template?.defaultStyle.id
        )
        if let ticket {
            createdTicket = ticket
            errorMessage = nil
        } else {
            errorMessage = store.errorMessage ?? "Couldn’t save ticket."
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
        }
    }
}
