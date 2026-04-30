//
//  MemorySortApplierTests.swift
//  Lumoria AppTests
//
//  Pure-logic coverage for MemorySortApplier — no Supabase, no
//  EncryptionService. Drives every (field, direction) combination plus
//  nil bucketing + tie-breaking.
//

import Foundation
import Testing
@testable import Lumoria_App

@Suite("MemorySortApplier")
@MainActor
struct MemorySortApplierTests {

    private let memoryId = UUID()

    private func makeTicket(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        eventDate: Date? = nil,
        addedAt: Date? = nil
    ) -> Ticket {
        Ticket(
            id: id,
            createdAt: createdAt,
            updatedAt: createdAt,
            orientation: .horizontal,
            payload: .afterglow(AfterglowTicket(
                airline: "X",
                flightNumber: "1",
                origin: "AAA", originCity: "A",
                destination: "BBB", destinationCity: "B",
                date: "1 Jan 2026",
                gate: "1",
                seat: "1A",
                boardingTime: "08:00"
            )),
            memoryIds: [memoryId],
            eventDate: eventDate,
            addedAtByMemory: addedAt.map { [memoryId: $0] } ?? [:]
        )
    }

    @Test("sorts by date added ascending — oldest first")
    func sortsByDateAddedAsc() {
        let day = Date(timeIntervalSince1970: 0)
        let a = makeTicket(addedAt: day)
        let b = makeTicket(addedAt: day.addingTimeInterval(60))
        let c = makeTicket(addedAt: day.addingTimeInterval(120))
        let result = MemorySortApplier.apply(
            [c, a, b],
            field: .dateAdded,
            ascending: true,
            memoryId: memoryId
        )
        #expect(result.map(\.id) == [a.id, b.id, c.id])
    }

    @Test("sorts by date added descending — newest first")
    func sortsByDateAddedDesc() {
        let day = Date(timeIntervalSince1970: 0)
        let a = makeTicket(addedAt: day)
        let b = makeTicket(addedAt: day.addingTimeInterval(60))
        let result = MemorySortApplier.apply(
            [a, b],
            field: .dateAdded,
            ascending: false,
            memoryId: memoryId
        )
        #expect(result.map(\.id) == [b.id, a.id])
    }

    @Test("sorts by event date ascending")
    func sortsByEventDateAsc() {
        let day = Date(timeIntervalSince1970: 0)
        let a = makeTicket(eventDate: day)
        let b = makeTicket(eventDate: day.addingTimeInterval(60))
        let result = MemorySortApplier.apply(
            [b, a],
            field: .eventDate,
            ascending: true,
            memoryId: memoryId
        )
        #expect(result.map(\.id) == [a.id, b.id])
    }

    @Test("sorts by created date ascending")
    func sortsByCreatedAsc() {
        let day = Date(timeIntervalSince1970: 0)
        let a = makeTicket(createdAt: day)
        let b = makeTicket(createdAt: day.addingTimeInterval(60))
        let result = MemorySortApplier.apply(
            [b, a],
            field: .dateCreated,
            ascending: true,
            memoryId: memoryId
        )
        #expect(result.map(\.id) == [a.id, b.id])
    }

    @Test("buckets nil event dates last regardless of direction")
    func bucketsNilEventDatesLast() {
        let day = Date(timeIntervalSince1970: 0)
        let dated = makeTicket(eventDate: day)
        let undated = makeTicket(eventDate: nil)
        let asc = MemorySortApplier.apply(
            [undated, dated],
            field: .eventDate,
            ascending: true,
            memoryId: memoryId
        )
        let desc = MemorySortApplier.apply(
            [undated, dated],
            field: .eventDate,
            ascending: false,
            memoryId: memoryId
        )
        #expect(asc.map(\.id) == [dated.id, undated.id])
        #expect(desc.map(\.id) == [dated.id, undated.id])
    }

    @Test("ties break by ticket id for determinism")
    func tiesBreakByTicketId() {
        let day = Date(timeIntervalSince1970: 0)
        let lowId  = UUID(uuid: (0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,1))
        let highId = UUID(uuid: (0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,2))
        let a = makeTicket(id: lowId,  eventDate: day)
        let b = makeTicket(id: highId, eventDate: day)
        let result = MemorySortApplier.apply(
            [b, a],
            field: .eventDate,
            ascending: true,
            memoryId: memoryId
        )
        #expect(result.map(\.id) == [lowId, highId])
    }
}
