//
//  PaywallTrigger.swift
//  Lumoria App
//
//  Identifies the entry point that opened the paywall.
//
//  Per the Figma layout (969:20169 default + 969:20173/20171 limit
//  variants), the paywall has two visual modes:
//
//    - Default: title "Lumoria Premium", single "Upgrade now" CTA.
//    - Limit reached: title "Out of {memories|tickets}" with the
//      resource word coloured, two CTAs ("Upgrade now" or
//      "Try for 14 days" + "Invite a friend").
//
//  Everything else (5-bullet feature list, plan tiles, trust copy)
//  stays identical across modes.
//
//  Trigger also drives the analytics `paywallViewed(source:)` property.
//

import Foundation

enum PaywallTrigger: String, Equatable, Sendable {

    // Free-tier counters — render the limit-reached variant.
    case memoryLimit  = "memory_limit"
    case ticketLimit  = "ticket_limit"

    // Map suite (Phase 3+ — render the default variant for now).
    case timelineLocked  = "timeline_locked"
    case mapExportLocked = "map_export_locked"

    // Premium content (Phase 3+ — render the default variant).
    case publicTransportCategory = "public_transport_category"
    case placeholderCategory     = "placeholder_category"
    case paidTemplate            = "paid_template"
    case styleCustomisation      = "style_customisation"
    case pkpassImport            = "pkpass_import"
    case stickerPack             = "sticker_pack"

    // Proactive upgrade from Settings → Plan management. Renders default.
    case upgradeFromSettings     = "upgrade_from_settings"

    /// Free-tier resource the user has run out of. Drives the
    /// "Out of memories" / "Out of tickets" title swap and the
    /// "limit reached" two-CTA layout. `nil` for any non-limit
    /// trigger — those render the default "Lumoria Premium" copy.
    enum LimitedResource: String, Equatable, Sendable {
        case memories
        case tickets
    }

    var limitedResource: LimitedResource? {
        switch self {
        case .memoryLimit: return .memories
        case .ticketLimit: return .tickets
        default:           return nil
        }
    }

    /// Whether this trigger renders the limit-reached layout (title
    /// swap + two-CTA row including "Invite a friend").
    var isLimitReached: Bool {
        limitedResource != nil
    }
}
