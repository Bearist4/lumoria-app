//
//  PostTicket.swift
//  Lumoria App
//
//  Payload for the "Post" train ticket template — a cream, serif, old-
//  fashioned ticket-stub feel. Two big city columns, hairline inner
//  border, Date / Depart / Car / Seat row across the bottom.
//

import Foundation

struct PostTicket: Codable, Hashable {
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
