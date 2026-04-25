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

    /// One or more tickets to add or remove as a group. Multi-leg
    /// underground journeys pass every persisted leg so picking a
    /// memory stores them all at once; all other templates pass a
    /// single ticket and the sheet behaves exactly as before.
    let tickets: [Ticket]

    /// Fired after the ticket(s) are added to a memory. Used by the
    /// success-step caller to dismiss the surrounding funnel and
    /// conclude the onboarding so the user lands back on Memories.
    let onCompleted: (() -> Void)?

    /// Convenience for the single-ticket callers (plane / train /
    /// concert) — keeps the old `AddToMemorySheet(ticket:)` call site
    /// working.
    init(ticket: Ticket, onCompleted: (() -> Void)? = nil) {
        self.tickets = [ticket]
        self.onCompleted = onCompleted
    }
    init(tickets: [Ticket], onCompleted: (() -> Void)? = nil) {
        self.tickets = tickets
        self.onCompleted = onCompleted
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var ticketsStore: TicketsStore
    @EnvironmentObject private var memories: MemoriesStore
    @EnvironmentObject private var onboardingCoordinator: OnboardingCoordinator

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
                    .onboardingAnchor("addToMemory.list")
                }
            }
            .refreshable { await memories.load() }
        }
        .background(Color.Background.default)
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large])
        .lumoriaToast($toastMessage)
        .onboardingOverlay(
            step: .exportOrAddMemory,
            coordinator: onboardingCoordinator,
            anchorID: "addToMemory.list",
            tip: OnboardingTipCopy(
                title: "Add to a memory",
                body: "Tap the memory you would like to add your ticket to. This can be changed later."
            )
        )
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

    /// Latest snapshots of the tracked tickets — picks up any memory
    /// edits the store has applied since the sheet was presented.
    private var currentTickets: [Ticket] {
        tickets.map { ticketsStore.ticket(with: $0.id) ?? $0 }
    }

    /// A memory is considered "member" when EVERY tracked ticket is
    /// in it. Mixed states fall back to non-member so the tap adds the
    /// missing ones instead of pulling everything out.
    private func isMember(of memory: Memory) -> Bool {
        currentTickets.allSatisfy { $0.memoryIds.contains(memory.id) }
    }

    /// Tickets already in the memory, with the current group pinned
    /// to the top when all its members are in. The card shows whatever
    /// is here as the deck — up to 5 get rendered.
    private func visibleTickets(in memory: Memory) -> [Ticket] {
        let existing = ticketsStore.tickets(in: memory.id)
        guard isMember(of: memory) else { return existing }
        let groupIds = Set(currentTickets.map(\.id))
        var ordered = existing.filter { !groupIds.contains($0.id) }
        ordered.insert(contentsOf: currentTickets, at: 0)
        return ordered
    }

    private func subtitle(for m: Memory) -> String {
        let count = ticketsStore.tickets(in: m.id).count
        return count == 1 ? "1 ticket" : "\(count) tickets"
    }

    /// Toggles every tracked ticket's membership as a group. If all
    /// were already members, removes the group; otherwise adds every
    /// ticket that wasn't in. Analytics fires one event summarising
    /// the batch rather than one per ticket.
    private func toggle(_ m: Memory) async {
        let wasFullMember = isMember(of: m)
        for t in currentTickets {
            let isIn = t.memoryIds.contains(m.id)
            if wasFullMember {
                // Remove every member.
                if isIn {
                    await ticketsStore.toggleMembership(ticketId: t.id, memoryId: m.id)
                }
            } else {
                // Add every non-member (leave existing members alone).
                if !isIn {
                    await ticketsStore.toggleMembership(ticketId: t.id, memoryId: m.id)
                }
            }
        }

        if wasFullMember {
            Analytics.track(.ticketRemovedFromMemory(
                memoryIdHash: AnalyticsIdentity.hashUUID(m.id)
            ))
            toastMessage = currentTickets.count == 1
                ? "Removed from \(m.name)"
                : "Removed \(currentTickets.count) tickets from \(m.name)"
        } else {
            let newCount = ticketsStore.tickets(in: m.id).count
            Analytics.track(.ticketAddedToMemory(
                memoryIdHash: AnalyticsIdentity.hashUUID(m.id),
                newTicketCount: newCount
            ))
            toastMessage = currentTickets.count == 1
                ? "Ticket added to \(m.name)"
                : "\(currentTickets.count) tickets added to \(m.name)"

            // Show the toast briefly so the user sees the confirmation,
            // then dismiss + hand control back to the caller (which
            // dismisses the funnel and concludes the onboarding).
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            onCompleted?()
            dismiss()
        }
    }
}
