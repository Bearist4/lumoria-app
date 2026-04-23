//
//  GlowTicket.swift
//  Lumoria App
//
//  Payload for the "Glow" train ticket template — pitch-black card with
//  a bloom of warm orange / magenta / pink radiating from the bottom
//  edge, a dashed perforation + punch disc between main and stub.
//

import Foundation

struct GlowTicket: Codable, Hashable {
    var trainNumber: String        // small label top-left, e.g. "TRAIN 12345"
    var trainType: String          // bold line below, e.g. "TGV Inoui"
    var originCity: String         // hero, e.g. "Paris"
    var originStation: String      // tiny subname, e.g. "Gare du Nord"
    var destinationCity: String    // hero, e.g. "Lyon"
    var destinationStation: String // tiny subname, e.g. "Part-Dieu"
    var date: String               // "15 Jul. 2026"
    var departureTime: String      // "07:30"
    var car: String                // "12"
    var seat: String               // "E7"
}
