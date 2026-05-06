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
    case plane, train, event, food, concert, movie, museum, sport, garden, publicTransit

    var id: String { rawValue }

    /// Palette family (e.g. "Blue"). The 300-weight is the background,
    /// the on-color is derived via `onColor`. Values map 1:1 to the
    /// Figma `_TicketDetails Category` catalogue (node 1652:57952).
    var colorFamily: String {
        switch self {
        case .plane:         return "Blue"
        case .train:         return "Yellow"
        case .event:         return "Orange"
        case .food:          return "Pink"
        case .concert:       return "Purple"
        case .movie:         return "Indigo"
        case .museum:        return "Red"
        case .sport:         return "Green"
        case .garden:        return "Lime"
        case .publicTransit: return "Cyan"
        }
    }

    /// Asset slug for the Figma `Category/*/<slug>` aliases. The Figma
    /// catalogue uses `public-transport` and `park`; the Swift enum
    /// keeps the older `publicTransit`/`garden` cases for stability.
    var assetSlug: String {
        switch self {
        case .publicTransit: return "public-transport"
        case .garden:        return "park"
        default:             return rawValue
        }
    }

    /// Background color of the pill / pin — resolves the Figma
    /// `Category/background/<slug>` alias (family/300 light, /400 dark,
    /// /400 HC light, /500 HC dark). All 4 appearance modes are baked in.
    var backgroundColor: Color { Color("Colors/category/background/\(assetSlug)") }

    /// Text/icon color on top of `backgroundColor` — resolves the Figma
    /// `Category/content/<slug>` alias (family/800 light, Gray/White
    /// dark, Gray/Black HC light, Gray/Black HC dark; concert is white in
    /// HC light because purple/800 is dark enough already).
    var onColor: Color { Color("Colors/category/content/\(assetSlug)") }

    /// SF Symbol name for the category glyph.
    var systemImage: String {
        switch self {
        case .plane:         return "airplane"
        case .train:         return "train.side.front.car"
        case .event:         return "theatermasks.fill"
        case .food:          return "fork.knife"
        case .concert:       return "music.note"
        case .movie:         return "popcorn.fill"
        case .museum:        return "building.columns.fill"
        case .sport:         return "figure.run"
        case .garden:        return "tree.fill"
        case .publicTransit: return "bus.fill"
        }
    }

    /// User-facing category name. Matches the Figma labels exactly so
    /// pill copy is consistent across surfaces.
    var displayName: String {
        switch self {
        case .plane:         return String(localized: "Plane")
        case .train:         return String(localized: "Train")
        case .event:         return String(localized: "Event")
        case .food:          return String(localized: "Food & Drinks")
        case .concert:       return String(localized: "Concert")
        case .movie:         return String(localized: "Movies")
        case .museum:        return String(localized: "Museum")
        case .sport:         return String(localized: "Sport")
        case .garden:        return String(localized: "Parks & Gardens")
        case .publicTransit: return String(localized: "Subway")
        }
    }

    /// Short, single-word label used in tight surfaces like the
    /// `TicketEntryRow` pill. For categories without a shorter form it
    /// falls back to `displayName`.
    var pillLabel: String {
        switch self {
        case .publicTransit: return String(localized: "Subway")
        case .food:          return String(localized: "Food")
        case .movie:         return String(localized: "Movie")
        case .garden:        return String(localized: "Park")
        default:             return displayName
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
        case .express, .orient, .night, .post, .glow:
            return .train
        case .concert:
            return .concert
        case .eurovision:
            return .event
        case .underground, .sign, .infoscreen, .grid:
            return .publicTransit
        case .lumiere:
            return .movie
        }
    }
}
