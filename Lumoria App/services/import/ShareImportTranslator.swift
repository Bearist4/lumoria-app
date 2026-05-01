//
//  ShareImportTranslator.swift
//  Lumoria App
//
//  Converts the share extension's primitive-typed payload into the
//  funnel's real form-input types. Lives in the main app target only;
//  the extension target never references TicketCategory or
//  FlightFormInput / EventFormInput.
//

import Foundation

enum ShareImportTranslator {

    static func category(from raw: String?) -> TicketCategory? {
        guard let raw else { return nil }
        return TicketCategory(rawValue: raw)
    }

    static func flightInput(from fields: SharePlaneFields) -> FlightFormInput {
        var input = FlightFormInput()
        input.airline = fields.airline
        input.flightNumber = fields.flightNumber
        input.originCode = fields.originCode
        input.destinationCode = fields.destinationCode
        input.gate = fields.gate
        input.seat = fields.seat
        input.terminal = fields.terminal
        if let date = fields.departureDate {
            input.departureDate = date
            input.departureTime = date
        }
        return input
    }

    static func eventInput(from fields: ShareConcertFields) -> EventFormInput {
        var input = EventFormInput()
        input.artist = fields.artist
        input.tourName = fields.tourName
        input.venue = fields.venue
        input.ticketNumber = fields.ticketNumber
        if let date = fields.date {
            input.date = date
        }
        if let doors = fields.doorsTime {
            input.doorsTime = doors
        }
        if let show = fields.showTime {
            input.showTime = show
        }
        return input
    }
}
