//
//  StickerRenderServiceTests.swift
//  Lumoria AppTests
//
//  Full lifecycle tests for StickerRenderService + StickerManifest against
//  a per-test temporary directory. UIKit rendering runs inside the iOS
//  simulator, so render() is exercised against real ImageRenderer output.
//

import CryptoKit
import Foundation
import Testing
@testable import Lumoria_App

// MARK: - Temp dir helper

private enum TempStickerDir {
    static func fresh() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumoria-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true
        )
        return dir
    }

    static func cleanUp(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - Accessibility label (pure)

@MainActor
@Suite("StickerRenderService.accessibilityLabel")
struct StickerAccessibilityLabelTests {

    private func ticket(
        origin: TicketLocation? = nil,
        destination: TicketLocation? = nil
    ) -> Ticket {
        let payload: TicketPayload = .afterglow(.init(
            airline: "AF", flightNumber: "AF1", origin: "CDG", originCity: "Paris",
            destination: "LAX", destinationCity: "LA",
            date: "3 May", gate: "F32", seat: "1A", boardingTime: "09:40"
        ))
        return Ticket(
            orientation: .horizontal,
            payload: payload,
            originLocation: origin,
            destinationLocation: destination
        )
    }

    private func loc(code: String) -> TicketLocation {
        TicketLocation(
            name: code, subtitle: code, city: code, country: "FR",
            countryCode: "FR", lat: 0, lng: 0, kind: .airport
        )
    }

    @Test("trip: category · origin to destination")
    func trip() {
        let t = ticket(origin: loc(code: "CDG"), destination: loc(code: "LAX"))
        let label = StickerRenderService.accessibilityLabel(for: t)
        #expect(label.contains("Plane") || label.contains("plane"))
        #expect(label.contains("CDG"))
        #expect(label.contains("LAX"))
    }

    @Test("origin only: category · origin")
    func originOnly() {
        let t = ticket(origin: loc(code: "CDG"), destination: nil)
        let label = StickerRenderService.accessibilityLabel(for: t)
        #expect(label.contains("CDG"))
        #expect(!label.contains("LAX"))
    }

    @Test("no locations: category only")
    func noLocations() {
        let t = ticket(origin: nil, destination: nil)
        let label = StickerRenderService.accessibilityLabel(for: t)
        #expect(!label.isEmpty)
        #expect(!label.contains("·"))
    }

    @Test("falls back to name when subtitle empty")
    func nameFallback() {
        let origin = TicketLocation(
            name: "Unknown Field", subtitle: "", city: "X", country: "X",
            countryCode: "XX", lat: 0, lng: 0, kind: .airport
        )
        let t = ticket(origin: origin, destination: nil)
        let label = StickerRenderService.accessibilityLabel(for: t)
        #expect(label.contains("Unknown Field"))
    }
}

// MARK: - Manifest against tmp dir

@Suite("StickerManifest persistence (tmp dir)", .serialized)
struct StickerManifestPersistenceTests {

    private func withTempDir<T>(_ body: () throws -> T) rethrows -> T {
        let dir = try! TempStickerDir.fresh()
        StickerAppGroup.directoryOverride = dir
        defer {
            StickerAppGroup.directoryOverride = nil
            TempStickerDir.cleanUp(dir)
        }
        return try body()
    }

    @Test("missing manifest file returns .empty")
    func missingManifest() throws {
        try withTempDir {
            let manifest = StickerManifest.load()
            #expect(manifest == .empty)
        }
    }

    @Test("save then load round-trips the entries")
    func saveLoadRoundTrip() throws {
        try withTempDir {
            let manifest = StickerManifest(
                version: 1,
                entries: [
                    .init(
                        ticketId: UUID().uuidString,
                        filename: "a.png",
                        createdAt: "2026-04-18T10:00:00Z",
                        label: "Plane · CDG to LAX"
                    ),
                ]
            )
            try manifest.save()
            let reloaded = StickerManifest.load()
            #expect(reloaded == manifest)
        }
    }

    @Test("save is atomic — no leftover .tmp file")
    func atomicSave() throws {
        try withTempDir {
            try StickerManifest(version: 1, entries: []).save()
            let dir = try #require(StickerAppGroup.stickersDirectory)
            let contents = try FileManager.default.contentsOfDirectory(atPath: dir.path)
            #expect(contents.contains("manifest.json"))
            #expect(!contents.contains { $0.hasSuffix(".tmp") })
        }
    }
}

// MARK: - Render lifecycle (requires UIKit — iOS simulator only)

#if canImport(UIKit)
@MainActor
@Suite("StickerRenderService lifecycle", .serialized)
struct StickerRenderLifecycleTests {

    private func installKey() {
        var bytes = Data(count: 32)
        for i in 0..<32 { bytes[i] = UInt8(i) }
        EncryptionService.keyProvider = { SymmetricKey(data: bytes) }
    }

    private func sampleTicket(id: UUID = UUID()) -> Ticket {
        Ticket(
            id: id,
            orientation: .horizontal,
            payload: .prism(.init(
                airline: "SQ", ticketNumber: "X", date: "16 Aug 2026",
                origin: "SIN", originName: "Changi",
                destination: "HND", destinationName: "Haneda",
                gate: "C34", seat: "11A", boardingTime: "08:40",
                departureTime: "09:10", terminal: "T3"
            ))
        )
    }

    /// Drives the service's private task queue forward. `render` returns
    /// immediately and enqueues work on an internal chain; tests need a
    /// way to block until that chain has drained. Wrapping a Task on
    /// MainActor lets the queued op run to completion before we poll
    /// disk state.
    private func drain() async {
        // The service serializes via a private `pending` Task. Yield
        // a few times so the continuation chain can fire. In practice
        // one hop suffices, but give it some slack.
        for _ in 0..<5 { await Task.yield() }
        try? await Task.sleep(nanoseconds: 100_000_000)
    }

    @Test("render writes a PNG and manifest entry")
    func renderWritesFiles() async throws {
        installKey()
        let dir = try TempStickerDir.fresh()
        StickerAppGroup.directoryOverride = dir
        defer {
            StickerAppGroup.directoryOverride = nil
            TempStickerDir.cleanUp(dir)
        }

        let ticket = sampleTicket()
        StickerRenderService.shared.render(ticket)
        await drain()

        let pngURL = dir.appendingPathComponent("\(ticket.id.uuidString).png")
        #expect(FileManager.default.fileExists(atPath: pngURL.path))

        let manifest = StickerManifest.load()
        #expect(manifest.entries.contains { $0.ticketId == ticket.id.uuidString })
    }

    @Test("delete removes PNG and manifest entry")
    func deleteRemovesFiles() async throws {
        installKey()
        let dir = try TempStickerDir.fresh()
        StickerAppGroup.directoryOverride = dir
        defer {
            StickerAppGroup.directoryOverride = nil
            TempStickerDir.cleanUp(dir)
        }

        let ticket = sampleTicket()
        StickerRenderService.shared.render(ticket)
        await drain()

        StickerRenderService.shared.delete(ticketId: ticket.id)
        await drain()

        let pngURL = dir.appendingPathComponent("\(ticket.id.uuidString).png")
        #expect(!FileManager.default.fileExists(atPath: pngURL.path))

        let manifest = StickerManifest.load()
        #expect(!manifest.entries.contains { $0.ticketId == ticket.id.uuidString })
    }

    @Test("reconcile prunes orphans and renders missing")
    func reconcilePrunes() async throws {
        installKey()
        let dir = try TempStickerDir.fresh()
        StickerAppGroup.directoryOverride = dir
        defer {
            StickerAppGroup.directoryOverride = nil
            TempStickerDir.cleanUp(dir)
        }

        // Seed manifest with a stale entry.
        let orphan = StickerManifest.Entry(
            ticketId: UUID().uuidString,
            filename: "orphan.png",
            createdAt: "2026-04-10T10:00:00Z",
            label: "Old"
        )
        // Also drop a fake file for the orphan to verify cleanup.
        let orphanFile = dir.appendingPathComponent("orphan.png")
        try Data("fake".utf8).write(to: orphanFile)
        try StickerManifest(version: 1, entries: [orphan]).save()

        let fresh = sampleTicket()
        StickerRenderService.shared.reconcile(with: [fresh])
        await drain()

        let manifest = StickerManifest.load()
        #expect(!manifest.entries.contains { $0.ticketId == orphan.ticketId })
        #expect(manifest.entries.contains { $0.ticketId == fresh.id.uuidString })
        #expect(!FileManager.default.fileExists(atPath: orphanFile.path))
    }
}
#endif
