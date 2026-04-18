//
//  NightTicket.swift
//  Lumoria App
//
//  Payload for the "Night" train ticket — a split-card sleeper /
//  overnight ticket (Nightjet, Caledonian Sleeper, etc.) with starfield
//  backdrop, moon glyph, and a right-hand summary stub.
//

import Foundation

struct NightTicket: Codable, Hashable {
    var company: String            // e.g. "OBB Nightjet" — shown top-left
    var trainType: String          // small subtitle under company
    var trainCode: String          // blue pill top-right, e.g. "NJ 295"
    var originCity: String         // hero left, e.g. "Vienna"
    var originStation: String      // station subtitle, e.g. "Wien Hauptbahnhof"
    var destinationCity: String    // hero right, e.g. "Paris"
    var destinationStation: String // station subtitle, e.g. "Gare de l'Est"
    var passenger: String          // first rounded card — "Jane Doe"
    var car: String                // second row, left — "37"
    var berth: String              // second row, right — "Lower"
    var date: String               // third row, left — "14 Mar 2026 · 22:04"
    var ticketNumber: String       // third row, right
}
