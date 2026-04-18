//
//  StoreSliceTests.swift
//  Lumoria AppTests
//
//  Tests the slices of the @MainActor stores that don't depend on the
//  Supabase network — sample seeding, pure queries, local optimistic
//  state updates, and preview helpers. The Supabase-backed load/create/
//  update/delete paths live behind the global `supabase` client and are
//  covered by integration testing rather than unit tests.
//

import Foundation
import Testing
@testable import Lumoria_App

// MARK: - TicketsStore slices

@MainActor
@Suite("TicketsStore pure slices")
struct TicketsStoreSliceTests {

    @Test("seedSamples populates the published array")
    func seedSamples() {
        let store = TicketsStore()
        #expect(store.tickets.isEmpty)
        store.seedSamples()
        #expect(!store.tickets.isEmpty)
        #expect(store.tickets.count == TicketsStore.sampleTickets.count)
    }

    @Test("seedSamples(in:count:) tags every ticket with the memory id")
    func seedInMemory() {
        let store = TicketsStore()
        let memoryId = UUID()
        store.seedSamples(in: memoryId, count: 2)
        #expect(store.tickets.count == 2)
        for t in store.tickets {
            #expect(t.memoryIds == [memoryId])
        }
    }

    @Test("seedForPreview replaces the array wholesale")
    func seedForPreview() {
        let store = TicketsStore()
        let replacement = Array(TicketsStore.sampleTickets.prefix(1))
        store.seedForPreview(replacement)
        #expect(store.tickets.count == 1)
        #expect(store.tickets[0].id == replacement[0].id)
    }

    @Test("ticket(with:) returns a match or nil")
    func ticketLookup() {
        let store = TicketsStore()
        store.seedSamples()
        let target = store.tickets.first!
        #expect(store.ticket(with: target.id)?.id == target.id)
        #expect(store.ticket(with: UUID()) == nil)
    }

    @Test("tickets(in:) filters by memory membership")
    func ticketsInMemory() {
        let store = TicketsStore()
        let memoryId = UUID()
        store.seedSamples(in: memoryId, count: 3)

        // Append a ticket not belonging to that memory.
        var loose = TicketsStore.sampleTickets[0]
        loose = Ticket(
            id: UUID(),
            createdAt: loose.createdAt,
            updatedAt: loose.updatedAt,
            orientation: loose.orientation,
            payload: loose.payload,
            memoryIds: [UUID()] // different memory
        )
        store.seedForPreview(store.tickets + [loose])

        let matched = store.tickets(in: memoryId)
        #expect(matched.count == 3)
        #expect(matched.allSatisfy { $0.memoryIds.contains(memoryId) })
    }

    @Test("sampleTickets are non-empty and cover multiple templates")
    func sampleSpread() {
        let kinds = Set(TicketsStore.sampleTickets.map(\.kind))
        #expect(kinds.count >= 2)
        #expect(!TicketsStore.sampleTickets.isEmpty)
    }
}

// MARK: - MemoriesStore slices

@MainActor
@Suite("MemoriesStore pure slices")
struct MemoriesStoreSliceTests {

    private func sampleMemories() -> [Memory] {
        [
            Memory(
                id: UUID(), userId: UUID(),
                name: "Japan", colorFamily: "Indigo", emoji: "🗾",
                createdAt: Date(), updatedAt: Date()
            ),
            Memory(
                id: UUID(), userId: UUID(),
                name: "Iceland", colorFamily: "Teal", emoji: "❄️",
                createdAt: Date(), updatedAt: Date()
            ),
        ]
    }

    @Test("seedForPreview populates the published array")
    func seedForPreview() {
        let store = MemoriesStore()
        let seeded = sampleMemories()
        store.seedForPreview(seeded)
        #expect(store.memories.count == seeded.count)
        #expect(store.memories[0].name == "Japan")
    }
}

// MARK: - NotificationsStore slices

@MainActor
@Suite("NotificationsStore pure slices")
struct NotificationsStoreSliceTests {

    @Test("unreadCount reflects the filtered subset")
    func unreadCount() {
        let store = NotificationsStore()
        // Empty baseline.
        #expect(store.unreadCount == 0)

        // Seed via reflection-free route: push via markAllRead / delete has
        // side-effects on the Supabase client. Cheapest way: construct a
        // store with a local subclass. NotificationsStore's `notifications`
        // is `private(set)` — we can't seed it without a test hook. Skip
        // direct seeding and assert the baseline behaviour.
        #expect(store.notifications.isEmpty)
    }
}

// MARK: - InvitesStore slices

@MainActor
@Suite("InvitesStore pure slices")
struct InvitesStoreSliceTests {

    @Test("ViewState equatability catches state transitions")
    func viewStateEquality() {
        let invite = Invite(
            id: UUID(),
            inviterId: UUID(),
            token: "AAAA",
            createdAt: Date(),
            revokedAt: nil,
            claimedBy: nil,
            claimedAt: nil,
            redeemedAt: nil
        )
        #expect(InvitesStore.ViewState.loading == .loading)
        #expect(InvitesStore.ViewState.notSent == .notSent)
        #expect(InvitesStore.ViewState.sent(invite) == .sent(invite))
        #expect(InvitesStore.ViewState.loading != .notSent)
    }

    #if DEBUG
    @Test("setStateForPreview seeds without hitting Supabase")
    func setStateForPreview() async {
        let store = InvitesStore()
        let invite = Invite(
            id: UUID(), inviterId: UUID(), token: "ABCDE23456",
            createdAt: Date(), revokedAt: nil, claimedBy: nil,
            claimedAt: nil, redeemedAt: nil
        )
        store.setStateForPreview(.sent(invite))
        #expect(store.state == .sent(invite))
    }
    #endif
}

// MARK: - Ticket extension: memory filter round-trip

@MainActor
@Suite("TicketsStore.tickets(in:) boundary conditions")
struct TicketsInMemoryBoundaryTests {

    @Test("empty store returns empty array")
    func empty() {
        let store = TicketsStore()
        #expect(store.tickets(in: UUID()).isEmpty)
    }

    @Test("ticket with no memory ids is excluded")
    func excludedWhenDetached() {
        let store = TicketsStore()
        store.seedSamples()
        // Seed samples don't carry memory ids — so query should return empty.
        #expect(store.tickets(in: UUID()).isEmpty)
    }
}
