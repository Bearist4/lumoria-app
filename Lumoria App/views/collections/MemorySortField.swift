//
//  MemorySortField.swift
//  Lumoria App
//
//  Per-memory sort preference. Raw values match the
//  `memories.sort_field` column constraint. `allCases` order is the
//  display order in `MemorySortSheet`.
//

import Foundation

enum MemorySortField: String, CaseIterable, Identifiable, Codable {
    case dateCreated = "date_created"
    case dateAdded   = "date_added"
    case eventDate   = "event_date"

    var id: String { rawValue }

    /// Title shown in the sort sheet's row.
    var title: String {
        switch self {
        case .dateCreated: return String(localized: "Ticket creation")
        case .dateAdded:   return String(localized: "Added to this memory")
        case .eventDate:   return String(localized: "Event")
        }
    }

    /// Optional second line under the row title. Used for the Event row
    /// to disambiguate it from "ticket creation" — the date the user
    /// sees on the ticket itself.
    var subtitle: String? {
        switch self {
        case .eventDate: return String(localized: "The date displayed on the ticket")
        default:         return nil
        }
    }
}
