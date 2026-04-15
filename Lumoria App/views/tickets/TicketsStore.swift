//
//  TicketsStore.swift
//  Lumoria App
//
//  Loads / creates / deletes / updates the signed-in user's tickets, and
//  manages their membership in collections via the `collection_tickets`
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
                .select("*, collection_tickets(collection_id)")
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
        } catch is CancellationError {
            // View dismissed mid-load — normal, don't surface.
        } catch let error as URLError where error.code == .cancelled {
            // URLSession cancellation — same treatment.
        } catch {
            errorMessage = "Couldn’t load tickets. \(error.localizedDescription)"
            print("[TicketsStore] load failed:", error)
        }
    }

    // MARK: - Create

    @discardableResult
    func create(
        payload: TicketPayload,
        orientation: TicketOrientation,
        collectionIds: [UUID] = []
    ) async -> Ticket? {

        let userId: UUID
        do {
            userId = try await supabase.auth.session.user.id
        } catch {
            errorMessage = "You need to be signed in to save a ticket."
            print("[TicketsStore] session fetch failed:", error)
            return nil
        }

        do {
            let json = try TicketCodec.encode(payload)
            let insert = NewTicketRow(
                userId: userId,
                templateKind: payload.kind.rawValue,
                orientation: orientation.rawValue,
                payload: json
            )

            let row: TicketRow = try await supabase
                .from("tickets")
                .insert(insert)
                .select("*, collection_tickets(collection_id)")
                .single()
                .execute()
                .value

            var ticket = try row.toTicket()

            // Attach to collections, if any were specified.
            if !collectionIds.isEmpty {
                try await insertMemberships(
                    ticketId: ticket.id,
                    collectionIds: collectionIds
                )
                ticket.collectionIds = collectionIds
            }

            tickets.insert(ticket, at: 0)
            errorMessage = nil
            return ticket
        } catch {
            errorMessage = "Couldn’t save ticket. \(error.localizedDescription)"
            print("[TicketsStore] create failed:", error)
            return nil
        }
    }

    // MARK: - Update

    /// Updates the ticket's payload / orientation. Does not touch membership —
    /// use `setCollections(for:to:)` for that.
    @discardableResult
    func update(_ ticket: Ticket) async -> Bool {
        do {
            let json = try TicketCodec.encode(ticket.payload)
            let patch = TicketUpdateRow(
                templateKind: ticket.kind.rawValue,
                orientation: ticket.orientation.rawValue,
                payload: json
            )

            let updated: TicketRow = try await supabase
                .from("tickets")
                .update(patch)
                .eq("id", value: ticket.id.uuidString)
                .select("*, collection_tickets(collection_id)")
                .single()
                .execute()
                .value

            let rebuilt = try updated.toTicket()
            if let idx = tickets.firstIndex(where: { $0.id == ticket.id }) {
                tickets[idx] = rebuilt
            }
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Couldn’t save changes. \(error.localizedDescription)"
            print("[TicketsStore] update failed:", error)
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
        } catch {
            errorMessage = "Couldn’t delete ticket. \(error.localizedDescription)"
            print("[TicketsStore] delete failed:", error)
        }
    }

    // MARK: - Collection membership

    /// Replaces the set of collections this ticket belongs to with the given
    /// `collectionIds`. Inserts any new links, removes any stale ones.
    func setCollections(
        for ticketId: UUID,
        to collectionIds: [UUID]
    ) async {
        guard let idx = tickets.firstIndex(where: { $0.id == ticketId }) else { return }

        let current = Set(tickets[idx].collectionIds)
        let desired = Set(collectionIds)
        let toAdd   = desired.subtracting(current)
        let toRemove = current.subtracting(desired)

        do {
            if !toAdd.isEmpty {
                try await insertMemberships(
                    ticketId: ticketId,
                    collectionIds: Array(toAdd)
                )
            }
            if !toRemove.isEmpty {
                try await supabase
                    .from("collection_tickets")
                    .delete()
                    .eq("ticket_id", value: ticketId.uuidString)
                    .in("collection_id", values: toRemove.map(\.uuidString))
                    .execute()
            }
            tickets[idx].collectionIds = collectionIds
            errorMessage = nil
        } catch {
            errorMessage = "Couldn’t update collections. \(error.localizedDescription)"
            print("[TicketsStore] setCollections failed:", error)
        }
    }

    /// Adds or removes the ticket ↔ collection link, depending on current state.
    func toggleMembership(ticketId: UUID, collectionId: UUID) async {
        guard let idx = tickets.firstIndex(where: { $0.id == ticketId }) else { return }
        var ids = Set(tickets[idx].collectionIds)
        if ids.contains(collectionId) {
            ids.remove(collectionId)
        } else {
            ids.insert(collectionId)
        }
        await setCollections(for: ticketId, to: Array(ids))
    }

    // MARK: - Queries

    func ticket(with id: UUID) -> Ticket? {
        tickets.first { $0.id == id }
    }

    func tickets(in collectionId: UUID) -> [Ticket] {
        tickets.filter { $0.collectionIds.contains(collectionId) }
    }

    // MARK: - Junction helper

    private func insertMemberships(
        ticketId: UUID,
        collectionIds: [UUID]
    ) async throws {
        let rows = collectionIds.map {
            CollectionTicketRow(collectionId: $0, ticketId: ticketId)
        }
        try await supabase
            .from("collection_tickets")
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
    /// `collectionId`. Does NOT hit Supabase.
    func seedSamples(in collectionId: UUID, count: Int) {
        tickets = Array(TicketsStore.sampleTickets.prefix(count)).map {
            var t = $0
            t.collectionIds = [collectionId]
            return t
        }
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
