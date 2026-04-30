//
//  MemorySortField.swift
//  Lumoria App
//
//  Per-memory sort preference. Raw values match the
//  `memories.sort_field` column constraint. `pickerOptions` is the
//  display order in `MemorySortSheet`; `.manual` is set implicitly when
//  the user reorders tickets and is hidden from the picker.
//

import Foundation

enum MemorySortField: String, CaseIterable, Identifiable, Codable {
    case dateCreated = "date_created"
    case dateAdded   = "date_added"
    case eventDate   = "event_date"
    case manual      = "manual"

    var id: String { rawValue }

    /// Cases that surface in the sort sheet. `.manual` is set
    /// implicitly when the user reorders tickets, so we hide it from
    /// the picker — the sheet keeps offering only date-based sorts.
    static var pickerOptions: [MemorySortField] {
        [.dateCreated, .dateAdded, .eventDate]
    }

    /// Title shown in the sort sheet's row.
    var title: String {
        switch self {
        case .dateCreated: return String(localized: "Ticket creation")
        case .dateAdded:   return String(localized: "Added to this memory")
        case .eventDate:   return String(localized: "Event")
        case .manual:      return String(localized: "Manual")
        }
    }

    /// Optional second line under the row title.
    var subtitle: String? {
        switch self {
        case .eventDate: return String(localized: "The date displayed on the ticket")
        default:         return nil
        }
    }
}
