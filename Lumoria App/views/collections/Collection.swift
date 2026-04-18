//
//  Memory.swift
//  Lumoria App
//
//  App-layer model for a user's memory (formerly "collection") + the row
//  shapes used to talk to Supabase. The DB stores ciphertext for every
//  user-entered field; this file also owns the translation between rows
//  (ciphertext) and the plaintext `Memory` the rest of the app consumes.
//

import Foundation
import SwiftUI

// MARK: - App-layer model (plaintext, never touches Supabase directly)

struct Memory: Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    var name: String
    var colorFamily: String
    var emoji: String?
    let createdAt: Date
    let updatedAt: Date

    /// Matches a stored `color_family` to a `ColorOption` from the palette.
    var colorOption: ColorOption? {
        ColorOption.all.first { $0.family == colorFamily }
    }
}

// MARK: - Row read from Supabase (ciphertext fields)

/// Mirrors the `public.memories` table. `name` and `emojiEnc` hold base64
/// AES-GCM-256 ciphertext.
struct MemoryRow: Decodable {
    let id: UUID
    let userId: UUID
    let name: String
    let colorFamily: String
    let emojiEnc: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name
        case userId      = "user_id"
        case colorFamily = "color_family"
        case emojiEnc    = "emoji_enc"
        case createdAt   = "created_at"
        case updatedAt   = "updated_at"
    }

    func toMemory() throws -> Memory {
        let decryptedName = try EncryptionService.decryptString(name)
        let decryptedEmoji = try emojiEnc.map { try EncryptionService.decryptString($0) }

        return Memory(
            id: id,
            userId: userId,
            name: decryptedName,
            colorFamily: colorFamily,
            emoji: decryptedEmoji,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
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

    enum CodingKeys: String, CodingKey {
        case userId      = "user_id"
        case name
        case colorFamily = "color_family"
        case emojiEnc    = "emoji_enc"
    }

    static func make(
        userId: UUID,
        name: String,
        colorFamily: String,
        emoji: String?
    ) throws -> NewMemoryPayload {
        let encryptedName = try EncryptionService.encryptString(name)
        let encryptedEmoji = try emoji.map { try EncryptionService.encryptString($0) }
        return NewMemoryPayload(
            userId: userId,
            name: encryptedName,
            colorFamily: colorFamily,
            emojiEnc: encryptedEmoji
        )
    }
}

/// Shape sent when updating an existing row. `emojiEnc` is always emitted
/// (as `null` when clearing) so PostgREST overwrites any stale ciphertext.
struct UpdateMemoryPayload: Encodable {
    let name: String              // ciphertext (b64)
    let colorFamily: String
    let emojiEnc: String?

    enum CodingKeys: String, CodingKey {
        case name
        case colorFamily = "color_family"
        case emojiEnc    = "emoji_enc"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(colorFamily, forKey: .colorFamily)
        try c.encode(emojiEnc, forKey: .emojiEnc)
    }

    static func make(
        name: String,
        colorFamily: String,
        emoji: String?
    ) throws -> UpdateMemoryPayload {
        let encryptedName = try EncryptionService.encryptString(name)
        let encryptedEmoji = try emoji.map { try EncryptionService.encryptString($0) }
        return UpdateMemoryPayload(
            name: encryptedName,
            colorFamily: colorFamily,
            emojiEnc: encryptedEmoji
        )
    }
}
