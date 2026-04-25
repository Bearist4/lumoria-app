//
//  PaywallTrigger.swift
//  Lumoria App
//
//  Identifies the entry point that opened the paywall. Maps to one of
//  the four personalised hero variants (Q5 = B grouping in the design
//  spec). Also drives the analytics `paywallViewed(source:)` property.
//

import Foundation

enum PaywallTrigger: String, Equatable, Sendable {
    // Free-tier counters.
    case memoryLimit  = "memory_limit"
    case ticketLimit  = "ticket_limit"

    // Map suite (wired in Phase 2/3).
    case timelineLocked  = "timeline_locked"
    case mapExportLocked = "map_export_locked"

    // Premium content (wired in Phase 2/3).
    case publicTransportCategory = "public_transport_category"
    case placeholderCategory     = "placeholder_category"
    case paidTemplate            = "paid_template"
    case styleCustomisation      = "style_customisation"
    case pkpassImport            = "pkpass_import"
    case stickerPack             = "sticker_pack"

    /// One of four hero variants to render.
    enum Variant: String, Equatable, Sendable {
        case memoryLimit
        case ticketLimit
        case mapSuite
        case premiumContent
    }

    var variant: Variant {
        switch self {
        case .memoryLimit:
            return .memoryLimit
        case .ticketLimit:
            return .ticketLimit
        case .timelineLocked, .mapExportLocked:
            return .mapSuite
        case .publicTransportCategory,
             .placeholderCategory,
             .paidTemplate,
             .styleCustomisation,
             .pkpassImport,
             .stickerPack:
            return .premiumContent
        }
    }
}
