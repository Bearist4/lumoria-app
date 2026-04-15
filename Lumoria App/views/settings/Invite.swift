//
//  Invite.swift
//  Lumoria App
//
//  Models for the single-use invite a user can share with one friend.
//

import Foundation

// MARK: - App-layer model

struct Invite: Identifiable, Equatable {
    let id: UUID
    let inviterId: UUID
    let token: String
    let createdAt: Date
    let revokedAt: Date?
    let claimedBy: UUID?
    let claimedAt: Date?
    let redeemedAt: Date?

    var isRedeemed: Bool { redeemedAt != nil }
    var isRevoked: Bool  { revokedAt != nil }

    /// Public sharable link. The app resolves both https and the custom
    /// `lumoria://` scheme — see `InviteLink`.
    var shareURL: URL { InviteLink.url(for: token) }
}

// MARK: - Row types

struct InviteRow: Decodable {
    let id: UUID
    let inviterId: UUID
    let token: String
    let createdAt: Date
    let revokedAt: Date?
    let claimedBy: UUID?
    let claimedAt: Date?
    let redeemedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, token
        case inviterId  = "inviter_id"
        case createdAt  = "created_at"
        case revokedAt  = "revoked_at"
        case claimedBy  = "claimed_by"
        case claimedAt  = "claimed_at"
        case redeemedAt = "redeemed_at"
    }

    func toInvite() -> Invite {
        Invite(
            id: id,
            inviterId: inviterId,
            token: token,
            createdAt: createdAt,
            revokedAt: revokedAt,
            claimedBy: claimedBy,
            claimedAt: claimedAt,
            redeemedAt: redeemedAt
        )
    }
}

struct NewInviteRow: Encodable {
    let inviterId: UUID
    let token: String

    enum CodingKeys: String, CodingKey {
        case inviterId = "inviter_id"
        case token
    }
}

struct RevokeInvitePatch: Encodable {
    let revokedAt: Date

    enum CodingKeys: String, CodingKey {
        case revokedAt = "revoked_at"
    }
}

// MARK: - Token generation

enum InviteToken {
    /// Crockford-style base32 (no 0/1/I/L/O/U) keeps tokens unambiguous
    /// when typed or spoken aloud. 10 chars ≈ 49 bits of entropy.
    private static let alphabet = Array("23456789ABCDEFGHJKMNPQRSTVWXYZ")

    static func make(length: Int = 10) -> String {
        var out = ""
        out.reserveCapacity(length)
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<length {
            out.append(alphabet.randomElement(using: &rng)!)
        }
        return out
    }
}

// MARK: - Link scheme

enum InviteLink {
    /// Human-sharable URL. Deep-link path for both https and the fallback
    /// custom scheme is `/invite/{token}`.
    static let host = "getlumoria.app"
    static let customScheme = "lumoria"
    static let pathPrefix = "/invite/"

    static func url(for token: String) -> URL {
        URL(string: "https://\(host)\(pathPrefix)\(token)")!
    }

    /// Returns the token if `url` matches either the https://lumoria.app
    /// universal link or the lumoria:// custom scheme for an invite.
    static func token(from url: URL) -> String? {
        let path: String
        if let scheme = url.scheme?.lowercased(), scheme == customScheme {
            // lumoria://invite/XYZ — host is "invite", path is "/XYZ"
            if url.host?.lowercased() == "invite" {
                path = url.path
            } else {
                // Allow lumoria:///invite/XYZ as well.
                path = url.path
            }
        } else if url.scheme?.lowercased().hasPrefix("http") == true,
                  url.host?.lowercased() == host {
            path = url.path
        } else {
            return nil
        }

        // Normalize: grab the last non-empty path component.
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(separator: "/")
        if let first = parts.first, first.lowercased() == "invite", parts.count >= 2 {
            return String(parts[1])
        }
        // For lumoria://invite/XYZ the "invite" is the host, so the path is
        // just "/XYZ" and parts = ["XYZ"].
        if url.scheme?.lowercased() == customScheme, url.host?.lowercased() == "invite" {
            return String(parts[0])
        }
        return nil
    }
}

// MARK: - Pending token storage

/// Persists an invite token received via deep-link so we can claim it after
/// the invitee signs up.
enum PendingInviteTokenStore {
    private static let key = "pending_invite_token"

    static func save(_ token: String) {
        UserDefaults.standard.set(token, forKey: key)
    }

    static func take() -> String? {
        let value = UserDefaults.standard.string(forKey: key)
        UserDefaults.standard.removeObject(forKey: key)
        return value
    }

    static var current: String? {
        UserDefaults.standard.string(forKey: key)
    }
}
