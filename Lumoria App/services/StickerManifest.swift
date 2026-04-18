//
//  StickerManifest.swift
//  Lumoria App / LumoriaStickers
//
//  On-disk index of the rendered sticker PNGs sitting in the App Group
//  container. Written by the main app's `StickerRenderService`, read
//  by the iMessage extension's `MessagesViewController`.
//
//  Both targets include this file. Keep it dependency-free (Foundation
//  only) so the extension doesn't drag in SwiftUI / Supabase / CryptoKit.
//

import Foundation

// MARK: - App Group

enum StickerAppGroup {
    static let identifier = "group.bearista.Lumoria-App"

    /// Override for tests to redirect reads/writes to a throwaway directory.
    /// When set, `stickersDirectory` returns this URL and skips the App
    /// Group container lookup entirely. Production leaves this nil.
    static var directoryOverride: URL?

    /// `<appGroup>/stickers/` — holds PNGs and `manifest.json`.
    static var stickersDirectory: URL? {
        if let override = directoryOverride {
            try? FileManager.default.createDirectory(
                at: override,
                withIntermediateDirectories: true
            )
            return override
        }
        guard let base = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: identifier
        ) else {
            return nil
        }
        let dir = base.appendingPathComponent("stickers", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        return dir
    }

    static var manifestURL: URL? {
        stickersDirectory?.appendingPathComponent("manifest.json")
    }

    static func pngURL(for filename: String) -> URL? {
        stickersDirectory?.appendingPathComponent(filename)
    }
}

// MARK: - Manifest

struct StickerManifest: Codable, Equatable {

    var version: Int
    var entries: [Entry]

    struct Entry: Codable, Equatable, Identifiable {
        /// Ticket UUID as string (avoids pulling in Foundation.UUID Codable
        /// subtleties across target boundaries).
        let ticketId: String
        /// File name inside the stickers directory — `<ticketId>.png`.
        let filename: String
        /// ISO 8601 timestamp. Used for sort order (newest first).
        let createdAt: String
        /// Accessibility label surfaced in the sticker browser cell.
        let label: String

        var id: String { ticketId }
    }

    static let empty = StickerManifest(version: 1, entries: [])

    /// Atomic load. Returns `.empty` if the file is missing or unreadable —
    /// the extension and the render service both treat "no manifest" as
    /// "no stickers", not as an error.
    static func load() -> StickerManifest {
        guard let url = StickerAppGroup.manifestURL,
              let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(StickerManifest.self, from: data)
        else {
            return .empty
        }
        return manifest
    }

    /// Atomic save: write to `<manifest>.tmp`, then rename. Prevents a
    /// half-written manifest from being read by the extension mid-update.
    func save() throws {
        guard let url = StickerAppGroup.manifestURL else {
            throw StickerManifestError.appGroupUnavailable
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)

        let tmp = url.appendingPathExtension("tmp")
        try data.write(to: tmp, options: .atomic)
        _ = try FileManager.default.replaceItemAt(url, withItemAt: tmp)
    }
}

enum StickerManifestError: Error {
    case appGroupUnavailable
}
