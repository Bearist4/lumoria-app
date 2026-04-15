//
//  TicketRow.swift
//  Lumoria App
//
//  Row shapes that mirror the `public.tickets` + `public.collection_tickets`
//  Supabase tables, plus helpers to convert between those rows and the
//  app-facing `Ticket` struct.
//
//  The `payload` jsonb column holds template-specific fields (e.g. the
//  `PrismTicket` struct's values as JSON). Round-trips go through a dedicated
//  encoder/decoder that converts between `camelCase` Swift properties and
//  the `snake_case` keys stored in JSONB.
//

import Foundation
import Supabase

// MARK: - Row read from Supabase

/// A decoded row from `public.tickets`. The `collectionTickets` array is
/// populated when the query embeds the junction table with
/// `.select("*, collection_tickets(collection_id)")`.
struct TicketRow: Decodable {
    let id: UUID
    let userId: UUID
    let templateKind: String
    let orientation: String
    let payload: AnyJSON
    let createdAt: Date
    let updatedAt: Date
    let collectionTickets: [CollectionTicketLink]?

    enum CodingKeys: String, CodingKey {
        case id, payload, orientation
        case userId            = "user_id"
        case templateKind      = "template_kind"
        case createdAt         = "created_at"
        case updatedAt         = "updated_at"
        case collectionTickets = "collection_tickets"
    }
}

/// Single row of the `collection_tickets` junction, embedded when reading a
/// ticket. Only `collection_id` is kept — the rest (ticket id, added_at) is
/// redundant on the ticket side.
struct CollectionTicketLink: Decodable {
    let collectionId: UUID

    enum CodingKeys: String, CodingKey {
        case collectionId = "collection_id"
    }
}

// MARK: - Insert payload

/// Shape sent when inserting a new ticket.
struct NewTicketRow: Encodable {
    let userId: UUID
    let templateKind: String
    let orientation: String
    let payload: AnyJSON

    enum CodingKeys: String, CodingKey {
        case userId       = "user_id"
        case templateKind = "template_kind"
        case orientation, payload
    }
}

/// Shape sent when updating a ticket's payload / orientation.
struct TicketUpdateRow: Encodable {
    let templateKind: String
    let orientation: String
    let payload: AnyJSON

    enum CodingKeys: String, CodingKey {
        case templateKind = "template_kind"
        case orientation, payload
    }
}

// MARK: - Junction payload

struct CollectionTicketRow: Encodable {
    let collectionId: UUID
    let ticketId: UUID

    enum CodingKeys: String, CodingKey {
        case collectionId = "collection_id"
        case ticketId     = "ticket_id"
    }
}

// MARK: - Payload ↔ AnyJSON codec

/// The `payload` JSONB column is a wrapper around a base64 AES-GCM-256
/// ciphertext blob, of the shape `{"c": "<base64>"}`. The cleartext inside
/// is the `snake_case`-encoded template struct (PrismTicket, StudioTicket,
/// etc). Only the owning user's device can decrypt it.
enum TicketCodec {

    private static let cipherKey = "c"

    /// JSON encoder used to serialize a template struct into `snake_case` JSON
    /// before encrypting.
    private static let payloadEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    /// JSON decoder used to parse the decrypted `snake_case` JSON back into
    /// the relevant template struct.
    private static let payloadDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // MARK: - Encode

    static func encode(_ payload: TicketPayload) throws -> AnyJSON {
        let cleartext = try cleartextData(for: payload)
        let cipher = try EncryptionService.encrypt(cleartext)
        return .object([cipherKey: .string(cipher.base64EncodedString())])
    }

    private static func cleartextData(for payload: TicketPayload) throws -> Data {
        switch payload {
        case .afterglow(let t): return try payloadEncoder.encode(t)
        case .studio(let t):    return try payloadEncoder.encode(t)
        case .heritage(let t):  return try payloadEncoder.encode(t)
        case .terminal(let t):  return try payloadEncoder.encode(t)
        case .prism(let t):     return try payloadEncoder.encode(t)
        }
    }

    // MARK: - Decode

    static func decodePayload(
        kind: TicketTemplateKind,
        from json: AnyJSON
    ) throws -> TicketPayload {
        guard
            case .object(let dict) = json,
            case .string(let b64)? = dict[cipherKey],
            let cipher = Data(base64Encoded: b64)
        else {
            throw TicketRowError.malformedCiphertext
        }

        let cleartext = try EncryptionService.decrypt(cipher)
        switch kind {
        case .afterglow: return .afterglow(try payloadDecoder.decode(AfterglowTicket.self, from: cleartext))
        case .studio:    return .studio(   try payloadDecoder.decode(StudioTicket.self,    from: cleartext))
        case .heritage:  return .heritage( try payloadDecoder.decode(HeritageTicket.self,  from: cleartext))
        case .terminal:  return .terminal( try payloadDecoder.decode(TerminalTicket.self,  from: cleartext))
        case .prism:     return .prism(    try payloadDecoder.decode(PrismTicket.self,     from: cleartext))
        }
    }
}

// MARK: - Row → Ticket

extension TicketRow {

    /// Converts the raw row into a `Ticket` the app layer can consume.
    func toTicket() throws -> Ticket {
        guard let kind = TicketTemplateKind(rawValue: templateKind) else {
            throw TicketRowError.unknownTemplateKind(templateKind)
        }
        guard let orient = TicketOrientation(rawValue: orientation) else {
            throw TicketRowError.unknownOrientation(orientation)
        }
        let payload = try TicketCodec.decodePayload(kind: kind, from: payload)
        let collectionIds = (collectionTickets ?? []).map(\.collectionId)
        return Ticket(
            id: id,
            createdAt: createdAt,
            updatedAt: updatedAt,
            orientation: orient,
            payload: payload,
            collectionIds: collectionIds
        )
    }
}

enum TicketRowError: LocalizedError {
    case unknownTemplateKind(String)
    case unknownOrientation(String)
    case malformedCiphertext

    var errorDescription: String? {
        switch self {
        case .unknownTemplateKind(let s): return "Unknown ticket template: \(s)"
        case .unknownOrientation(let s):  return "Unknown ticket orientation: \(s)"
        case .malformedCiphertext:        return "Encrypted ticket payload is malformed."
        }
    }
}
