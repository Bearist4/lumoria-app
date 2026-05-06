//
//  LumiereTicket.swift
//  Lumoria App
//
//  Payload for the "Lumiere" movie-category ticket — a black cinema
//  stub with the film's poster filling the right half (horizontal) or
//  upper portion (vertical). Movie title drives an OMDb lookup at save
//  time so `posterUrl` and `director` get auto-filled from the public
//  movie database; both fields are still freely editable by the user.
//
//  Design: figma.com/design/1vAhPHcA6A3SRsQJkkylIU/Tickets?node-id=374-397
//

import Foundation

struct LumiereTicket: Codable, Hashable {
    var movieTitle: String
    /// Director name. Auto-filled from OMDb when the title resolves;
    /// user-editable. Empty string renders an empty subtitle slot
    /// (rather than a literal "Director" placeholder) so an unknown
    /// title doesn't print stale copy on the ticket.
    var director: String
    var cinemaLocation: String   // "Pathé Beaugrenelle"
    var date: String             // "21 Jun 2026"
    var time: String             // "20:30"
    var roomNumber: String       // "12" / "Salle 4"
    var row: String              // "K"
    var seat: String             // "14"
    /// Absolute URL to the OMDb poster image (`https://m.media-amazon.com/...`).
    /// Empty string = no poster found / not yet resolved; the renderer
    /// falls back to a black placeholder so the layout never collapses.
    /// Named with lowercase `url` so Swift's `convertToSnakeCase` /
    /// `convertFromSnakeCase` round-trip cleanly through `poster_url` —
    /// `posterURL` would encode as `poster_url` but decode back to
    /// `posterUrl`, breaking the codec.
    var posterUrl: String
}
