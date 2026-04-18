//
//  OrientTicket.swift
//  Lumoria App
//
//  Payload for the "Orient" train ticket template — a luxe vintage
//  Orient-Express-style boarding pass: navy + gold, Playfair Display
//  serif, decorative diamond rule between cities, station subnames.
//

import Foundation

struct OrientTicket: Codable, Hashable {
    /// Carrier wordmark shown top-left in italic Playfair Display gold
    /// (e.g. "Venice Simplon Orient Express").
    var company: String
    var cabinClass: String          // shown in the gold-bordered chip top-right
    var originCity: String          // hero, e.g. "Venice"
    var originStation: String       // small italic subname, e.g. "Santa Lucia"
    var destinationCity: String     // hero, e.g. "Paris"
    var destinationStation: String  // small italic subname, e.g. "Gare de Lyon"
    var passenger: String           // mid-card italic name
    var ticketNumber: String        // small mid-card right-aligned
    var date: String                // bottom strip, "4 May 2026"
    var departureTime: String       // bottom strip, "19:10"
    var carriage: String            // bottom strip, "7"
    var seat: String                // bottom strip, "A"
}
