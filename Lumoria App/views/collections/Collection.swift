//
//  Memory.swift
//  Lumoria App
//
//  App-layer model for a user's memory (formerly "collection") + the row
//  shapes used to talk to Supabase. The DB stores ciphertext for every
//  user-entered field; this file also owns the translation between rows
//  (ciphertext) and the plaintext `Memory` the rest of the app consumes.
//

import CoreLocation
import Foundation
import SwiftUI

// MARK: - App-layer model (plaintext, never touches Supabase directly)

struct Memory: Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    var name: String
    var colorFamily: String
    var emoji: String?
    /// Optional span of the memory. Used for the Journey Wrap stats and the
    /// Map timeline's date rail. Falls back to the earliest / latest ticket
    /// date when nil.
    var startDate: Date?
    var endDate: Date?
    /// Per-memory sort preference for `MemoryDetailView`. Defaults to
    /// `.dateAdded` ascending (oldest added first) so the user's first-
    /// added tickets sit at the top.
    var sortField: MemorySortField = .dateAdded
    var sortAscending: Bool = true
    let createdAt: Date
    let updatedAt: Date

    /// Matches a stored `color_family` to a `ColorOption` from the palette.
    var colorOption: ColorOption? {
        ColorOption.all.first { $0.family == colorFamily }
    }
}

// MARK: - Row read from Supabase (ciphertext fields)

/// Mirrors the `public.memories` table. `name`, `emojiEnc`, and the two
/// date fields hold base64 AES-GCM-256 ciphertext.
struct MemoryRow: Decodable {
    let id: UUID
    let userId: UUID
    let name: String
    let colorFamily: String
    let emojiEnc: String?
    let startDateEnc: String?
    let endDateEnc: String?
    let sortField: String?
    let sortAscending: Bool?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name
        case userId        = "user_id"
        case colorFamily   = "color_family"
        case emojiEnc      = "emoji_enc"
        case startDateEnc  = "start_date_enc"
        case endDateEnc    = "end_date_enc"
        case sortField     = "sort_field"
        case sortAscending = "sort_ascending"
        case createdAt     = "created_at"
        case updatedAt     = "updated_at"
    }

    func toMemory() throws -> Memory {
        let decryptedName  = try EncryptionService.decryptString(name)
        let decryptedEmoji = try emojiEnc.map { try EncryptionService.decryptString($0) }
        let decryptedStart = try startDateEnc.map { try MemoryDateCodec.decrypt($0) }
        let decryptedEnd   = try endDateEnc.map   { try MemoryDateCodec.decrypt($0) }

        // Treat unknown sort_field strings as the default. Optional from
        // the row so older rows that predate the column still decode.
        let resolvedField = sortField
            .flatMap(MemorySortField.init(rawValue:))
            ?? .dateAdded

        return Memory(
            id: id,
            userId: userId,
            name: decryptedName,
            colorFamily: colorFamily,
            emoji: decryptedEmoji,
            startDate: decryptedStart,
            endDate: decryptedEnd,
            sortField: resolvedField,
            sortAscending: sortAscending ?? true,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

// MARK: - Date codec

/// Encrypts/decrypts a `Date` as an ISO-8601 string inside the same
/// AES-GCM-256 envelope used for `name` / `emoji_enc`.
enum MemoryDateCodec {
    private static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func encrypt(_ date: Date) throws -> String {
        try EncryptionService.encryptString(formatter.string(from: date))
    }

    static func decrypt(_ base64: String) throws -> Date {
        let raw = try EncryptionService.decryptString(base64)
        guard let date = formatter.date(from: raw) else {
            throw EncryptionServiceError.invalidBase64
        }
        return date
    }
}

// MARK: - Insert / update payloads

/// Shape sent when inserting a new row. All user-entered fields are
/// encrypted before hitting this struct.
struct NewMemoryPayload: Encodable {
    let userId: UUID
    let name: String              // ciphertext (b64)
    let colorFamily: String
    let emojiEnc: String?         // ciphertext (b64), nullable
    let startDateEnc: String?     // ciphertext (b64), nullable
    let endDateEnc: String?       // ciphertext (b64), nullable

    enum CodingKeys: String, CodingKey {
        case userId       = "user_id"
        case name
        case colorFamily  = "color_family"
        case emojiEnc     = "emoji_enc"
        case startDateEnc = "start_date_enc"
        case endDateEnc   = "end_date_enc"
    }

    static func make(
        userId: UUID,
        name: String,
        colorFamily: String,
        emoji: String?,
        startDate: Date?,
        endDate: Date?
    ) throws -> NewMemoryPayload {
        let encryptedName  = try EncryptionService.encryptString(name)
        let encryptedEmoji = try emoji.map { try EncryptionService.encryptString($0) }
        let encryptedStart = try startDate.map { try MemoryDateCodec.encrypt($0) }
        let encryptedEnd   = try endDate.map   { try MemoryDateCodec.encrypt($0) }
        return NewMemoryPayload(
            userId: userId,
            name: encryptedName,
            colorFamily: colorFamily,
            emojiEnc: encryptedEmoji,
            startDateEnc: encryptedStart,
            endDateEnc: encryptedEnd
        )
    }
}

/// Shape sent when updating an existing row. All optional fields are
/// always emitted (as `null` when clearing) so PostgREST overwrites any
/// stale ciphertext.
struct UpdateMemoryPayload: Encodable {
    let name: String              // ciphertext (b64)
    let colorFamily: String
    let emojiEnc: String?
    let startDateEnc: String?
    let endDateEnc: String?

    enum CodingKeys: String, CodingKey {
        case name
        case colorFamily  = "color_family"
        case emojiEnc     = "emoji_enc"
        case startDateEnc = "start_date_enc"
        case endDateEnc   = "end_date_enc"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name,          forKey: .name)
        try c.encode(colorFamily,   forKey: .colorFamily)
        try c.encode(emojiEnc,      forKey: .emojiEnc)
        try c.encode(startDateEnc,  forKey: .startDateEnc)
        try c.encode(endDateEnc,    forKey: .endDateEnc)
    }

    static func make(
        name: String,
        colorFamily: String,
        emoji: String?,
        startDate: Date?,
        endDate: Date?
    ) throws -> UpdateMemoryPayload {
        let encryptedName  = try EncryptionService.encryptString(name)
        let encryptedEmoji = try emoji.map { try EncryptionService.encryptString($0) }
        let encryptedStart = try startDate.map { try MemoryDateCodec.encrypt($0) }
        let encryptedEnd   = try endDate.map   { try MemoryDateCodec.encrypt($0) }
        return UpdateMemoryPayload(
            name: encryptedName,
            colorFamily: colorFamily,
            emojiEnc: encryptedEmoji,
            startDateEnc: encryptedStart,
            endDateEnc: encryptedEnd
        )
    }
}

// MARK: - Sort prefs payload

/// Payload for the dedicated sort-pref update path. Kept separate from
/// `UpdateMemoryPayload` so the sort sheet doesn't need to round-trip the
/// encrypted name / emoji / dates just to flip a flag.
struct UpdateMemorySortPayload: Encodable {
    let sortField: String
    let sortAscending: Bool

    enum CodingKeys: String, CodingKey {
        case sortField     = "sort_field"
        case sortAscending = "sort_ascending"
    }
}

// MARK: - Journey anchor

/// A user-defined stop attached to a memory without a backing ticket
/// (e.g. "Home — Paris", a hotel, a connecting city). Anchors merge with
/// ticket-derived stops when building the Story Mode sequence.
enum JourneyAnchorKind: String, Codable, Hashable {
    case start
    case end
    case waypoint
}

struct JourneyAnchor: Identifiable, Hashable {
    let id: UUID
    let memoryId: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var date: Date
    var kind: JourneyAnchorKind

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// Encrypted JSON payload shape stored in `journey_anchors.payload_enc`.
struct JourneyAnchorPayload: Codable {
    var name: String
    var lat: Double
    var lng: Double
}

/// Row shape read from `public.journey_anchors`.
struct JourneyAnchorRow: Decodable {
    let id: UUID
    let userId: UUID
    let memoryId: UUID
    let payloadEnc: String
    let dateEnc: String
    let kind: String
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId     = "user_id"
        case memoryId   = "memory_id"
        case payloadEnc = "payload_enc"
        case dateEnc    = "date_enc"
        case kind
        case createdAt  = "created_at"
        case updatedAt  = "updated_at"
    }

    func toAnchor() throws -> JourneyAnchor {
        guard let base64Data = Data(base64Encoded: payloadEnc) else {
            throw EncryptionServiceError.invalidBase64
        }
        let plain = try EncryptionService.decrypt(base64Data)
        let payload = try JSONDecoder().decode(JourneyAnchorPayload.self, from: plain)
        let date = try MemoryDateCodec.decrypt(dateEnc)
        let anchorKind = JourneyAnchorKind(rawValue: kind) ?? .waypoint
        return JourneyAnchor(
            id: id,
            memoryId: memoryId,
            name: payload.name,
            latitude: payload.lat,
            longitude: payload.lng,
            date: date,
            kind: anchorKind
        )
    }
}

/// Insert payload for a new anchor.
struct NewJourneyAnchorPayload: Encodable {
    let userId: UUID
    let memoryId: UUID
    let payloadEnc: String
    let dateEnc: String
    let kind: String

    enum CodingKeys: String, CodingKey {
        case userId     = "user_id"
        case memoryId   = "memory_id"
        case payloadEnc = "payload_enc"
        case dateEnc    = "date_enc"
        case kind
    }

    static func make(
        userId: UUID,
        memoryId: UUID,
        name: String,
        coordinate: CLLocationCoordinate2D,
        date: Date,
        kind: JourneyAnchorKind
    ) throws -> NewJourneyAnchorPayload {
        let body = JourneyAnchorPayload(
            name: name,
            lat: coordinate.latitude,
            lng: coordinate.longitude
        )
        let encoded = try JSONEncoder().encode(body)
        let payloadCipher = try EncryptionService.encrypt(encoded).base64EncodedString()
        let dateCipher = try MemoryDateCodec.encrypt(date)
        return NewJourneyAnchorPayload(
            userId: userId,
            memoryId: memoryId,
            payloadEnc: payloadCipher,
            dateEnc: dateCipher,
            kind: kind.rawValue
        )
    }
}
