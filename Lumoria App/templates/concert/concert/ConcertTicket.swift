//
//  ConcertTicket.swift
//  Lumoria App
//
//  Payload for the "Concert" event-category ticket template — a dreamy
//  pop-concert stub with a curved artist name arcing across the top,
//  a heart motif behind the scenes, and a Date / Doors / Show / Venue
//  row at the bottom.
//

import Foundation

struct ConcertTicket: Codable, Hashable {
    var artist: String          // arcs across the top, e.g. "Madison Beer"
    var tourName: String        // subtitle, e.g. "The Locket Tour"
    var venue: String           // bottom-right value, e.g. "O2 Arena"
    var date: String            // "21 Jun 2026"
    var doorsTime: String       // "19:00"
    var showTime: String        // "20:30"
    var ticketNumber: String    // "CON-2026-000142"
}
