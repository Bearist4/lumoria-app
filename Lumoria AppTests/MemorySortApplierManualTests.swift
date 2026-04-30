//
//  MemorySortApplierManualTests.swift
//  Lumoria AppTests
//
//  Manual-sort coverage for MemorySortApplier — orders by per-memory
//  displayOrder, buckets nils last regardless of direction.
//

import Foundation
import Testing
@testable import Lumoria_App

@Suite("MemorySortApplier — manual")
@MainActor
struct MemorySortApplierManualTests {

    private let memoryId = UUID()

    private func makeTicket(id: UUID = UUID(), order: Int? = nil) -> Ticket {
        Ticket(
            id: id,
            createdAt: Date(),
            updatedAt: Date(),
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
            displayOrderByMemory: order.map { [memoryId: $0] } ?? [:]
        )
    }

    @Test("manual ascending — orders by displayOrder")
    func manualAsc() {
        let a = makeTicket(order: 0)
        let b = makeTicket(order: 1)
        let c = makeTicket(order: 2)
        let result = MemorySortApplier.apply(
            [c, a, b],
            field: .manual,
            ascending: true,
            memoryId: memoryId
        )
        #expect(result.map(\.id) == [a.id, b.id, c.id])
    }

    @Test("manual buckets nil orders last regardless of direction")
    func manualBucketsNilLast() {
        let ordered = makeTicket(order: 0)
        let unordered = makeTicket(order: nil)
        let asc = MemorySortApplier.apply(
            [unordered, ordered],
            field: .manual,
            ascending: true,
            memoryId: memoryId
        )
        let desc = MemorySortApplier.apply(
            [unordered, ordered],
            field: .manual,
            ascending: false,
            memoryId: memoryId
        )
        #expect(asc.map(\.id) == [ordered.id, unordered.id])
        #expect(desc.map(\.id) == [ordered.id, unordered.id])
    }
}
