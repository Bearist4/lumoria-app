//
//  AllTicketsSortField.swift
//  Lumoria App
//
//  Sort field for the global "All tickets" view. Mirrors
//  `MemorySortField` for the date-based options (so sheet UI can be
//  shared) and adds two category-alphabetical orderings.
//
//  Unlike memory sort, this is local-only state — there's no per-user
//  preference column for the all-tickets gallery.
//

import Foundation

enum AllTicketsSortField: String, CaseIterable, Identifiable, Codable {
    case dateCreated = "date_created"
    case dateAdded   = "date_added"
    case eventDate   = "event_date"
    case categoryAZ  = "category_az"
    case categoryZA  = "category_za"

    var id: String { rawValue }

    /// Date-keyed options shown under the "Date" group in the sheet.
    /// `.dateAdded` is excluded — it's a memory-scoped concept, so the
    /// global gallery only offers ticket-creation and event date.
    static var dateOptions: [AllTicketsSortField] {
        [.dateCreated, .eventDate]
    }

    /// Category-keyed options shown under "Categories".
    static var categoryOptions: [AllTicketsSortField] {
        [.categoryAZ, .categoryZA]
    }

    var title: String {
        switch self {
        case .dateCreated: return String(localized: "Ticket creation")
        case .dateAdded:   return String(localized: "Added to a memory")
        case .eventDate:   return String(localized: "Event")
        case .categoryAZ:  return String(localized: "A-Z")
        case .categoryZA:  return String(localized: "Z-A")
        }
    }

    var subtitle: String? {
        switch self {
        case .eventDate: return String(localized: "The date displayed on the ticket")
        default:         return nil
        }
    }

    /// Whether the oldest/newest direction toggle is meaningful for
    /// this field. Category fields bake the direction into the name
    /// (A-Z / Z-A), so the segmented control is hidden for them.
    var supportsDirection: Bool {
        switch self {
        case .categoryAZ, .categoryZA: return false
        default:                       return true
        }
    }
}
