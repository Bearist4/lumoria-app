//
//  TicketsStore.swift
//  Lumoria App
//
//  Loads / creates / deletes / updates the signed-in user's tickets, and
//  manages their membership in memories via the `memory_tickets`
//  junction table.
//

import Combine
import Foundation
import Supabase
import SwiftUI

@MainActor
final class TicketsStore: ObservableObject {

    @Published private(set) var tickets: [Ticket] = []
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // MARK: - Free-tier gate

    /// Whether the user can create another ticket under the free-tier
    /// cap. Premium / grandfathered / lifetime / active subscriber →
    /// always true. Mirrors the enforce_ticket_cap trigger.
    func canCreate(entitlement: EntitlementStore) -> Bool {
        if entitlement.hasPremium { return true }
        let cap = FreeCaps.ticketCap(rewardKind: entitlement.inviteRewardKind)
        return tickets.count < cap
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        defer { isLoading = false }

        // Ensure the session is restored before hitting PostgREST. The sync
        // `currentUser` accessor can be nil right after launch even when a
        // valid session is in the keychain.
        guard (try? await supabase.auth.session) != nil else {
            tickets = []
            return
        }

        do {
            let rows: [TicketRow] = try await supabase
                .from("tickets")
                .select("*, memory_tickets(memory_id, added_at, display_order)")
                .order("created_at", ascending: false)
                .execute()
                .value

            tickets = rows.compactMap { row in
                do { return try row.toTicket() }
                catch {
                    print("[TicketsStore] skipping row \(row.id):", error)
                    return nil
                }
            }
            errorMessage = nil
            StickerRenderService.shared.reconcile(with: tickets)
        } catch is CancellationError {
            // View dismissed mid-load — normal, don't surface.
        } catch let error as URLError where error.code == .cancelled {
            // URLSession cancellation — same treatment.
        } catch {
            errorMessage = String(localized: "Couldn’t load tickets. \(error.localizedDescription)")
            print("[TicketsStore] load failed:", error)
            Analytics.track(.appError(domain: .ticket, code: (error as NSError).code.description, viewContext: "TicketsStore.load"))
        }
    }

    // MARK: - Create

    @discardableResult
    func create(
        payload: TicketPayload,
        orientation: TicketOrientation,
        memoryIds: [UUID] = [],
        originLocation: TicketLocation? = nil,
        destinationLocation: TicketLocation? = nil,
        styleId: String? = nil,
        colorOverrides: [String: String]? = nil,
        eventDate: Date? = nil,
        groupId: UUID? = nil
    ) async -> Ticket? {

        let userId: UUID
        do {
            userId = try await supabase.auth.session.user.id
        } catch {
            errorMessage = String(localized: "You need to be signed in to save a ticket.")
            print("[TicketsStore] session fetch failed:", error)
            return nil
        }

        do {
            let json = try TicketCodec.encode(payload)
            let primaryEnc   = try originLocation.map { try TicketLocation.encrypt($0) }
            let secondaryEnc = try destinationLocation.map { try TicketLocation.encrypt($0) }
            let eventDateEnc = try eventDate.map { try MemoryDateCodec.encrypt($0) }
            let insert = NewTicketRow(
                userId: userId,
                templateKind: payload.kind.rawValue,
                orientation: orientation.rawValue,
                payload: json,
                locationPrimaryEnc: primaryEnc,
                locationSecondaryEnc: secondaryEnc,
                styleId: styleId,
                colorOverrides: (colorOverrides?.isEmpty ?? true) ? nil : colorOverrides,
                eventDateEnc: eventDateEnc,
                groupId: groupId
            )

            let row: TicketRow = try await supabase
                .from("tickets")
                .insert(insert)
                .select("*, memory_tickets(memory_id, added_at, display_order)")
                .single()
                .execute()
                .value

            var ticket = try row.toTicket()

            // Attach to memories, if any were specified.
            if !memoryIds.isEmpty {
                try await insertMemberships(
                    ticketId: ticket.id,
                    memoryIds: memoryIds
                )
                ticket.memoryIds = memoryIds
                // Best-effort local timestamp until next refetch — keeps
                // the new ticket sorting in the right bucket immediately
                // when "Date added" is selected.
                let now = Date()
                for id in memoryIds {
                    ticket.addedAtByMemory[id] = now
                }
            }

            tickets.insert(ticket, at: 0)
            errorMessage = nil
            StickerRenderService.shared.render(ticket)
            return ticket
        } catch {
            errorMessage = String(localized: "Couldn’t save ticket. \(error.localizedDescription)")
            print("[TicketsStore] create failed:", error)
            Analytics.track(.appError(domain: .ticket, code: (error as NSError).code.description, viewContext: "TicketsStore.create"))
            return nil
        }
    }

    // MARK: - Update

    /// Updates the ticket's payload / orientation. Does not touch membership —
    /// use `setMemories(for:to:)` for that.
    @discardableResult
    func update(_ ticket: Ticket) async -> Bool {
        do {
            let json = try TicketCodec.encode(ticket.payload)
            let primaryEnc   = try ticket.originLocation.map { try TicketLocation.encrypt($0) }
            let secondaryEnc = try ticket.destinationLocation.map { try TicketLocation.encrypt($0) }
            let eventDateEnc = try ticket.eventDate.map { try MemoryDateCodec.encrypt($0) }
            let patch = TicketUpdateRow(
                templateKind: ticket.kind.rawValue,
                orientation: ticket.orientation.rawValue,
                payload: json,
                locationPrimaryEnc: primaryEnc,
                locationSecondaryEnc: secondaryEnc,
                styleId: ticket.styleId,
                colorOverrides: (ticket.colorOverrides?.isEmpty ?? true) ? nil : ticket.colorOverrides,
                eventDateEnc: eventDateEnc,
                groupId: ticket.groupId
            )

            let updated: TicketRow = try await supabase
                .from("tickets")
                .update(patch)
                .eq("id", value: ticket.id.uuidString)
                .select("*, memory_tickets(memory_id, added_at, display_order)")
                .single()
                .execute()
                .value

            let rebuilt = try updated.toTicket()
            if let idx = tickets.firstIndex(where: { $0.id == ticket.id }) {
                tickets[idx] = rebuilt
            }
            errorMessage = nil
            StickerRenderService.shared.render(rebuilt)
            return true
        } catch {
            errorMessage = String(localized: "Couldn’t save changes. \(error.localizedDescription)")
            print("[TicketsStore] update failed:", error)
            Analytics.track(.appError(domain: .ticket, code: (error as NSError).code.description, viewContext: "TicketsStore.update"))
            return false
        }
    }

    // MARK: - Delete

    func delete(_ ticket: Ticket) async {
        do {
            try await supabase
                .from("tickets")
                .delete()
                .eq("id", value: ticket.id.uuidString)
                .execute()

            tickets.removeAll { $0.id == ticket.id }
            errorMessage = nil
            StickerRenderService.shared.delete(ticketId: ticket.id)
        } catch {
            errorMessage = String(localized: "Couldn’t delete ticket. \(error.localizedDescription)")
            print("[TicketsStore] delete failed:", error)
            Analytics.track(.appError(domain: .ticket, code: (error as NSError).code.description, viewContext: "TicketsStore.delete"))
        }
    }

    // MARK: - Memory membership

    /// Replaces the set of memories this ticket belongs to with the given
    /// `memoryIds`. Inserts any new links, removes any stale ones.
    func setMemories(
        for ticketId: UUID,
        to memoryIds: [UUID]
    ) async {
        guard let idx = tickets.firstIndex(where: { $0.id == ticketId }) else { return }

        let current = Set(tickets[idx].memoryIds)
        let desired = Set(memoryIds)
        let toAdd   = desired.subtracting(current)
        let toRemove = current.subtracting(desired)

        do {
            if !toAdd.isEmpty {
                try await insertMemberships(
                    ticketId: ticketId,
                    memoryIds: Array(toAdd)
                )
            }
            if !toRemove.isEmpty {
                try await supabase
                    .from("memory_tickets")
                    .delete()
                    .eq("ticket_id", value: ticketId.uuidString)
                    .in("memory_id", values: toRemove.map(\.uuidString))
                    .execute()
            }
            tickets[idx].memoryIds = memoryIds
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Couldn’t update memories. \(error.localizedDescription)")
            print("[TicketsStore] setMemories failed:", error)
            Analytics.track(.appError(domain: .memory, code: (error as NSError).code.description, viewContext: "TicketsStore.setMemories"))
        }
    }

    /// Adds or removes the ticket ↔ memory link, depending on current state.
    func toggleMembership(ticketId: UUID, memoryId: UUID) async {
        guard let idx = tickets.firstIndex(where: { $0.id == ticketId }) else { return }
        var ids = Set(tickets[idx].memoryIds)
        if ids.contains(memoryId) {
            ids.remove(memoryId)
        } else {
            ids.insert(memoryId)
        }
        await setMemories(for: ticketId, to: Array(ids))
    }

    // MARK: - Queries

    func ticket(with id: UUID) -> Ticket? {
        tickets.first { $0.id == id }
    }

    func tickets(in memoryId: UUID) -> [Ticket] {
        tickets.filter { $0.memoryIds.contains(memoryId) }
    }

    // MARK: - Optimistic helpers

    /// Sync local display-order update for tickets in a memory. Each
    /// ticket gets a 0-based index matching its position in
    /// `orderedIds`. Pair with `MemoriesStore.reorderTickets` to
    /// persist; this lets the reading view reflect the new order
    /// instantly while the network writes run in background.
    func applyLocalDisplayOrder(memoryId: UUID, orderedIds: [UUID]) {
        for (index, ticketId) in orderedIds.enumerated() {
            if let idx = tickets.firstIndex(where: { $0.id == ticketId }) {
                tickets[idx].displayOrderByMemory[memoryId] = index
            }
        }
    }

    // MARK: - Junction helper

    private func insertMemberships(
        ticketId: UUID,
        memoryIds: [UUID]
    ) async throws {
        let rows = memoryIds.map {
            MemoryTicketRow(memoryId: $0, ticketId: ticketId)
        }
        try await supabase
            .from("memory_tickets")
            .insert(rows)
            .execute()
    }
}

// MARK: - Sample data (previews only)

extension TicketsStore {

    /// Populates the in-memory `tickets` array with a spread of sample tickets
    /// across templates and orientations. Does NOT hit Supabase — safe to use
    /// in `#Preview` blocks where there's no authenticated user.
    func seedSamples() {
        tickets = TicketsStore.sampleTickets
    }

    /// Preview-only: seed first `count` sample tickets, each attached to
    /// `memoryId`. Does NOT hit Supabase.
    func seedSamples(in memoryId: UUID, count: Int) {
        tickets = Array(TicketsStore.sampleTickets.prefix(count)).map {
            var t = $0
            t.memoryIds = [memoryId]
            return t
        }
    }

    /// Preview-only — lets `#Preview` blocks drop a curated set of tickets
    /// into the store without going through Supabase.
    func seedForPreview(_ tickets: [Ticket]) {
        self.tickets = tickets
    }

    static let sampleTickets: [Ticket] = [
        Ticket(
            createdAt: date("2026-08-16"),
            updatedAt: date("2026-08-16"),
            orientation: .horizontal,
            payload: .prism(PrismTicket(
                airline: "Airline",
                ticketNumber: "Ticket number",
                date: "16 Aug 2026",
                origin: "SIN",
                originName: "Singapore Changi",
                destination: "HND",
                destinationName: "Tokyo Haneda",
                gate: "C34",
                seat: "11A",
                boardingTime: "08:40",
                departureTime: "09:10",
                terminal: "T3"
            ))
        ),
        Ticket(
            createdAt: date("2026-09-04"),
            updatedAt: date("2026-09-04"),
            orientation: .horizontal,
            payload: .heritage(HeritageTicket(
                airline: "Airline",
                ticketNumber: "Ticket number · Aircraft",
                cabinClass: "Class",
                cabinDetail: "Business · The Pier",
                origin: "HKG",
                originName: "Hong Kong International",
                originLocation: "Hong Kong",
                destination: "LHR",
                destinationName: "London Heathrow",
                destinationLocation: "London, United Kingdom",
                flightDuration: "9h 40m · Non-stop",
                gate: "42",
                seat: "11A",
                boardingTime: "22:10",
                departureTime: "22:55",
                date: "4 Sep",
                fullDate: "4 Sep 2026"
            ))
        ),
        Ticket(
            createdAt: date("2026-06-08"),
            updatedAt: date("2026-06-08"),
            orientation: .vertical,
            payload: .studio(StudioTicket(
                airline: "Airline",
                flightNumber: "FlightNumber",
                cabinClass: "Class",
                origin: "NRT",
                originName: "Narita International",
                originLocation: "Tokyo, Japan",
                destination: "JFK",
                destinationName: "John F. Kennedy",
                destinationLocation: "New York, United States",
                date: "8 Jun 2026",
                gate: "74",
                seat: "1K",
                departureTime: "11:05"
            ))
        ),
    ]

    private static func date(_ iso: String) -> Date {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone(identifier: "UTC")
        return df.date(from: iso) ?? Date()
    }
}
