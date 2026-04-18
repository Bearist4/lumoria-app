//
//  AddToMemorySheet.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1166-83935
//
//  Bottom sheet surfaced from the success step. Lists the user's memories
//  as `MemoryCard`s; tapping one toggles the ticket's membership and
//  flashes a confirmation pill at the bottom.
//

import SwiftUI

struct AddToMemorySheet: View {

    let ticket: Ticket

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var ticketsStore: TicketsStore
    @EnvironmentObject private var memories: MemoriesStore

    @State private var toastMessage: String? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 24),
        GridItem(.flexible(), spacing: 24),
    ]

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                if memories.memories.isEmpty {
                    emptyCopy
                        .padding(.horizontal, 24)
                        .padding(.top, 32)
                } else {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(memories.memories) { m in
                            let tickets = visibleTickets(in: m)
                            Button {
                                Task { await toggle(m) }
                            } label: {
                                MemoryCard(
                                    title: m.name,
                                    subtitle: subtitle(for: m),
                                    state: isMember(of: m) ? .added : .normal,
                                    emoji: m.emoji,
                                    filledCount: min(tickets.count, 5),
                                    colorFamily: m.colorFamily
                                ) { index in
                                    if index < tickets.count {
                                        MemoryCardSlot.frameForSlot(
                                            TicketPreview(ticket: tickets[index]),
                                            orientation: tickets[index].orientation
                                        )
                                    } else {
                                        Color.clear
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .refreshable { await memories.load() }
        }
        .background(Color.Background.default)
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large])
        .lumoriaToast($toastMessage)
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Add to a memory")
                .font(.headline)
                .foregroundStyle(Color.Text.primary)

            HStack {
                LumoriaIconButton(systemImage: "xmark") { dismiss() }
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    // MARK: - Empty

    private var emptyCopy: some View {
        VStack(spacing: 8) {
            Text("No memories yet")
                .font(.title2.bold())
                .foregroundStyle(Color.Text.tertiary)
            Text("Create a memory first, then come back to add this ticket.")
                .font(.body)
                .foregroundStyle(Color.Text.tertiary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Helpers

    /// Latest snapshot of the ticket (picks up any memory edits the store
    /// has applied since this sheet was presented).
    private var currentTicket: Ticket {
        ticketsStore.ticket(with: ticket.id) ?? ticket
    }

    private func isMember(of memory: Memory) -> Bool {
        currentTicket.memoryIds.contains(memory.id)
    }

    /// Tickets already in the memory, with the currently-being-added
    /// ticket pinned to the top when it's a member. The card shows
    /// whatever is here as the deck — up to 5 get rendered.
    private func visibleTickets(in memory: Memory) -> [Ticket] {
        let existing = ticketsStore.tickets(in: memory.id)
        guard isMember(of: memory) else { return existing }
        var ordered = existing.filter { $0.id != currentTicket.id }
        ordered.insert(currentTicket, at: 0)
        return ordered
    }

    private func subtitle(for m: Memory) -> String {
        let count = ticketsStore.tickets(in: m.id).count
        return count == 1 ? "1 ticket" : "\(count) tickets"
    }

    private func toggle(_ m: Memory) async {
        let wasMember = isMember(of: m)
        await ticketsStore.toggleMembership(ticketId: ticket.id, memoryId: m.id)
        if wasMember {
            Analytics.track(.ticketRemovedFromMemory(
                memoryIdHash: AnalyticsIdentity.hashUUID(m.id)
            ))
        } else {
            let newCount = ticketsStore.tickets(in: m.id).count
            Analytics.track(.ticketAddedToMemory(
                memoryIdHash: AnalyticsIdentity.hashUUID(m.id),
                newTicketCount: newCount
            ))
        }
        toastMessage = wasMember
            ? "Removed from \(m.name)"
            : "Ticket added to \(m.name)"
    }
}
