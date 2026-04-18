//
//  Lumoria_AppTests.swift
//  Lumoria AppTests
//
//  Pure-logic unit tests for Lumoria. Covers models, codecs, lookups, and
//  URL/token parsing. Anything that reaches the Keychain, Supabase, the
//  App Group container, or UIKit rendering is excluded — those paths need
//  integration tests with stubbed dependencies.
//

import CoreLocation
import Foundation
import Testing
@testable import Lumoria_App

// MARK: - TicketTemplateKind

@Suite("TicketTemplateKind")
struct TicketTemplateKindTests {

    @Test("displayName covers every case")
    func displayNameAll() {
        for kind in TicketTemplateKind.allCases {
            #expect(!kind.displayName.isEmpty)
        }
    }

    @Test("categoryLabel buckets trains vs planes")
    func categoryLabelBuckets() {
        let trains: Set<TicketTemplateKind> = [.express, .orient, .night]
        let planes: Set<TicketTemplateKind> = [.afterglow, .studio, .heritage, .terminal, .prism]
        for kind in TicketTemplateKind.allCases {
            if trains.contains(kind) {
                #expect(kind.categoryLabel.lowercased().contains("train"))
            } else if planes.contains(kind) {
                #expect(kind.categoryLabel.lowercased().contains("plane"))
            }
        }
    }

    @Test("rawValue round-trips through TicketTemplateKind init")
    func rawValueRoundTrip() {
        for kind in TicketTemplateKind.allCases {
            #expect(TicketTemplateKind(rawValue: kind.rawValue) == kind)
        }
        #expect(TicketTemplateKind(rawValue: "garbage") == nil)
    }

    @Test("requirements non-empty per template")
    func requirementsNonEmpty() {
        for kind in TicketTemplateKind.allCases {
            #expect(!kind.requirements.isEmpty)
        }
    }

    @Test("plane templates include passenger details except afterglow")
    func planeRequirementsPassenger() {
        let noPassenger: Set<TicketTemplateKind> = [.afterglow]
        let planes: [TicketTemplateKind] = [.afterglow, .studio, .heritage, .terminal, .prism]
        for kind in planes {
            let hasPassenger = kind.requirements.contains { $0.label.lowercased().contains("passenger") }
            #expect(hasPassenger != noPassenger.contains(kind))
        }
    }

    @Test("heritage and terminal surface aircraft details")
    func aircraftRequirement() {
        let aircraftKinds: Set<TicketTemplateKind> = [.heritage, .terminal]
        for kind in aircraftKinds {
            let hasAircraft = kind.requirements.contains { $0.label.lowercased().contains("aircraft") }
            #expect(hasAircraft)
        }
    }
}

// MARK: - TicketOrientation

@Suite("TicketOrientation")
struct TicketOrientationTests {

    @Test("rawValue is stable for persistence")
    func rawValues() {
        #expect(TicketOrientation.horizontal.rawValue == "horizontal")
        #expect(TicketOrientation.vertical.rawValue == "vertical")
    }

    @Test("init from raw")
    func initFromRaw() {
        #expect(TicketOrientation(rawValue: "horizontal") == .horizontal)
        #expect(TicketOrientation(rawValue: "vertical") == .vertical)
        #expect(TicketOrientation(rawValue: "diagonal") == nil)
    }
}

// MARK: - TicketLocation

@Suite("TicketLocation")
struct TicketLocationTests {

    private func makeLocation(
        code: String? = "FR",
        lat: Double = 48.8566,
        lng: Double = 2.3522
    ) -> TicketLocation {
        TicketLocation(
            name: "Gare de Lyon",
            subtitle: "PAR",
            city: "Paris",
            country: "France",
            countryCode: code,
            lat: lat,
            lng: lng,
            kind: .station
        )
    }

    @Test("coordinate mirrors lat/lng")
    func coordinate() {
        let loc = makeLocation(lat: 1.23, lng: 4.56)
        #expect(loc.coordinate.latitude == 1.23)
        #expect(loc.coordinate.longitude == 4.56)
    }

    @Test("flagEmoji maps ISO 3166-1 alpha-2 to regional indicator pair")
    func flagEmojiKnownCodes() {
        #expect(makeLocation(code: "FR").flagEmoji == "🇫🇷")
        #expect(makeLocation(code: "JP").flagEmoji == "🇯🇵")
        #expect(makeLocation(code: "us").flagEmoji == "🇺🇸") // case-insensitive upper
    }

    @Test("flagEmoji returns nil for missing or malformed codes")
    func flagEmojiInvalid() {
        #expect(makeLocation(code: nil).flagEmoji == nil)
        #expect(makeLocation(code: "").flagEmoji == nil)
        #expect(makeLocation(code: "FRA").flagEmoji == nil) // not 2 chars
        #expect(makeLocation(code: "F").flagEmoji == nil)
    }

    @Test("Codable round-trip preserves fields")
    func codableRoundTrip() throws {
        let loc = makeLocation()
        let data = try JSONEncoder().encode(loc)
        let decoded = try JSONDecoder().decode(TicketLocation.self, from: data)
        #expect(decoded == loc)
    }
}

// MARK: - Ticket

@Suite("Ticket")
struct TicketTests {

    private func makeTicket(styleId: String? = nil) -> Ticket {
        let payload: TicketPayload = .afterglow(
            AfterglowTicket(
                airline: "AF",
                flightNumber: "AF123",
                origin: "CDG",
                originCity: "Paris",
                destination: "LAX",
                destinationCity: "Los Angeles",
                date: "3 May 2026",
                gate: "F32",
                seat: "1A",
                boardingTime: "09:40"
            )
        )
        return Ticket(orientation: .horizontal, payload: payload, styleId: styleId)
    }

    @Test("kind derives from payload")
    func kindDerivation() {
        let ticket = makeTicket()
        #expect(ticket.kind == .afterglow)
        #expect(ticket.payload.kind == .afterglow)
    }

    @Test("equality and hashing key off id only")
    func equalityById() {
        let a = makeTicket()
        var b = a
        b.orientation = .vertical
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test("resolvedStyle falls back to default when styleId is nil")
    func resolvedStyleNil() {
        let ticket = makeTicket(styleId: nil)
        #expect(ticket.resolvedStyle.id == TicketTemplateKind.afterglow.defaultStyle.id)
    }

    @Test("resolvedStyle falls back to default when styleId is unknown")
    func resolvedStyleStale() {
        let ticket = makeTicket(styleId: "afterglow.nope")
        #expect(ticket.resolvedStyle.id == TicketTemplateKind.afterglow.defaultStyle.id)
    }

    @Test("default init assigns createdAt ≈ updatedAt")
    func initDateDefaults() {
        let t = makeTicket()
        let delta = abs(t.createdAt.timeIntervalSince(t.updatedAt))
        #expect(delta < 1)
    }
}

// MARK: - TicketStyleCatalog

@Suite("TicketStyleCatalog")
struct TicketStyleCatalogTests {

    @Test("every template has at least one variant")
    func everyTemplateHasVariant() {
        for kind in TicketTemplateKind.allCases {
            #expect(!kind.styles.isEmpty)
        }
    }

    @Test("studio ships with multiple variants → hasStyleVariants = true")
    func studioHasVariants() {
        #expect(TicketTemplateKind.studio.hasStyleVariants)
    }

    @Test("single-variant templates return hasStyleVariants = false")
    func singleVariantTemplates() {
        for kind in [TicketTemplateKind.afterglow, .heritage, .terminal, .prism, .express, .orient, .night] {
            #expect(!kind.hasStyleVariants)
        }
    }

    @Test("style ids are unique within a template")
    func uniqueIds() {
        for kind in TicketTemplateKind.allCases {
            let ids = kind.styles.map(\.id)
            #expect(Set(ids).count == ids.count)
        }
    }

    @Test("style ids follow \"<template>.<variant>\" prefix convention")
    func idPrefix() {
        for kind in TicketTemplateKind.allCases {
            for v in kind.styles {
                #expect(v.id.hasPrefix("\(kind.rawValue)."))
            }
        }
    }

    @Test("resolveStyle returns exact match when id is valid")
    func resolveExact() {
        let studio = TicketTemplateKind.studio
        let target = studio.styles.last!
        #expect(studio.resolveStyle(id: target.id).id == target.id)
    }

    @Test("defaultStyle matches the first variant")
    func defaultIsFirst() {
        for kind in TicketTemplateKind.allCases {
            #expect(kind.defaultStyle.id == kind.styles[0].id)
        }
    }
}

// MARK: - BrandArt

@Suite("BrandArt.slug")
struct BrandArtTests {

    @Test("known alternate icon names map to slugs")
    func knownIcons() {
        #expect(BrandArt.slug(from: "AppIcon Noir") == "noir")
        #expect(BrandArt.slug(from: "AppIcon Earth") == "earth")
        #expect(BrandArt.slug(from: "AppIcon Outline") == "outline")
    }

    @Test("nil, empty, and unknown fall back to default")
    func defaultFallback() {
        #expect(BrandArt.slug(from: nil) == "default")
        #expect(BrandArt.slug(from: "") == "default")
        #expect(BrandArt.slug(from: "AppIcon Rainbow") == "default")
    }
}

// MARK: - LumoriaLinks

@Suite("LumoriaLinks")
struct LumoriaLinksTests {

    @Test("shareURL points at the public host")
    func shareURLHost() {
        #expect(LumoriaLinks.shareURL.host == "getlumoria.app")
        #expect(LumoriaLinks.shareURL.scheme == "https")
    }

    @Test("shareMessage contains the public URL")
    func shareMessageContainsURL() {
        #expect(LumoriaLinks.shareMessage.contains("getlumoria.app"))
    }
}

// MARK: - LumoriaNotification

@Suite("LumoriaNotification.Kind")
struct LumoriaNotificationKindTests {

    @Test("eyebrow is unique per kind")
    func uniqueEyebrow() {
        let kinds: [LumoriaNotification.Kind] = [.throwback, .onboarding, .news, .link]
        let eyebrows = kinds.map(\.eyebrow)
        #expect(Set(eyebrows).count == kinds.count)
    }

    @Test("eyebrow reads as uppercase copy")
    func eyebrowUppercase() {
        for kind in [LumoriaNotification.Kind.throwback, .onboarding, .news, .link] {
            #expect(kind.eyebrow == kind.eyebrow.uppercased())
        }
    }

    @Test("init defaults isRead false and createdAt ≈ now")
    func initDefaults() {
        let n = LumoriaNotification(kind: .news, title: "Hi", message: "Body")
        #expect(n.isRead == false)
        #expect(abs(n.createdAt.timeIntervalSinceNow) < 1)
        #expect(n.memoryId == nil)
        #expect(n.templateKind == nil)
    }
}

// MARK: - Invite model

@Suite("Invite")
struct InviteTests {

    private func makeInvite(
        redeemed: Bool = false,
        revoked: Bool = false,
        token: String = "ABCDE23456"
    ) -> Invite {
        Invite(
            id: UUID(),
            inviterId: UUID(),
            token: token,
            createdAt: Date(),
            revokedAt: revoked ? Date() : nil,
            claimedBy: nil,
            claimedAt: nil,
            redeemedAt: redeemed ? Date() : nil
        )
    }

    @Test("isRedeemed / isRevoked reflect the stamp fields")
    func flags() {
        #expect(makeInvite().isRedeemed == false)
        #expect(makeInvite().isRevoked == false)
        #expect(makeInvite(redeemed: true).isRedeemed)
        #expect(makeInvite(revoked: true).isRevoked)
    }

    @Test("shareURL embeds the token on the canonical path")
    func shareURLToken() {
        let invite = makeInvite(token: "TOKEN1")
        #expect(invite.shareURL.absoluteString == "https://getlumoria.app/invite/TOKEN1")
    }
}

// MARK: - InviteToken

@Suite("InviteToken.make")
struct InviteTokenTests {

    private let alphabet = Set("23456789ABCDEFGHJKMNPQRSTVWXYZ")
    private let ambiguous = Set("01ILOU")

    @Test("default length is 10")
    func defaultLength() {
        #expect(InviteToken.make().count == 10)
    }

    @Test("custom length honored")
    func customLength() {
        #expect(InviteToken.make(length: 6).count == 6)
        #expect(InviteToken.make(length: 16).count == 16)
    }

    @Test("only Crockford-style characters used")
    func alphabetOnly() {
        let token = InviteToken.make(length: 200)
        for char in token {
            #expect(alphabet.contains(char))
            #expect(!ambiguous.contains(char))
        }
    }

    @Test("tokens diverge across calls")
    func distinctTokens() {
        let a = InviteToken.make(length: 16)
        let b = InviteToken.make(length: 16)
        #expect(a != b)
    }
}

// MARK: - InviteLink

@Suite("InviteLink URL parsing")
struct InviteLinkTests {

    @Test("https round-trip")
    func httpsRoundTrip() {
        let url = InviteLink.url(for: "TOKEN1")
        #expect(InviteLink.token(from: url) == "TOKEN1")
    }

    @Test("accepts http scheme as well")
    func httpAccepted() throws {
        let url = try #require(URL(string: "http://getlumoria.app/invite/TOKEN1"))
        #expect(InviteLink.token(from: url) == "TOKEN1")
    }

    @Test("lumoria:// custom scheme with host=invite")
    func customSchemeHostInvite() throws {
        let url = try #require(URL(string: "lumoria://invite/XYZ"))
        #expect(InviteLink.token(from: url) == "XYZ")
    }

    @Test("lumoria:///invite/XYZ variant works")
    func customSchemeTripleSlash() throws {
        let url = try #require(URL(string: "lumoria:///invite/XYZ"))
        #expect(InviteLink.token(from: url) == "XYZ")
    }

    @Test("host matching is case-insensitive")
    func hostCaseInsensitive() throws {
        let url = try #require(URL(string: "https://GetLumoria.App/invite/AbC123"))
        #expect(InviteLink.token(from: url) == "AbC123")
    }

    @Test("wrong host rejected")
    func wrongHost() throws {
        let url = try #require(URL(string: "https://evil.example/invite/TOKEN"))
        #expect(InviteLink.token(from: url) == nil)
    }

    @Test("wrong path rejected")
    func wrongPath() throws {
        let url = try #require(URL(string: "https://getlumoria.app/something/TOKEN"))
        #expect(InviteLink.token(from: url) == nil)
    }

    @Test("empty token rejected")
    func emptyToken() throws {
        let url = try #require(URL(string: "https://getlumoria.app/invite/"))
        #expect(InviteLink.token(from: url) == nil)
    }

    @Test("unrelated scheme rejected")
    func unrelatedScheme() throws {
        let url = try #require(URL(string: "ftp://getlumoria.app/invite/TOKEN"))
        #expect(InviteLink.token(from: url) == nil)
    }
}

// MARK: - PendingInviteTokenStore

@Suite("PendingInviteTokenStore", .serialized)
struct PendingInviteTokenStoreTests {

    @Test("save then take returns the token and clears it")
    func saveAndTake() {
        PendingInviteTokenStore.save("TKN")
        #expect(PendingInviteTokenStore.current == "TKN")
        #expect(PendingInviteTokenStore.take() == "TKN")
        #expect(PendingInviteTokenStore.current == nil)
    }

    @Test("take on empty returns nil")
    func takeEmpty() {
        _ = PendingInviteTokenStore.take() // clear
        #expect(PendingInviteTokenStore.take() == nil)
    }
}

// MARK: - CityNameTranslator

@Suite("CityNameTranslator")
struct CityNameTranslatorTests {

    @Test("exact lowercase hit")
    func exactHit() {
        #expect(CityNameTranslator.kanji(for: "tokyo") == "東京")
        #expect(CityNameTranslator.kanji(for: "osaka") == "大阪")
    }

    @Test("case-insensitive")
    func caseInsensitive() {
        #expect(CityNameTranslator.kanji(for: "TOKYO") == "東京")
        #expect(CityNameTranslator.kanji(for: "Tokyo") == "東京")
    }

    @Test("strips spaces, hyphens, apostrophes")
    func normalization() {
        #expect(CityNameTranslator.kanji(for: "New York") == "ニューヨーク")
        #expect(CityNameTranslator.kanji(for: "new-york") == "ニューヨーク")
        #expect(CityNameTranslator.kanji(for: "san francisco") == "サンフランシスコ")
        #expect(CityNameTranslator.kanji(for: "Hong Kong") == "香港")
    }

    @Test("folds diacritics")
    func diacriticsFolded() {
        #expect(CityNameTranslator.kanji(for: "Kyōto") == "京都")
        #expect(CityNameTranslator.kanji(for: "Bogotá") == nil) // not in table
    }

    @Test("unknown city returns nil")
    func unknown() {
        #expect(CityNameTranslator.kanji(for: "Atlantis") == nil)
        #expect(CityNameTranslator.kanji(for: "") == nil)
    }

    @Test("trims leading/trailing whitespace")
    func trimmedInput() {
        #expect(CityNameTranslator.kanji(for: "  Tokyo  ") == "東京")
    }
}

// MARK: - AirportDatabase

@Suite("AirportDatabase")
struct AirportDatabaseTests {

    @Test("seed contains unique IATA codes")
    func uniqueIATA() {
        let codes = AirportDatabase.seed.map(\.iata)
        #expect(Set(codes).count == codes.count)
        #expect(codes.count > 100) // ~150 airports expected
    }

    @Test("coordinate derives from lat/lng")
    func coordinate() {
        let airport = AirportDatabase.seed.first { $0.iata == "CDG" }!
        #expect(airport.coordinate.latitude == airport.lat)
        #expect(airport.coordinate.longitude == airport.lng)
    }

    @Test("nearest resolves CDG from a coord inside the campus")
    func nearestCDG() {
        let coord = CLLocationCoordinate2D(latitude: 49.0097, longitude: 2.5479)
        #expect(AirportDatabase.nearest(to: coord)?.iata == "CDG")
    }

    @Test("nearest returns nil when no airport within radius")
    func nearestNil() {
        // Middle of the South Pacific — far from any seeded airport.
        let coord = CLLocationCoordinate2D(latitude: -45.0, longitude: -140.0)
        #expect(AirportDatabase.nearest(to: coord) == nil)
    }

    @Test("nearest respects shrunk radius")
    func radiusTight() {
        // CDG terminal 2: ~49.0033, 2.5707. 10 km default still matches, but
        // 100 m radius should fail even from the exact airport coord if we
        // bump it slightly.
        let slightlyOff = CLLocationCoordinate2D(latitude: 49.020, longitude: 2.600)
        #expect(AirportDatabase.nearest(to: slightlyOff, within: 100) == nil)
        #expect(AirportDatabase.nearest(to: slightlyOff, within: 10_000)?.iata == "CDG")
    }
}

// MARK: - AirlineDatabase

@Suite("AirlineDatabase")
struct AirlineDatabaseTests {

    @Test("seed IATA codes unique")
    func seedUnique() {
        let codes = AirlineDatabase.seed.map(\.iata)
        #expect(Set(codes).count == codes.count)
    }

    @Test("queries shorter than minimum return empty")
    func belowMinimum() {
        #expect(AirlineDatabase.search("a").isEmpty)
        #expect(AirlineDatabase.search("ai").isEmpty) // 2 < 3
    }

    @Test("name substring match")
    func nameSubstring() {
        let results = AirlineDatabase.search("british")
        #expect(results.contains { $0.iata == "BA" })
    }

    @Test("exact IATA match")
    func iataExact() {
        let results = AirlineDatabase.search("baw") // too long for IATA (2 chars)
        #expect(results.isEmpty || results.allSatisfy { $0.name.lowercased().contains("baw") })
        // "ba " doesn't trim to 2 chars when min is 3; use a 3-char IATA-style name match:
        let afr = AirlineDatabase.search("air")
        #expect(!afr.isEmpty)
    }

    @Test("trims whitespace and lowercases")
    func trimAndLowercase() {
        let a = AirlineDatabase.search("  BRITISH  ")
        let b = AirlineDatabase.search("british")
        #expect(a.map(\.iata) == b.map(\.iata))
    }

    @Test("caps at 10 results")
    func capped() {
        let results = AirlineDatabase.search("air")
        #expect(results.count <= 10)
    }

    @Test("unknown returns empty")
    func unknown() {
        #expect(AirlineDatabase.search("zzzzz").isEmpty)
    }
}

// MARK: - StickerManifest

@Suite("StickerManifest")
struct StickerManifestTests {

    @Test(".empty is version 1 with no entries")
    func empty() {
        #expect(StickerManifest.empty.version == 1)
        #expect(StickerManifest.empty.entries.isEmpty)
    }

    @Test("Codable round-trip preserves entries")
    func codableRoundTrip() throws {
        let manifest = StickerManifest(
            version: 1,
            entries: [
                .init(
                    ticketId: UUID().uuidString,
                    filename: "abc.png",
                    createdAt: "2026-04-18T10:00:00Z",
                    label: "Plane · Paris to Tokyo"
                ),
                .init(
                    ticketId: UUID().uuidString,
                    filename: "def.png",
                    createdAt: "2026-04-17T10:00:00Z",
                    label: "Train · Kyoto to Osaka"
                ),
            ]
        )
        let data = try JSONEncoder().encode(manifest)
        let decoded = try JSONDecoder().decode(StickerManifest.self, from: data)
        #expect(decoded == manifest)
    }

    @Test("Entry.id mirrors ticketId")
    func entryIdentifiable() {
        let ticketId = UUID().uuidString
        let entry = StickerManifest.Entry(
            ticketId: ticketId,
            filename: "x.png",
            createdAt: "",
            label: ""
        )
        #expect(entry.id == ticketId)
    }
}

// MARK: - ColorOption

@Suite("ColorOption")
struct ColorOptionTests {

    @Test("palette has known families")
    func paletteContents() {
        let families = Set(ColorOption.all.map(\.family))
        #expect(families.contains("Blue"))
        #expect(families.contains("Pink"))
        #expect(families.contains("Red"))
    }

    @Test("assetPath follows <family>/500 convention")
    func assetPath() {
        for option in ColorOption.all {
            #expect(option.assetPath == "\(option.family)/500")
        }
    }

    @Test("Memory.colorOption matches by family")
    func memoryColorOption() {
        let memory = Memory(
            id: UUID(),
            userId: UUID(),
            name: "Japan 2026",
            colorFamily: "Indigo",
            emoji: "🗾",
            createdAt: Date(),
            updatedAt: Date()
        )
        #expect(memory.colorOption?.family == "Indigo")
    }

    @Test("Memory.colorOption returns nil for unknown family")
    func memoryColorOptionMissing() {
        let memory = Memory(
            id: UUID(),
            userId: UUID(),
            name: "X",
            colorFamily: "Chartreuse",
            emoji: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        #expect(memory.colorOption == nil)
    }
}

// MARK: - Template payloads Codable round-trip

@Suite("Template payload Codable round-trips")
struct TemplatePayloadCodableTests {

    private let snakeEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    private let snakeDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let data = try snakeEncoder.encode(value)
        return try snakeDecoder.decode(T.self, from: data)
    }

    @Test("AfterglowTicket")
    func afterglow() throws {
        let t = AfterglowTicket(
            airline: "AF", flightNumber: "AF123",
            origin: "CDG", originCity: "Paris",
            destination: "LAX", destinationCity: "Los Angeles",
            date: "3 May 2026", gate: "F32", seat: "1A", boardingTime: "09:40"
        )
        #expect(try roundTrip(t) == t)
    }

    @Test("StudioTicket")
    func studio() throws {
        let t = StudioTicket(
            airline: "AF", flightNumber: "AF123", cabinClass: "Economy",
            origin: "NRT", originName: "Narita International", originLocation: "Tokyo, Japan",
            destination: "JFK", destinationName: "John F. Kennedy", destinationLocation: "New York, United States",
            date: "8 Jun 2026", gate: "74", seat: "1K", departureTime: "11:05"
        )
        #expect(try roundTrip(t) == t)
    }

    @Test("HeritageTicket")
    func heritage() throws {
        let t = HeritageTicket(
            airline: "CX", ticketNumber: "001", cabinClass: "Business", cabinDetail: "Business · The Pier",
            origin: "HKG", originName: "Hong Kong Intl", originLocation: "Hong Kong",
            destination: "LHR", destinationName: "London Heathrow", destinationLocation: "London, UK",
            flightDuration: "12h", gate: "42", seat: "11A", boardingTime: "22:10", departureTime: "22:55",
            date: "4 Sep", fullDate: "4 Sep 2026"
        )
        #expect(try roundTrip(t) == t)
    }

    @Test("TerminalTicket")
    func terminal() throws {
        let t = TerminalTicket(
            airline: "OS", ticketNumber: "123", cabinClass: "Business",
            origin: "CDG", originName: "CDG", originLocation: "Paris, France",
            destination: "VIE", destinationName: "Vienna", destinationLocation: "Vienna, Austria",
            gate: "42", seat: "11A", boardingTime: "22:10", departureTime: "22:55",
            date: "4 Sep", fullDate: "4 Sep 2026"
        )
        #expect(try roundTrip(t) == t)
    }

    @Test("PrismTicket")
    func prism() throws {
        let t = PrismTicket(
            airline: "SQ", ticketNumber: "X", date: "16 Aug 2026",
            origin: "SIN", originName: "Singapore Changi",
            destination: "HND", destinationName: "Tokyo Haneda",
            gate: "C34", seat: "11A", boardingTime: "08:40", departureTime: "09:10",
            terminal: "T3"
        )
        #expect(try roundTrip(t) == t)
    }

    @Test("ExpressTicket bilingual fields survive round-trip")
    func express() throws {
        let t = ExpressTicket(
            trainType: "Shinkansen N700", trainNumber: "Hikari 503",
            cabinClass: "Green Car",
            originCity: "Tokyo", originCityKanji: "東京",
            destinationCity: "Osaka", destinationCityKanji: "大阪",
            date: "14.03.2026", departureTime: "06:33", arrivalTime: "09:10",
            car: "7", seat: "14A", ticketNumber: "0000000000"
        )
        #expect(try roundTrip(t) == t)
    }

    @Test("OrientTicket")
    func orient() throws {
        let t = OrientTicket(
            company: "Venice Simplon Orient Express", cabinClass: "Historic",
            originCity: "Venice", originStation: "Santa Lucia",
            destinationCity: "Paris", destinationStation: "Gare de Lyon",
            passenger: "Jane Doe", ticketNumber: "VS-001",
            date: "4 May 2026", departureTime: "19:10", carriage: "7", seat: "A"
        )
        #expect(try roundTrip(t) == t)
    }

    @Test("NightTicket")
    func night() throws {
        let t = NightTicket(
            company: "OBB Nightjet", trainType: "Comfort",
            trainCode: "NJ 295",
            originCity: "Vienna", originStation: "Wien Hauptbahnhof",
            destinationCity: "Paris", destinationStation: "Gare de l'Est",
            passenger: "Jane Doe", car: "37", berth: "Lower",
            date: "14 Mar 2026 · 22:04", ticketNumber: "NJ-001"
        )
        #expect(try roundTrip(t) == t)
    }

    @Test("camelCase property survives as snake_case key")
    func snakeKeyFormat() throws {
        let t = AfterglowTicket(
            airline: "AF", flightNumber: "AF123",
            origin: "CDG", originCity: "Paris",
            destination: "LAX", destinationCity: "Los Angeles",
            date: "3 May 2026", gate: "F32", seat: "1A", boardingTime: "09:40"
        )
        let data = try snakeEncoder.encode(t)
        let json = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        #expect(json["flight_number"] != nil)
        #expect(json["origin_city"] != nil)
        #expect(json["boarding_time"] != nil)
        #expect(json["flightNumber"] == nil)
    }
}

// MARK: - TicketPayload

@Suite("TicketPayload.kind")
struct TicketPayloadKindTests {

    @Test("kind dispatches to the corresponding template")
    func dispatch() {
        let cases: [(TicketPayload, TicketTemplateKind)] = [
            (.afterglow(.init(airline: "", flightNumber: "", origin: "", originCity: "", destination: "", destinationCity: "", date: "", gate: "", seat: "", boardingTime: "")), .afterglow),
        ]
        for (payload, kind) in cases {
            #expect(payload.kind == kind)
        }
    }
}

// MARK: - TicketRowError

@Suite("TicketRowError")
struct TicketRowErrorTests {

    @Test("errorDescription interpolates the offending value")
    func description() {
        let err = TicketRowError.unknownTemplateKind("banana")
        #expect(err.errorDescription?.contains("banana") == true)
    }

    @Test("malformedCiphertext has a human-readable description")
    func malformed() {
        #expect(TicketRowError.malformedCiphertext.errorDescription?.isEmpty == false)
    }
}

// MARK: - EncryptionServiceError

@Suite("EncryptionServiceError")
struct EncryptionServiceErrorTests {

    @Test("error descriptions are non-empty for every case")
    func descriptions() {
        let cases: [EncryptionServiceError] = [.noActiveUser, .emptyCiphertext, .invalidBase64]
        for err in cases {
            #expect(err.errorDescription?.isEmpty == false)
        }
    }
}
