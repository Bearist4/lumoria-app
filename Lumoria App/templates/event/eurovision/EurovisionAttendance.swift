//
//  EurovisionAttendance.swift
//  Lumoria App
//
//  How the user is experiencing Eurovision 2026 — in the arena, or
//  watching from somewhere else. The form switches its seat-detail
//  fields based on this pick, and the rendered ticket swaps its
//  detail cells (section/row/seat ↔ a single "watching from" cell)
//  so the stub reflects the chosen mode.
//

import Foundation

enum EurovisionAttendance: String, CaseIterable, Codable, Hashable, Identifiable {
    case inPerson = "in_person"
    case atHome   = "at_home"

    var id: String { rawValue }

    /// Title shown on the segmented control.
    var displayName: String {
        switch self {
        case .inPerson: return String(localized: "In person")
        case .atHome:   return String(localized: "At home")
        }
    }
}
