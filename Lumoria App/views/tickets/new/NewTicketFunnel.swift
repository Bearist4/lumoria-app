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
        case .train:         return "Train ticket"
        case .plane:         return "Plane ticket"
        case .parksGardens:  return "Park & Gardens"
        case .publicTransit: return "Public Transit"
        case .concert:       return "Concert"
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

    var isAvailable: Bool { self == .plane }

    /// Templates offered inside this category.
    var templates: [TicketTemplateKind] {
        switch self {
        case .plane: return [.afterglow, .studio, .terminal, .heritage, .prism]
        default:     return []
        }
    }
}

// MARK: - Step

enum NewTicketStep: Int, CaseIterable, Comparable {
    case category, template, orientation, form, style, success

    var title: String {
        switch self {
        case .category:    return "Select a category"
        case .template:    return "Pick a template"
        case .orientation: return "Choose an orientation"
        case .form:        return "Fill your ticket’s information"
        case .style:       return "Choose the style of your ticket"
        case .success:     return ""
        }
    }

    var subtitle: String? {
        self == .category
            ? "Choose the type of ticket you want to create."
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
    var arrivalDate: Date = Date()
    var arrivalTime: Date = Date()

    var flightDuration: String = ""
    var gate: String = ""
    var seat: String = ""
    var terminal: String = ""

    /// Minimum fields required across all templates before Next is enabled.
    var isMinimallyValid: Bool {
        !airline.trimmingCharacters(in: .whitespaces).isEmpty
        && !originCode.trimmingCharacters(in: .whitespaces).isEmpty
        && !destinationCode.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

// MARK: - Funnel

@MainActor
final class NewTicketFunnel: ObservableObject {

    // MARK: Navigation

    @Published var step: NewTicketStep = .category

    // MARK: Selections

    @Published var category: TicketCategory? = nil
    @Published var template: TicketTemplateKind? = nil
    @Published var orientation: TicketOrientation = .horizontal
    @Published var form: FlightFormInput = FlightFormInput()
    @Published var styleIndex: Int = 0

    // MARK: Persistence

    @Published var isSaving: Bool = false
    @Published var createdTicket: Ticket? = nil
    @Published var errorMessage: String? = nil

    // MARK: - Availability

    var availableStyles: [StyleSwatchPalette] {
        guard let template else { return [] }
        return Self.styles(for: template)
    }

    var hasStylesStep: Bool { !availableStyles.isEmpty }

    // MARK: - Next / Back logic

    /// Whether the current step's Next button should be enabled.
    var canAdvance: Bool {
        switch step {
        case .category:    return category?.isAvailable == true
        case .template:    return template != nil
        case .orientation: return true
        case .form:        return form.isMinimallyValid
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
        let arrTime   = Self.time(f.arrivalTime)
        let ticketNumber = f.aircraft.isEmpty
            ? f.flightNumber
            : "\(f.flightNumber) · \(f.aircraft)"

        switch template {
        case .afterglow:
            return .afterglow(AfterglowTicket(
                airline: f.airline,
                flightNumber: f.flightNumber,
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
                flightNumber: f.flightNumber,
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
                departureTime: arrTime,
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
                departureTime: arrTime,
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
                departureTime: arrTime,
                terminal: f.terminal
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

        let ticket = await store.create(
            payload: payload,
            orientation: orientation
        )
        if let ticket {
            createdTicket = ticket
            errorMessage = nil
        } else {
            errorMessage = store.errorMessage ?? "Couldn’t save ticket."
        }
    }

    // MARK: - Static catalog: styles per template

    static func styles(for template: TicketTemplateKind) -> [StyleSwatchPalette] {
        switch template {
        case .heritage, .terminal:
            // Templates with a visible accent color get a couple of colorways.
            return [.family("Blue"), .family("Red")]
        case .studio:
            return [.family("Red"), .family("Blue")]
        case .afterglow, .prism:
            // These ship with baked-in gradients; no style variants yet.
            return []
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
        }
    }
}
