//
//  WidgetCategoryIcon.swift
//  Lumoria (widget)
//
//  Minimal mirror of the main app's `TicketCategoryStyle` mapping that
//  the small widget variant needs — SF Symbol name + palette family per
//  category raw value. Kept local to the widget target so the widget
//  doesn't have to pull in TicketTemplateKind and its dependencies.
//

import SwiftUI

enum WidgetCategoryIcon {

    /// SF Symbol name for a category raw value (`TicketCategoryStyle.rawValue`).
    /// Returns `ticket` as a fallback so an unknown / future category still
    /// renders something sensible rather than a blank pill.
    static func systemImage(for rawValue: String) -> String {
        switch rawValue {
        case "plane":         return "airplane"
        case "train":         return "train.side.front.car"
        case "event":         return "theatermasks.fill"
        case "food":          return "fork.knife"
        case "concert":       return "music.note"
        case "movie":         return "popcorn.fill"
        case "museum":        return "building.columns.fill"
        case "sport":         return "figure.run"
        case "garden":        return "tree.fill"
        case "publicTransit": return "bus.fill"
        default:              return "ticket"
        }
    }
}
