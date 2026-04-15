//
//  CollectionDetailView.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1166-42715
//

import SwiftUI
import ProgressiveBlurHeader

struct CollectionDetailView: View {

    let collection: Collection

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var ticketsStore: TicketsStore
    @EnvironmentObject private var collectionsStore: CollectionsStore

    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var previewColorFamily: String?

    var body: some View {
        ZStack(alignment: .top) {
            tintBackground
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.35), value: activeColorFamily)

            StickyBlurHeader(
                maxBlurRadius: 8,
                fadeExtension: 56,
                tintOpacityTop: 0,
                tintOpacityMiddle: 0
            ) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
            } content: {
                VStack(alignment: .leading, spacing: 0) {
                    title
                        .padding(.horizontal, 16)
                        .padding(.top, 56)
                        .padding(.bottom, 56)

                    contentCard
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: Ticket.self) { ticket in
            TicketDetailView(ticket: ticket)
        }
        .sheet(isPresented: $showEdit, onDismiss: {
            previewColorFamily = nil
        }) {
            EditCollectionView(
                collection: currentCollection,
                previewColorFamily: $previewColorFamily
            )
            .environmentObject(collectionsStore)
        }
        .alert(
            "Delete this collection?",
            isPresented: $showDeleteConfirm
        ) {
            Button("Delete collection", role: .destructive) {
                Task {
                    await collectionsStore.delete(currentCollection)
                    dismiss()
                }
            }
            Button("Keep it", role: .cancel) { }
        } message: {
            Text("Tickets in this collection will not be deleted. This action can’t be undone.")
        }
    }

    // MARK: - Derived

    /// Latest copy from the store so edits propagate without re-init.
    private var currentCollection: Collection {
        collectionsStore.collections.first(where: { $0.id == collection.id }) ?? collection
    }

    private var menuItems: [LumoriaMenuItem] {
        [
            .init(title: "Edit") { showEdit = true },
            .init(title: "Delete", kind: .destructive) { showDeleteConfirm = true },
        ]
    }

    // MARK: - Background

    private var activeColorFamily: String {
        previewColorFamily ?? currentCollection.colorFamily
    }

    private var tintBackground: Color {
        Color("Colors/\(activeColorFamily)/50")
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 8) {
            LumoriaIconButton(
                systemImage: "chevron.left",
                position: .onSurface
            ) {
                dismiss()
            }

            Spacer(minLength: 0)

            LumoriaIconButton(
                systemImage: "plus",
                position: .onSurface
            ) {
                // TODO: new ticket in this collection
            }

            LumoriaContextualMenuButton(items: menuItems) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(.white))
            }
        }
    }

    // MARK: - Title

    private var title: some View {
        HStack {
            Text(collection.name)
                .font(.system(size: 34, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(Color.Text.OnColor.black)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Content card

    @ViewBuilder
    private var contentCard: some View {
        let tickets = ticketsStore.tickets(in: collection.id)

        VStack(alignment: .leading, spacing: 0) {
            if tickets.isEmpty {
                emptyBody
            } else {
                ticketsGrid(tickets)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(minHeight: UIScreen.main.bounds.height * 0.75, alignment: .topLeading)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 32,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 32,
                style: .continuous
            )
            .fill(Color.Background.default)
        )
    }

    // MARK: - Empty state

    private var emptyBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            emptyTicketPlaceholder

            VStack(alignment: .leading, spacing: 8) {
                Text("No tickets yet")
                    .font(.system(size: 22, weight: .bold))
                    .tracking(-0.26)
                    .foregroundStyle(Color.Text.tertiary)

                Text("This collection is empty. Add a ticket from the + button or the gallery to start building it up.")
                    .font(.system(size: 17, weight: .regular))
                    .tracking(-0.43)
                    .foregroundStyle(Color.Text.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
    }

    private var emptyTicketPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.03))

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    Color.Border.default,
                    style: StrokeStyle(lineWidth: 3, dash: [6])
                )
        }
        .frame(height: 215)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Grid

    @ViewBuilder
    private func ticketsGrid(_ tickets: [Ticket]) -> some View {
        VStack(spacing: 32) {
            ForEach(Array(rows(for: tickets).enumerated()), id: \.offset) { _, row in
                switch row {
                case .horizontal(let t):
                    link(t)
                case .verticalPair(let a, let b):
                    HStack(alignment: .top, spacing: 16) {
                        link(a); link(b)
                    }
                case .verticalSingle(let t):
                    HStack(alignment: .top, spacing: 16) {
                        link(t); Color.clear
                    }
                }
            }
        }
    }

    private func link(_ ticket: Ticket) -> some View {
        NavigationLink(value: ticket) {
            TicketPreview(ticket: ticket)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Row partitioning

    private enum GridRow {
        case horizontal(Ticket)
        case verticalPair(Ticket, Ticket)
        case verticalSingle(Ticket)
    }

    private func rows(for tickets: [Ticket]) -> [GridRow] {
        var out: [GridRow] = []
        var pending: Ticket?
        for t in tickets {
            switch t.orientation {
            case .horizontal:
                if let p = pending { out.append(.verticalSingle(p)); pending = nil }
                out.append(.horizontal(t))
            case .vertical:
                if let p = pending { out.append(.verticalPair(p, t)); pending = nil }
                else { pending = t }
            }
        }
        if let p = pending { out.append(.verticalSingle(p)) }
        return out
    }
}

// MARK: - Preview

private let previewCollection = Collection(
    id: UUID(),
    userId: UUID(),
    name: "Japan 2026",
    colorFamily: "Red",
    locationName: nil,
    locationLat: nil,
    locationLng: nil,
    createdAt: .now,
    updatedAt: .now
)

#Preview("Empty") {
    NavigationStack {
        CollectionDetailView(collection: previewCollection)
            .environmentObject(TicketsStore())
            .environmentObject(CollectionsStore())
    }
}

#Preview("5 tickets") {
    let store: TicketsStore = {
        let s = TicketsStore()
        s.seedSamples(in: previewCollection.id, count: 5)
        return s
    }()
    return NavigationStack {
        CollectionDetailView(collection: previewCollection)
            .environmentObject(store)
            .environmentObject(CollectionsStore())
    }
}
