//
//  AnalyticsIdentity.swift
//  Lumoria App
//
//  Deterministic hash + email-domain helpers. Everything here must be
//  side-effect-free and trivially testable — we use these to strip PII
//  from UUIDs and emails before they reach Amplitude.
//

import CryptoKit
import Foundation

enum AnalyticsIdentity {

    /// SHA-256(UUID) truncated to 16 hex chars. Preserves joinability of
    /// related events (e.g. Invite Shared ↔ Invite Claimed) without
    /// leaking the original primary key.
    static func hashUUID(_ uuid: UUID) -> String {
        hashString(uuid.uuidString)
    }

    /// SHA-256 of the UTF-8 encoding of `input`, returned as the first 16
    /// lowercase hex characters (64-bit prefix). Input is hashed verbatim —
    /// no normalization is applied. Callers hashing UUIDs should use
    /// `hashUUID(_:)` to guarantee the canonical representation.
    static func hashString(_ input: String) -> String {
        let data = Data(input.utf8)
        let digest = SHA256.hash(data: data)
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return String(hex.prefix(16))
    }

    /// Extracts the domain portion of an email address, lowercased.
    /// Returns nil when the input has no `@` or no domain part.
    static func emailDomain(_ email: String) -> String? {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let atIndex = trimmed.firstIndex(of: "@") else { return nil }
        let domain = trimmed[trimmed.index(after: atIndex)...]
        guard !domain.isEmpty else { return nil }
        return domain.lowercased()
    }
}
