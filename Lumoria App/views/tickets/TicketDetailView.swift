//
//  TicketDetailView.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=955-14489
//
//  Shows a single ticket in full. The Collections section below the details
//  card is context-aware:
//
//  - No collections at all             → "Create collection…" menu, empty copy
//  - Collections exist, not in any     → "Create collection…" + "Add to…"
//  - Ticket is in ≥1 collection        → + "Remove from collection…"
//  - Remove mode active                → cards show a red remove badge;
//                                        tapping any card triggers a confirm
//                                        alert before detaching.
//

import SwiftUI
import ProgressiveBlurHeader

struct TicketDetailView: View {

    let ticket: Ticket

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var ticketsStore: TicketsStore
    @EnvironmentObject private var collectionsStore: CollectionsStore

    @State private var showNewCollection = false
    @State private var showAddToCollection = false
    @State private var inRemoveMode = false
    @State private var collectionPendingRemoval: Collection? = nil

    @State private var showExport = false
    @State private var showDeleteConfirm = false

    var body: some View {
        StickyBlurHeader(maxBlurRadius: 8, fadeExtension: 48) {
            header
        } content: {
            VStack(alignment: .leading, spacing: 24) {
                TicketPreview(ticket: currentTicket)
                    .padding(.horizontal, currentTicket.orientation == .horizontal ? 16 : 64)

                detailsCard
                    .padding(.horizontal, 16)
            }
            .padding(.vertical, 16)
        }
        .background(Color.Background.default.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showNewCollection) {
            NewCollectionView { name, color, location in
                guard let color else { return }
                Task {
                    await collectionsStore.create(
                        name: name,
                        colorFamily: color.family,
                        location: location
                    )
                }
            }
        }
        .sheet(isPresented: $showAddToCollection) {
            AddToCollectionSheet(ticket: currentTicket)
        }
        .sheet(isPresented: $showExport) {
            ExportSheet(ticket: currentTicket)
        }
        .alert(
            "Delete this ticket?",
            isPresented: $showDeleteConfirm
        ) {
            Button("Delete ticket", role: .destructive) {
                Task {
                    await ticketsStore.delete(currentTicket)
                    dismiss()
                }
            }
            Button("Keep it", role: .cancel) { }
        } message: {
            Text("This will permanently remove the ticket from your gallery and any collections it's in. This can't be undone.")
        }
        .alert(
            "Remove this ticket?",
            isPresented: Binding(
                get: { collectionPendingRemoval != nil },
                set: { if !$0 { collectionPendingRemoval = nil } }
            ),
            presenting: collectionPendingRemoval
        ) { collection in
            Button("Remove from collection", role: .destructive) {
                Task {
                    await ticketsStore.toggleMembership(
                        ticketId: currentTicket.id,
                        collectionId: collection.id
                    )
                    if associatedCollections.count <= 1 {
                        inRemoveMode = false
                    }
                }
            }
            Button("Leave it in collection", role: .cancel) { }
        } message: { _ in
            Text("You are going to remove this ticket from your collection. You can always add it back later. Do you want to proceed?")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            LumoriaIconButton(systemImage: "chevron.left") { dismiss() }
            Spacer()
            LumoriaContextualMenuButton(items: headerMenuItems) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.Text.primary)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Color.black.opacity(0.05)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Header menu

    private var headerMenuItems: [LumoriaMenuItem] {
        [
            .init(title: "Edit") {
                // TODO: route to edit flow
            },
            .init(title: "Export…") {
                showExport = true
            },
            .init(title: "Delete ticket…", kind: .destructive) {
                showDeleteConfirm = true
            },
        ]
    }

    // MARK: - Details card

    @ViewBuilder
    private var detailsCard: some View {
        let items: [TicketDetailsCardItem] = [
            .init(label: "Creation",  sublabel: Self.formatted(currentTicket.createdAt)),
            .init(label: "Last edit", sublabel: Self.formatted(currentTicket.updatedAt)),
            .init(label: "✈︎",       sublabel: currentTicket.kind.categoryLabel, fullWidth: true),
        ]

        TicketDetailsCard(
            items: items,
            menuItems: collectionsMenuItems,
            collectionsContent: { collectionsBody }
        )
    }

    // MARK: - Collections section menu

    private var collectionsMenuItems: [LumoriaMenuItem] {
        var out: [LumoriaMenuItem] = [
            .init(title: "Create collection…") { showNewCollection = true },
        ]
        if !collectionsStore.collections.isEmpty {
            out.append(.init(title: "Add to a collection…") {
                showAddToCollection = true
            })
        }
        if !associatedCollections.isEmpty {
            out.append(.init(
                title: inRemoveMode ? "Done" : "Remove from collection…",
                kind: .destructive
            ) {
                inRemoveMode.toggle()
            })
        }
        return out
    }

    // MARK: - Collections body

    @ViewBuilder
    private var collectionsBody: some View {
        if associatedCollections.isEmpty {
            Text(emptyCopy)
                .font(.system(size: 15, weight: .regular))
                .tracking(-0.23)
                .foregroundStyle(Color.Text.secondary)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(associatedCollections) { c in
                        let tickets = ticketsStore.tickets(in: c.id)
                        Button {
                            if inRemoveMode {
                                collectionPendingRemoval = c
                            }
                        } label: {
                            CollectionCard(
                                title: c.name,
                                subtitle: tickets.count == 1 ? "1 ticket" : "\(tickets.count) tickets",
                                state: inRemoveMode ? .removable : .normal,
                                filledCount: min(tickets.count, 5),
                                colorFamily: c.colorFamily
                            ) { idx in
                                if idx < tickets.count {
                                    TicketPreview(ticket: tickets[idx])
                                        .frame(width: 160)
                                } else {
                                    EmptyView()
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Derived state

    /// Live snapshot of the ticket, so collection edits propagate without
    /// forcing the view to re-init.
    private var currentTicket: Ticket {
        ticketsStore.ticket(with: ticket.id) ?? ticket
    }

    private var associatedCollections: [Collection] {
        let ids = Set(currentTicket.collectionIds)
        return collectionsStore.collections.filter { ids.contains($0.id) }
    }

    private var emptyCopy: String {
        if collectionsStore.collections.isEmpty {
            return "You have no collection yet. To create a collection, tap the + icon."
        } else {
            return "This ticket is not part of a collection. Collections help organize your tickets in a way that makes sense to you."
        }
    }

    // MARK: - Formatting

    private static func formatted(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "dd MMMM yyyy"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df.string(from: date)
    }
}

// MARK: - Preview

#Preview("Prism horizontal") {
    let tickets: TicketsStore = {
        let s = TicketsStore()
        s.seedSamples()
        return s
    }()
    return NavigationStack {
        TicketDetailView(ticket: TicketsStore.sampleTickets[0])
            .environmentObject(tickets)
            .environmentObject(CollectionsStore())
    }
}
