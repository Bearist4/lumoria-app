//
//  UndergroundTicket.swift
//  Lumoria App
//
//  Payload for the "Underground" public-transport template — a dark
//  subway / metro / underground ticket keyed off an operator's line
//  (Vienna's U1, Tokyo's Ginza, London's Central…). The line's
//  short-code tile + line name are tinted with the operator's
//  authentic colour, which is why `lineColor` lives on the payload
//  instead of in a style variant (`TicketStyleVariant` colours are
//  shared across every ticket of the same template).
//
//  Station metadata (origin / destination) is expected to be resolved
//  via MapKit's `MKLocalSearch` POI filter + the bundled GTFS line
//  catalogs; the payload itself just carries the user-facing text.
//
//  Design: figma.com/design/1vAhPHcA6A3SRsQJkkylIU/Tickets?node-id=18-515
//

import Foundation

struct UndergroundTicket: Codable, Hashable {

    /// Short line identifier shown inside the circular badge at the
    /// top-left of the ticket. Usually 1–3 characters: "U1", "E", "5".
    var lineShortName: String

    /// Full line name printed next to the badge, in the line colour.
    /// Example: "U1 Leopoldau – Reumannplatz".
    var lineName: String

    /// Operator / agency name printed under the line name, dimmed.
    /// Example: "Wiener Linien".
    var companyName: String

    /// Hex colour (e.g. `"#E4002B"`) of the operator's line branding.
    /// Drives the badge background and the line name text colour on
    /// the rendered ticket.
    var lineColor: String

    /// Origin station printed as the FROM hero.
    var originStation: String

    /// Destination station printed as the TO hero.
    var destinationStation: String

    /// Number of station-to-station segments the rider travels —
    /// i.e. how many times the train stops from boarding through
    /// arriving at the destination. Two adjacent stations = 1
    /// (not 0); three intermediate stations plus the destination
    /// = 4. Matches rider-intuition for "how many stops until I
    /// get off".
    var stopsCount: Int

    /// Date of travel, pre-formatted for display (e.g. `"15 Jul 2026"`).
    var date: String

    /// Operator-issued ticket / reference number.
    var ticketNumber: String

    /// Fare zone label — "All zones", "Zone 1–2", etc. Operators differ;
    /// free-form string so Vienna, Tokyo, London and NYC can all use
    /// the format that reads natively for their riders.
    var zones: String

    /// Fare paid, pre-formatted (e.g. `"2.50 €"`, `"¥180"`, `"$2.90"`).
    var fare: String

    /// GTFS `route_type` int — 0 tram, 1 subway, 3 bus, 5 cable tram,
    /// etc. Drives the mode symbol rendered next to the line badge.
    /// Optional so older tickets (pre-mode-field) still decode cleanly.
    var mode: Int? = nil
}

/// Picks a single hero-station font size that both FROM and TO can
/// fit at, keyed off whichever name is longer. Without this each
/// `Text` shrinks independently via `minimumScaleFactor`, producing
/// the visible imbalance ("Zürich, Museum für Gestaltung" at 11pt
/// next to "Zürich, Kronenstrasse" at 22pt). Returns the unscaled
/// point size — callers multiply by their own `s` (width / frame)
/// scale.
func transitStationFontSize(origin: String, destination: String) -> CGFloat {
    let maxLen = max(origin.count, destination.count)
    switch maxLen {
    case 0...14:  return 22
    case 15...18: return 19
    case 19...22: return 16
    case 23...26: return 14
    default:      return 12
    }
}
