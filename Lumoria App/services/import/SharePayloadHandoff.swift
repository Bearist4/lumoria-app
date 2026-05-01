//
//  SharePayloadHandoff.swift
//  Lumoria App
//
//  JSON encode/decode + App Group file I/O for the share extension's
//  pending-share.json sentinel. Mirrors the App Group pattern used by
//  PKPassImporter for boarding passes.
//

import Foundation

enum SharePayloadHandoff {

    static let appGroupId = "group.bearista.Lumoria-App"
    static let pendingFilename = "pending-share.json"

    // MARK: - Encode / decode

    static func encode(_ result: ShareImportResult) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(result)
    }

    static func decode(_ data: Data) throws -> ShareImportResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ShareImportResult.self, from: data)
    }

    // MARK: - App Group I/O

    static func writePending(_ result: ShareImportResult) throws -> URL {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            throw HandoffError.appGroupUnavailable
        }
        let url = container.appendingPathComponent(pendingFilename)
        let data = try encode(result)
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Reads + deletes the pending file in one shot. Returns nil when
    /// nothing is queued.
    static func drainPending() -> ShareImportResult? {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            return nil
        }
        let url = container.appendingPathComponent(pendingFilename)
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else { return nil }
        try? FileManager.default.removeItem(at: url)
        return try? decode(data)
    }

    enum HandoffError: Error {
        case appGroupUnavailable
    }
}
