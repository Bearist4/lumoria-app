//
//  EncryptionService.swift
//  Lumoria App
//
//  Client-side AES-GCM-256 envelope for user content that must never be
//  readable server-side. Each user has a single 256-bit data key stored in
//  the device Keychain (synced across devices via iCloud Keychain). All
//  ticket payloads and collection names/locations are encrypted with this
//  key before leaving the device and decrypted only after fetch.
//

import CryptoKit
import Foundation
import Supabase

enum EncryptionServiceError: LocalizedError {
    case noActiveUser
    case emptyCiphertext
    case invalidBase64

    var errorDescription: String? {
        switch self {
        case .noActiveUser:    return "No signed-in user. Sign in to decrypt your data."
        case .emptyCiphertext: return "Encrypted value is empty."
        case .invalidBase64:   return "Encrypted value is not valid base64."
        }
    }
}

/// Loads or creates the per-user data key on demand and exposes a tiny
/// encrypt/decrypt API over `Data` and `String`.
///
/// Thread-safety: all methods are synchronous and reach into the Keychain,
/// which serializes access internally. Store reads happen on `@MainActor`
/// callers; no additional synchronization is required.
enum EncryptionService {

    /// Loads the key for the currently signed-in Supabase user, generating
    /// a fresh one if this is the user's first encrypted write on this
    /// account. Throws if no session is available.
    static func currentKey() throws -> SymmetricKey {
        guard let userId = supabase.auth.currentUser?.id else {
            throw EncryptionServiceError.noActiveUser
        }
        return try keyFor(userId: userId)
    }

    /// Loads or creates the data key for a specific user id. Exposed so
    /// that the auth layer can eagerly provision a key right after sign-in.
    @discardableResult
    static func keyFor(userId: UUID) throws -> SymmetricKey {
        let account = userId.uuidString
        if let existing = try KeychainStore.read(account: account) {
            return SymmetricKey(data: existing)
        }
        let fresh = SymmetricKey(size: .bits256)
        let raw = fresh.withUnsafeBytes { Data($0) }
        try KeychainStore.save(raw, account: account)
        return fresh
    }

    // MARK: - Data ↔ Data

    static func encrypt(_ plaintext: Data) throws -> Data {
        let key = try currentKey()
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else {
            throw EncryptionServiceError.emptyCiphertext
        }
        return combined
    }

    static func decrypt(_ ciphertext: Data) throws -> Data {
        let key = try currentKey()
        let box = try AES.GCM.SealedBox(combined: ciphertext)
        return try AES.GCM.open(box, using: key)
    }

    // MARK: - String (base64) helpers

    /// Encrypts the UTF-8 bytes of `plaintext` and returns base64 ciphertext
    /// safe to send through PostgREST text/JSONB columns.
    static func encryptString(_ plaintext: String) throws -> String {
        let cipher = try encrypt(Data(plaintext.utf8))
        return cipher.base64EncodedString()
    }

    /// Reverses `encryptString`.
    static func decryptString(_ base64Ciphertext: String) throws -> String {
        guard let data = Data(base64Encoded: base64Ciphertext) else {
            throw EncryptionServiceError.invalidBase64
        }
        let plain = try decrypt(data)
        return String(decoding: plain, as: UTF8.self)
    }
}
