//
//  Collection.swift
//  Lumoria App
//
//  App-layer model for a user's collection + the row shapes used to talk to
//  Supabase. The DB stores ciphertext for every user-entered field; this
//  file also owns the translation between rows (ciphertext) and the
//  plaintext `Collection` the rest of the app consumes.
//

import CoreLocation
import Foundation
import SwiftUI

// MARK: - App-layer model (plaintext, never touches Supabase directly)

struct Collection: Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    var name: String
    var colorFamily: String
    var locationName: String?
    var locationLat: Double?
    var locationLng: Double?
    let createdAt: Date
    let updatedAt: Date

    /// Matches a stored `color_family` to a `ColorOption` from the palette.
    var colorOption: ColorOption? {
        ColorOption.all.first { $0.family == colorFamily }
    }
}

// MARK: - Row read from Supabase (ciphertext fields)

/// Mirrors the `public.collections` table. `name` holds base64 AES-GCM-256
/// ciphertext; `locationEnc` holds ciphertext of a JSON-encoded
/// `EncryptedLocation`, or nil.
struct CollectionRow: Decodable {
    let id: UUID
    let userId: UUID
    let name: String
    let colorFamily: String
    let locationEnc: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name
        case userId      = "user_id"
        case colorFamily = "color_family"
        case locationEnc = "location_enc"
        case createdAt   = "created_at"
        case updatedAt   = "updated_at"
    }

    func toCollection() throws -> Collection {
        let decryptedName = try EncryptionService.decryptString(name)
        let loc = try locationEnc.flatMap { try EncryptedLocation.decrypt($0) }

        return Collection(
            id: id,
            userId: userId,
            name: decryptedName,
            colorFamily: colorFamily,
            locationName: loc?.name,
            locationLat: loc?.lat,
            locationLng: loc?.lng,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

// MARK: - Encrypted location bundle

/// The cleartext shape serialized into `location_enc`. Bundling the three
/// fields together means we ship a single ciphertext + no separate lat/lng
/// columns are readable server-side.
struct EncryptedLocation: Codable {
    let name: String
    let lat: Double
    let lng: Double

    static func encrypt(name: String, lat: Double, lng: Double) throws -> String {
        let data = try JSONEncoder().encode(Self(name: name, lat: lat, lng: lng))
        let cipher = try EncryptionService.encrypt(data)
        return cipher.base64EncodedString()
    }

    static func decrypt(_ base64: String) throws -> Self {
        guard let cipher = Data(base64Encoded: base64) else {
            throw EncryptionServiceError.invalidBase64
        }
        let plain = try EncryptionService.decrypt(cipher)
        return try JSONDecoder().decode(Self.self, from: plain)
    }
}

// MARK: - Insert / update payloads

/// Shape sent when inserting a new row. All user-entered fields are
/// encrypted before hitting this struct.
struct NewCollectionPayload: Encodable {
    let userId: UUID
    let name: String              // ciphertext (b64)
    let colorFamily: String
    let locationEnc: String?

    enum CodingKeys: String, CodingKey {
        case userId      = "user_id"
        case name
        case colorFamily = "color_family"
        case locationEnc = "location_enc"
    }

    static func make(
        userId: UUID,
        name: String,
        colorFamily: String,
        location: SelectedLocation?
    ) throws -> NewCollectionPayload {
        let encryptedName = try EncryptionService.encryptString(name)
        let encryptedLocation = try location.map { loc in
            try EncryptedLocation.encrypt(
                name: loc.title,
                lat: loc.coordinate.latitude,
                lng: loc.coordinate.longitude
            )
        }
        return NewCollectionPayload(
            userId: userId,
            name: encryptedName,
            colorFamily: colorFamily,
            locationEnc: encryptedLocation
        )
    }
}

/// Shape sent when updating an existing row. `locationEnc` is always emitted
/// (as `null` when clearing) so PostgREST overwrites any stale ciphertext.
struct UpdateCollectionPayload: Encodable {
    let name: String              // ciphertext (b64)
    let colorFamily: String
    let locationEnc: String?

    enum CodingKeys: String, CodingKey {
        case name
        case colorFamily = "color_family"
        case locationEnc = "location_enc"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(colorFamily, forKey: .colorFamily)
        try c.encode(locationEnc, forKey: .locationEnc)
    }

    static func make(
        name: String,
        colorFamily: String,
        location: SelectedLocation?
    ) throws -> UpdateCollectionPayload {
        let encryptedName = try EncryptionService.encryptString(name)
        let encryptedLocation = try location.map { loc in
            try EncryptedLocation.encrypt(
                name: loc.title,
                lat: loc.coordinate.latitude,
                lng: loc.coordinate.longitude
            )
        }
        return UpdateCollectionPayload(
            name: encryptedName,
            colorFamily: colorFamily,
            locationEnc: encryptedLocation
        )
    }
}
