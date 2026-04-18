//
//  StickerRenderService.swift
//  Lumoria App
//
//  Renders tickets to transparent PNGs inside the App Group container
//  and keeps `manifest.json` in sync. The iMessage sticker extension
//  reads that cache — there is no live data path from the extension
//  to Supabase, so this service is the only writer.
//
//  Called from `TicketsStore` on create / update / delete / load.
//  Failures never propagate — sticker rendering is best-effort.
//

import Foundation
import SwiftUI
import UIKit

@MainActor
final class StickerRenderService {

    static let shared = StickerRenderService()

    private init() {}

    // MARK: - Tunables

    /// Apple's hard ceiling is 500 KB per sticker. Aim below it so we
    /// don't ship files that load slowly in Messages.
    private let targetMaxBytes = 400_000

    /// Long-edge ladder for the size-cap retry. If 1200 px overshoots
    /// the target byte size, fall back to 900, then 700.
    private let longEdgeLadder: [CGFloat] = [1200, 900, 700]

    /// Serialises writes — protects manifest reads/writes and keeps the
    /// reconcile pass from racing per-ticket mutations.
    private var pending: Task<Void, Never> = Task { }

    // MARK: - Public API

    /// Renders (or re-renders) the given ticket and updates the manifest.
    func render(_ ticket: Ticket) {
        enqueue { [weak self] in
            guard let self else { return }
            do { try await self.renderNow(ticket) }
            catch { print("[StickerRenderService] render failed for \(ticket.id):", error) }
        }
    }

    /// Removes the ticket's PNG and manifest entry, if present.
    func delete(ticketId: UUID) {
        enqueue { [weak self] in
            guard let self else { return }
            do { try await self.deleteNow(ticketId: ticketId) }
            catch { print("[StickerRenderService] delete failed for \(ticketId):", error) }
        }
    }

    /// Diffs the manifest against the current ticket set: renders any
    /// ticket without a PNG / manifest entry, prunes entries whose
    /// ticket no longer exists. Called after `TicketsStore.load()`.
    func reconcile(with tickets: [Ticket]) {
        enqueue { [weak self] in
            guard let self else { return }
            do { try await self.reconcileNow(with: tickets) }
            catch { print("[StickerRenderService] reconcile failed:", error) }
        }
    }

    // MARK: - Queue

    private func enqueue(_ op: @escaping @Sendable () async -> Void) {
        let previous = pending
        pending = Task {
            await previous.value
            await op()
        }
    }

    // MARK: - Core ops

    private func renderNow(_ ticket: Ticket) async throws {
        guard let dir = StickerAppGroup.stickersDirectory else {
            throw StickerManifestError.appGroupUnavailable
        }
        let filename = "\(ticket.id.uuidString).png"
        let url = dir.appendingPathComponent(filename)

        let data = try pngData(for: ticket)
        try data.write(to: url, options: .atomic)

        var manifest = StickerManifest.load()
        manifest.entries.removeAll { $0.ticketId == ticket.id.uuidString }
        manifest.entries.append(
            StickerManifest.Entry(
                ticketId: ticket.id.uuidString,
                filename: filename,
                createdAt: Self.iso.string(from: ticket.createdAt),
                label: Self.accessibilityLabel(for: ticket)
            )
        )
        manifest.entries.sort { $0.createdAt > $1.createdAt }
        try manifest.save()
    }

    private func deleteNow(ticketId: UUID) async throws {
        let filename = "\(ticketId.uuidString).png"
        if let url = StickerAppGroup.pngURL(for: filename),
           FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        var manifest = StickerManifest.load()
        manifest.entries.removeAll { $0.ticketId == ticketId.uuidString }
        try manifest.save()
    }

    private func reconcileNow(with tickets: [Ticket]) async throws {
        guard let dir = StickerAppGroup.stickersDirectory else {
            throw StickerManifestError.appGroupUnavailable
        }

        let currentIds = Set(tickets.map(\.id.uuidString))
        var manifest = StickerManifest.load()

        // Prune orphans (entries whose ticket no longer exists).
        let orphans = manifest.entries.filter { !currentIds.contains($0.ticketId) }
        for orphan in orphans {
            let url = dir.appendingPathComponent(orphan.filename)
            try? FileManager.default.removeItem(at: url)
        }
        manifest.entries.removeAll { !currentIds.contains($0.ticketId) }
        try manifest.save()

        // Render missing — also re-render if the PNG file has been deleted
        // from disk while the manifest entry survived.
        let indexed = Dictionary(uniqueKeysWithValues: manifest.entries.map { ($0.ticketId, $0) })
        for ticket in tickets {
            let key = ticket.id.uuidString
            let fileExists: Bool = {
                guard let entry = indexed[key] else { return false }
                let url = dir.appendingPathComponent(entry.filename)
                return FileManager.default.fileExists(atPath: url.path)
            }()
            if indexed[key] == nil || !fileExists {
                do { try await renderNow(ticket) }
                catch { print("[StickerRenderService] backfill render failed for \(ticket.id):", error) }
            }
        }
    }

    // MARK: - Rendering

    private func pngData(for ticket: Ticket) throws -> Data {
        for longEdge in longEdgeLadder {
            let data = try renderPNG(ticket: ticket, longEdge: longEdge)
            if data.count <= targetMaxBytes { return data }
        }
        // Ladder exhausted — ship the smallest we produced so we don't
        // fail the whole write.
        return try renderPNG(ticket: ticket, longEdge: longEdgeLadder.last ?? 700)
    }

    private func renderPNG(ticket: Ticket, longEdge: CGFloat) throws -> Data {
        let size = StickerRenderView.renderSize(for: ticket.orientation, longEdge: longEdge)
        let view = StickerRenderView(ticket: ticket)
            .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1   // points == pixels; size already in px
        renderer.isOpaque = false

        guard let image = renderer.uiImage, let data = image.pngData() else {
            throw StickerRenderError.rasterizationFailed
        }
        return data
    }

    // MARK: - Helpers

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// `"Plane ticket · HKG to LHR"` for trips,
    /// `"Plane ticket · HKG"` when there's an origin but no destination,
    /// `"Plane ticket"` when there's no location data.
    static func accessibilityLabel(for ticket: Ticket) -> String {
        let category = ticket.kind.categoryLabel
        let origin = ticket.originLocation.flatMap { locationCode($0) }
        let destination = ticket.destinationLocation.flatMap { locationCode($0) }

        switch (origin, destination) {
        case let (origin?, destination?):
            return "\(category) · \(origin) to \(destination)"
        case let (origin?, nil):
            return "\(category) · \(origin)"
        default:
            return category
        }
    }

    /// Prefers the short subtitle (IATA code, station code) and falls
    /// back to the display name if none was captured.
    private static func locationCode(_ location: TicketLocation) -> String? {
        if let subtitle = location.subtitle, !subtitle.isEmpty { return subtitle }
        if !location.name.isEmpty { return location.name }
        return nil
    }
}

// MARK: - Errors

enum StickerRenderError: Error {
    case rasterizationFailed
}
