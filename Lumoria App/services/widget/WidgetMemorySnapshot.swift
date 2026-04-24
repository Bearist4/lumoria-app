//
//  WidgetMemorySnapshot.swift
//  Lumoria App + Lumoria (widget)
//
//  Plain Codable shapes the widget reads. The main app writes plaintext
//  here after decrypting memories + tickets; the widget process never
//  touches Supabase or the encryption key.
//
//  File belongs to both targets' compile sources.
//

import Foundation

// MARK: - Top-level snapshot

struct WidgetSnapshot: Codable {
    /// When this snapshot was written. Purely informational; the widget
    /// uses it to decide whether to skip a rebuild when no data changed.
    let lastUpdated: Date
    /// Signed-in user's memories, most-recent first.
    let memories: [WidgetMemorySnapshot]
}

// MARK: - Per-memory payload

struct WidgetMemorySnapshot: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let emoji: String?
    /// Palette family (e.g. "Pink") — the widget resolves
    /// `Color("Colors/<family>/300")` directly from the asset catalog shared
    /// with the main app's asset bundle.
    let colorFamily: String
    let ticketCount: Int
    /// Distinct `TicketCategoryStyle.rawValue` values for tickets in this
    /// memory, in display order (most-common first, then alphabetical).
    let categoryStyleRawValues: [String]
    /// Total distance in km across all plane/train segments (rounded).
    /// Nil when the memory has no locatable trip segments.
    let kmTotal: Int?
    /// Memory duration in days: ceil(endDate - startDate). Falls back to
    /// earliest/latest ticket created_at when start/end are nil.
    let dayCount: Int?
    /// References to pre-rendered ticket mini PNGs stored in the App Group
    /// container. Up to 10 — the widget samples 3 at a time for the medium
    /// variant.
    let ticketImageRefs: [WidgetTicketImageRef]
}

// MARK: - Ticket mini reference

struct WidgetTicketImageRef: Codable, Hashable {
    let ticketId: UUID
    /// Filename relative to `WidgetSharedContainer.ticketsFolderURL`.
    let filename: String
    let orientation: Orientation

    enum Orientation: String, Codable {
        case horizontal
        case vertical
    }
}
