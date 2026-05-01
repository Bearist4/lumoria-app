//
//  EurovisionTicket.swift
//  Lumoria App
//
//  Payload for the "Eurovision" event-category ticket — a Vienna 2026
//  grand-finale stub. Date and venue are pinned to the real-world event
//  (16 May 2026, Wiener Stadthalle Halle D) so the form only collects
//  the country the user is supporting plus their seat / row / section.
//

import Foundation

struct EurovisionTicket: Codable, Hashable {

    /// ISO 3166-1 alpha-2 (lowercased). Drives `eurovision-bg-<code>`
    /// + `eurovision-logo-<code>` lookups at render time.
    var countryCode: String

    /// English country name. Cached on the payload so the renderer can
    /// fall back to a text label if the country's logo asset is missing.
    var countryName: String

    /// "16 May. 2026" — already formatted by `NewTicketFunnel.eurovisionDate`.
    var date: String

    /// Always "Stadthalle Halle D".
    var venue: String

    /// In-arena vs. watching from elsewhere. Drives which detail cells
    /// the renderer paints — section/row/seat for in-person, a single
    /// `watchLocation` cell for at-home.
    /// Stored as the enum's raw value so the column survives schema
    /// changes and stays human-readable in DB dumps.
    var attendance: String

    /// "Floor", "A", "Lower Tier", … — used only when `attendance == .inPerson`.
    var section: String

    /// "GA", "12", "27", … — in-person only.
    var row: String

    /// "OPEN", "1A", "27", … — in-person only.
    var seat: String

    /// Where the user is watching from when `attendance == .atHome`
    /// (e.g. "At home", "Friend's place", "Bar in Vienna"). Ignored
    /// for in-person tickets.
    var watchLocation: String

    /// "ESC-2026-000142" or operator-issued reference.
    var ticketNumber: String

    /// Decoded attendance — falls back to `.inPerson` when the stored
    /// string is unrecognised, so old tickets created before this
    /// field existed render the way they were originally designed.
    var attendanceMode: EurovisionAttendance {
        EurovisionAttendance(rawValue: attendance) ?? .inPerson
    }
}
