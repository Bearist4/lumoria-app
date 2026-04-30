//
//  CryptoAndCodecTests.swift
//  Lumoria AppTests
//
//  Exercises the crypto pipeline end-to-end: EncryptionService roundtrip,
//  TicketCodec, TicketLocation encrypt/decrypt, MemoryRow → Memory, and
//  TicketRow → Ticket. All tests run with a fixed symmetric key injected
//  via EncryptionService.keyProvider so they don't need Supabase or the
//  Keychain.
//

import CryptoKit
import Foundation
import Supabase
import Testing
@testable import Lumoria_App

// MARK: - Test fixtures

private enum CryptoFixture {
    /// Stable 256-bit key shared across these suites. Raw bytes are
    /// irrelevant — only determinism matters.
    static let key: SymmetricKey = {
        var bytes = Data(count: 32)
        for i in 0..<32 { bytes[i] = UInt8(i) }
        return SymmetricKey(data: bytes)
    }()

    /// Installs the fixed key into EncryptionService. Every test in the
    /// suites below is run after this has been set.
    static func install() {
        EncryptionService.keyProvider = { key }
    }

    static func restore() {
        EncryptionService.keyProvider = {
            guard let userId = supabase.auth.currentUser?.id else {
                throw EncryptionServiceError.noActiveUser
            }
            return try EncryptionService.keyFor(userId: userId)
        }
    }
}

// MARK: - EncryptionService

@Suite("EncryptionService", .serialized)
struct EncryptionServiceTests {

    init() { CryptoFixture.install() }

    @Test("Data round-trips through encrypt → decrypt")
    func dataRoundTrip() throws {
        let plain = Data("hello, lumoria".utf8)
        let cipher = try EncryptionService.encrypt(plain)
        #expect(cipher != plain)
        let back = try EncryptionService.decrypt(cipher)
        #expect(back == plain)
    }

    @Test("String helpers round-trip through base64 ciphertext")
    func stringRoundTrip() throws {
        let plain = "Ticket 001 · Paris → Tokyo"
        let cipher = try EncryptionService.encryptString(plain)
        #expect(Data(base64Encoded: cipher) != nil)
        #expect(try EncryptionService.decryptString(cipher) == plain)
    }

    @Test("Two encrypts of the same plaintext produce distinct ciphertexts")
    func nonDeterministic() throws {
        let a = try EncryptionService.encryptString("same input")
        let b = try EncryptionService.encryptString("same input")
        #expect(a != b)
    }

    @Test("decryptString rejects non-base64 input")
    func invalidBase64() {
        #expect(throws: EncryptionServiceError.self) {
            try EncryptionService.decryptString("not base 64 !!!!")
        }
    }

    @Test("decrypt throws on garbled ciphertext bytes")
    func garbledCiphertext() throws {
        let cipher = try EncryptionService.encrypt(Data("payload".utf8))
        var tampered = cipher
        // Flip a byte in the auth tag region (last 16 bytes of AES-GCM combined).
        let last = tampered.count - 1
        tampered[last] ^= 0xFF
        #expect(throws: (any Error).self) {
            _ = try EncryptionService.decrypt(tampered)
        }
    }

    @Test("Unicode survives the round-trip")
    func unicode() throws {
        let plain = "東京 → 大阪 · 🚄 · 日本"
        let back = try EncryptionService.decryptString(
            try EncryptionService.encryptString(plain)
        )
        #expect(back == plain)
    }
}

// MARK: - TicketLocation crypto

@Suite("TicketLocation encrypt/decrypt", .serialized)
struct TicketLocationCryptoTests {

    init() { CryptoFixture.install() }

    private func makeLocation() -> TicketLocation {
        TicketLocation(
            name: "Charles De Gaulle",
            subtitle: "CDG",
            city: "Paris",
            country: "France",
            countryCode: "FR",
            lat: 49.0097,
            lng: 2.5479,
            kind: .airport
        )
    }

    @Test("round-trips through encrypt → decrypt")
    func roundTrip() throws {
        let loc = makeLocation()
        let cipher = try TicketLocation.encrypt(loc)
        let back = try TicketLocation.decrypt(cipher)
        #expect(back == loc)
    }

    @Test("decrypt passes through nil")
    func nilPassthrough() throws {
        #expect(try TicketLocation.decrypt(nil) == nil)
    }

    @Test("decrypt rejects malformed base64")
    func malformedBase64() {
        #expect(throws: EncryptionServiceError.self) {
            _ = try TicketLocation.decrypt("!!!not b64!!!")
        }
    }
}

// MARK: - TicketCodec

@Suite("TicketCodec", .serialized)
struct TicketCodecTests {

    init() { CryptoFixture.install() }

    private func samplePayloads() -> [TicketPayload] {
        [
            .afterglow(.init(
                airline: "AF", flightNumber: "AF123",
                origin: "CDG", originCity: "Paris",
                destination: "LAX", destinationCity: "Los Angeles",
                date: "3 May 2026", gate: "F32", seat: "1A", boardingTime: "09:40"
            )),
            .studio(.init(
                airline: "AF", flightNumber: "AF010", cabinClass: "Economy",
                origin: "NRT", originName: "Narita", originLocation: "Tokyo, Japan",
                destination: "JFK", destinationName: "JFK", destinationLocation: "NY, USA",
                date: "8 Jun 2026", gate: "74", seat: "1K", departureTime: "11:05"
            )),
            .express(.init(
                trainType: "Shinkansen N700", trainNumber: "Hikari 503",
                cabinClass: "Green Car",
                originCity: "Tokyo", originCityKanji: "東京",
                destinationCity: "Osaka", destinationCityKanji: "大阪",
                date: "14.03.2026", departureTime: "06:33", arrivalTime: "09:10",
                car: "7", seat: "14A", ticketNumber: "000"
            )),
            .night(.init(
                company: "OBB Nightjet", trainType: "Comfort", trainCode: "NJ 295",
                originCity: "Vienna", originStation: "Wien Hbf",
                destinationCity: "Paris", destinationStation: "Gare de l'Est",
                passenger: "Jane Doe", car: "37", berth: "Lower",
                date: "14 Mar 2026 · 22:04", ticketNumber: "NJ-001"
            )),
        ]
    }

    @Test("payload round-trips through encode → decodePayload")
    func roundTripSpread() throws {
        for payload in samplePayloads() {
            let json = try TicketCodec.encode(payload)
            let decoded = try TicketCodec.decodePayload(kind: payload.kind, from: json)
            #expect(decoded.kind == payload.kind)
            // Deep-equality via Codable reflection — re-encode the decoded
            // payload and compare the JSON representation.
            let before = try JSONEncoder.snake().encode(payload)
            let after  = try JSONEncoder.snake().encode(decoded)
            #expect(before == after)
        }
    }

    @Test("encoded AnyJSON is a {c: <base64>} envelope")
    func envelopeShape() throws {
        let payload = samplePayloads()[0]
        let json = try TicketCodec.encode(payload)
        guard case .object(let dict) = json,
              case .string(let b64) = dict["c"]
        else {
            Issue.record("Expected {c: <string>} envelope")
            return
        }
        #expect(Data(base64Encoded: b64) != nil)
        #expect(dict.count == 1)
    }

    @Test("decodePayload throws on missing envelope")
    func decodeMissingEnvelope() {
        let bogus = AnyJSON.object(["x": .string("y")])
        #expect(throws: TicketRowError.self) {
            _ = try TicketCodec.decodePayload(kind: .studio, from: bogus)
        }
    }

    @Test("decodePayload throws on non-base64 cipher value")
    func decodeMalformedCipher() {
        let bogus = AnyJSON.object(["c": .string("!!!")])
        #expect(throws: TicketRowError.self) {
            _ = try TicketCodec.decodePayload(kind: .studio, from: bogus)
        }
    }

    @Test("decoding under a mismatched template kind fails")
    func kindMismatch() throws {
        let payload: TicketPayload = .express(.init(
            trainType: "", trainNumber: "",
            cabinClass: "",
            originCity: "", originCityKanji: "",
            destinationCity: "", destinationCityKanji: "",
            date: "", departureTime: "", arrivalTime: "",
            car: "", seat: "", ticketNumber: ""
        ))
        let json = try TicketCodec.encode(payload)
        // Decrypting works (same key), but JSON shape won't match StudioTicket.
        #expect(throws: (any Error).self) {
            _ = try TicketCodec.decodePayload(kind: .studio, from: json)
        }
    }
}

private extension JSONEncoder {
    static func snake() -> JSONEncoder {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.outputFormatting = [.sortedKeys]
        return e
    }
}

// MARK: - MemoryRow.toMemory

@Suite("MemoryRow.toMemory", .serialized)
struct MemoryRowDecryptTests {

    init() { CryptoFixture.install() }

    @Test("ciphertext fields decrypt into plaintext Memory")
    func decryptsFields() throws {
        let name = try EncryptionService.encryptString("Japan 2026")
        let emoji = try EncryptionService.encryptString("🗾")

        let json = """
        {
            "id": "\(UUID().uuidString)",
            "user_id": "\(UUID().uuidString)",
            "name": "\(name)",
            "color_family": "Indigo",
            "emoji_enc": "\(emoji)",
            "created_at": "2026-04-18T10:00:00Z",
            "updated_at": "2026-04-18T10:00:00Z"
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let row = try decoder.decode(MemoryRow.self, from: Data(json.utf8))
        let memory = try row.toMemory()

        #expect(memory.name == "Japan 2026")
        #expect(memory.emoji == "🗾")
        #expect(memory.colorFamily == "Indigo")
    }

    @Test("nil emoji_enc round-trips as nil plaintext emoji")
    func nilEmoji() throws {
        let name = try EncryptionService.encryptString("Solo trip")

        let json = """
        {
            "id": "\(UUID().uuidString)",
            "user_id": "\(UUID().uuidString)",
            "name": "\(name)",
            "color_family": "Green",
            "emoji_enc": null,
            "created_at": "2026-04-18T10:00:00Z",
            "updated_at": "2026-04-18T10:00:00Z"
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let row = try decoder.decode(MemoryRow.self, from: Data(json.utf8))
        let memory = try row.toMemory()
        #expect(memory.emoji == nil)
    }
}

// MARK: - TicketRow.toTicket

@Suite("TicketRow.toTicket", .serialized)
struct TicketRowDecodeTests {

    init() { CryptoFixture.install() }

    private func encodeSample() throws -> (payload: String, kind: TicketTemplateKind) {
        let payload: TicketPayload = .afterglow(.init(
            airline: "AF", flightNumber: "AF123",
            origin: "CDG", originCity: "Paris",
            destination: "LAX", destinationCity: "Los Angeles",
            date: "3 May 2026", gate: "F32", seat: "1A", boardingTime: "09:40"
        ))
        let json = try TicketCodec.encode(payload)
        let data = try JSONEncoder().encode(json)
        let asString = String(decoding: data, as: UTF8.self)
        return (asString, .afterglow)
    }

    @Test("happy path: decrypt payload + locations + memory links")
    func happyPath() throws {
        let (payloadJSON, kind) = try encodeSample()
        let origin = TicketLocation(
            name: "CDG", subtitle: "CDG", city: "Paris", country: "France",
            countryCode: "FR", lat: 49.0097, lng: 2.5479, kind: .airport
        )
        let destination = TicketLocation(
            name: "LAX", subtitle: "LAX", city: "Los Angeles", country: "United States",
            countryCode: "US", lat: 33.9416, lng: -118.4085, kind: .airport
        )
        let originEnc = try TicketLocation.encrypt(origin)
        let destEnc   = try TicketLocation.encrypt(destination)
        let memoryId = UUID()
        let ticketId = UUID()
        let userId = UUID()

        let rowJSON = """
        {
            "id": "\(ticketId.uuidString)",
            "user_id": "\(userId.uuidString)",
            "template_kind": "\(kind.rawValue)",
            "orientation": "horizontal",
            "payload": \(payloadJSON),
            "location_primary_enc": "\(originEnc)",
            "location_secondary_enc": "\(destEnc)",
            "style_id": null,
            "created_at": "2026-04-18T10:00:00Z",
            "updated_at": "2026-04-18T10:00:00Z",
            "memory_tickets": [
                { "memory_id": "\(memoryId.uuidString)" }
            ]
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let row = try decoder.decode(TicketRow.self, from: Data(rowJSON.utf8))
        let ticket = try row.toTicket()

        #expect(ticket.id == ticketId)
        #expect(ticket.kind == .afterglow)
        #expect(ticket.orientation == .horizontal)
        #expect(ticket.originLocation?.subtitle == "CDG")
        #expect(ticket.destinationLocation?.subtitle == "LAX")
        #expect(ticket.memoryIds == [memoryId])
        #expect(ticket.styleId == nil)
    }

    @Test("unknown template_kind surfaces a TicketRowError")
    func unknownKind() throws {
        let (payloadJSON, _) = try encodeSample()
        let json = """
        {
            "id": "\(UUID().uuidString)",
            "user_id": "\(UUID().uuidString)",
            "template_kind": "banana",
            "orientation": "horizontal",
            "payload": \(payloadJSON),
            "location_primary_enc": null,
            "location_secondary_enc": null,
            "style_id": null,
            "created_at": "2026-04-18T10:00:00Z",
            "updated_at": "2026-04-18T10:00:00Z"
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let row = try decoder.decode(TicketRow.self, from: Data(json.utf8))
        #expect(throws: TicketRowError.self) { _ = try row.toTicket() }
    }

    @Test("unknown orientation surfaces a TicketRowError")
    func unknownOrientation() throws {
        let (payloadJSON, kind) = try encodeSample()
        let json = """
        {
            "id": "\(UUID().uuidString)",
            "user_id": "\(UUID().uuidString)",
            "template_kind": "\(kind.rawValue)",
            "orientation": "diagonal",
            "payload": \(payloadJSON),
            "location_primary_enc": null,
            "location_secondary_enc": null,
            "style_id": null,
            "created_at": "2026-04-18T10:00:00Z",
            "updated_at": "2026-04-18T10:00:00Z"
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let row = try decoder.decode(TicketRow.self, from: Data(json.utf8))
        #expect(throws: TicketRowError.self) { _ = try row.toTicket() }
    }

    @Test("missing memory_tickets embed → empty memoryIds")
    func missingEmbed() throws {
        let (payloadJSON, kind) = try encodeSample()
        let json = """
        {
            "id": "\(UUID().uuidString)",
            "user_id": "\(UUID().uuidString)",
            "template_kind": "\(kind.rawValue)",
            "orientation": "horizontal",
            "payload": \(payloadJSON),
            "location_primary_enc": null,
            "location_secondary_enc": null,
            "style_id": null,
            "created_at": "2026-04-18T10:00:00Z",
            "updated_at": "2026-04-18T10:00:00Z"
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let row = try decoder.decode(TicketRow.self, from: Data(json.utf8))
        let ticket = try row.toTicket()
        #expect(ticket.memoryIds.isEmpty)
    }
}

// MARK: - MemoryDateCodec (used for tickets.event_date_enc + memories.start/end)

@Suite("MemoryDateCodec", .serialized)
struct MemoryDateCodecTests {

    init() { CryptoFixture.install() }

    @Test("round-trips an arbitrary date")
    func roundTrip() throws {
        // 2026-04-30 14:32:08 UTC — non-aligned seconds so any precision
        // loss in the codec surfaces.
        let original = Date(timeIntervalSince1970: 1_777_660_328)
        let cipher = try MemoryDateCodec.encrypt(original)
        let decoded = try MemoryDateCodec.decrypt(cipher)

        // ISO-8601 keeps second precision.
        #expect(Int(original.timeIntervalSince1970) == Int(decoded.timeIntervalSince1970))
    }
}
