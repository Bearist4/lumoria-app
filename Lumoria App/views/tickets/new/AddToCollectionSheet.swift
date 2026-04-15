//
//  AddToCollectionSheet.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1166-83935
//
//  Bottom sheet surfaced from the success step. Lists the user's collections
//  as `CollectionCard`s; tapping one toggles the ticket's membership and
//  flashes a confirmation pill at the bottom.
//

import SwiftUI

struct AddToCollectionSheet: View {

    let ticket: Ticket

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var ticketsStore: TicketsStore
    @EnvironmentObject private var collections: CollectionsStore

    @State private var toastMessage: String? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 24),
        GridItem(.flexible(), spacing: 24),
    ]

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                if collections.collections.isEmpty {
                    emptyCopy
                        .padding(.horizontal, 24)
                        .padding(.top, 32)
                } else {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(collections.collections) { c in
                            Button {
                                Task { await toggle(c) }
                            } label: {
                                CollectionCard(
                                    title: c.name,
                                    subtitle: subtitle(for: c),
                                    state: isMember(of: c) ? .added : .normal,
                                    filledCount: isMember(of: c) ? 1 : 0,
                                    colorFamily: c.colorFamily
                                ) { _ in
                                    TicketPreview(ticket: currentTicket)
                                        .frame(width: 160)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .refreshable { await collections.load() }
        }
        .background(Color.Background.default)
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large])
        .lumoriaToast($toastMessage)
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Add to a collection")
                .font(.system(size: 17, weight: .semibold))
                .tracking(-0.43)
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
            Text("No collections yet")
                .font(.system(size: 22, weight: .bold))
                .tracking(-0.26)
                .foregroundStyle(Color.Text.tertiary)
            Text("Create a collection first, then come back to add this ticket.")
                .font(.system(size: 17, weight: .regular))
                .tracking(-0.43)
                .foregroundStyle(Color.Text.tertiary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Helpers

    /// Latest snapshot of the ticket (picks up any collection edits the store
    /// has applied since this sheet was presented).
    private var currentTicket: Ticket {
        ticketsStore.ticket(with: ticket.id) ?? ticket
    }

    private func isMember(of collection: Collection) -> Bool {
        currentTicket.collectionIds.contains(collection.id)
    }

    private func subtitle(for c: Collection) -> String {
        let count = ticketsStore.tickets(in: c.id).count
        return count == 1 ? "1 ticket" : "\(count) tickets"
    }

    private func toggle(_ c: Collection) async {
        let wasMember = isMember(of: c)
        await ticketsStore.toggleMembership(ticketId: ticket.id, collectionId: c.id)
        toastMessage = wasMember
            ? "Removed from \(c.name)"
            : "Ticket added to \(c.name)"
    }
}
