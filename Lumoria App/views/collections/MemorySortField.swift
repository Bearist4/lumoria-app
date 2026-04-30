//
//  MemorySortField.swift
//  Lumoria App
//
//  Per-memory sort preference. Raw values match the
//  `memories.sort_field` column constraint.
//

import Foundation

enum MemorySortField: String, CaseIterable, Identifiable, Codable {
    case dateAdded   = "date_added"
    case eventDate   = "event_date"
    case dateCreated = "date_created"

    var id: String { rawValue }

    /// Title shown in the sort sheet's radio list.
    var title: String {
        switch self {
        case .dateAdded:   return String(localized: "Date added to memory")
        case .eventDate:   return String(localized: "Date of the event")
        case .dateCreated: return String(localized: "Date the ticket was created")
        }
    }
}
