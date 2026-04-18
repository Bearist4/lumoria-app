//
//  TicketCategoryStyle.swift
//  Lumoria App
//
//  Shared visual catalog for ticket categories — color family, SF Symbol
//  name, and display label per category. Used by the ticket-details
//  category tile, the memory-map pin, and any future surface that needs
//  to visually tag a ticket by kind.
//
//  Colors resolve to `Colors/<family>/300` asset tokens — the soft, warm
//  300-weight used for background chips and pins.
//

import SwiftUI

enum TicketCategoryStyle: String, CaseIterable, Identifiable {
    case plane, train, event, food

    var id: String { rawValue }

    /// Palette family (e.g. "Blue"). The 300-weight is the background,
    /// the on-color is derived via `onColor`.
    var colorFamily: String {
        switch self {
        case .plane: return "Blue"
        case .train: return "Yellow"
        case .event: return "Orange"
        case .food:  return "Pink"
        }
    }

    /// Background color of the pill / pin — palette 300 weight.
    var backgroundColor: Color { Color("Colors/\(colorFamily)/300") }

    /// Text/icon color on top of `backgroundColor`. Yellow is bright enough
    /// to need black; the others take white.
    var onColor: Color { self == .train ? .black : .white }

    /// SF Symbol name for the category glyph.
    var systemImage: String {
        switch self {
        case .plane: return "airplane"
        case .train: return "train.side.front.car"
        case .event: return "theatermasks.fill"
        case .food:  return "fork.knife"
        }
    }

    /// User-facing category name.
    var displayName: String {
        switch self {
        case .plane: return String(localized: "Plane")
        case .train: return String(localized: "Train")
        case .event: return String(localized: "Event")
        case .food:  return String(localized: "Food & Drinks")
        }
    }
}

// MARK: - Template → category

extension TicketTemplateKind {
    /// Visual category each ticket template belongs to.
    var categoryStyle: TicketCategoryStyle {
        switch self {
        case .afterglow, .studio, .heritage, .terminal, .prism:
            return .plane
        case .express, .orient, .night:
            return .train
        }
    }
}
