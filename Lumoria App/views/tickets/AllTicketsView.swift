//
//  AllTicketsView.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=955-16025 (empty)
//          figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=955-14104 (populated)
//
//  Gallery of the user's tickets. Horizontal templates span both grid
//  columns; vertical templates pair up in a 2-column layout.
//

import SwiftUI

struct AllTicketsView: View {

    @EnvironmentObject private var store: TicketsStore
    @State private var showFunnel = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header

                ScrollView {
                    if store.tickets.isEmpty {
                        emptyState
                    } else {
                        grid
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Ticket.self) { ticket in
                TicketDetailView(ticket: ticket)
            }
            .refreshable { await store.load() }
            .fullScreenCover(isPresented: $showFunnel) {
                NewTicketFunnelView()
                    .environmentObject(store)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Text("All tickets")
                .font(.system(size: 34, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(Color.Text.primary)

            Spacer()

            HStack(spacing: 8) {
                LumoriaIconButton(systemImage: "arrow.up.arrow.down", action: {})
                LumoriaIconButton(systemImage: "plus") { showFunnel = true }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 24) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.03))
                .frame(height: 215)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(
                            Color.Border.default,
                            style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                        )
                )

            VStack(alignment: .leading, spacing: 8) {
                Text("No tickets yet")
                    .font(.system(size: 22, weight: .bold))
                    .tracking(-0.26)
                    .foregroundStyle(Color.Text.tertiary)

                Text("Your ticket gallery is empty. Create your first one by tapping the + button in the top right.")
                    .font(.system(size: 17, weight: .regular))
                    .tracking(-0.43)
                    .foregroundStyle(Color.Text.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 32)
    }

    // MARK: - Populated grid

    private var grid: some View {
        VStack(spacing: 32) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                rowView(for: row)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
    }

    @ViewBuilder
    private func rowView(for row: GridRow) -> some View {
        switch row {
        case .horizontal(let ticket):
            ticketLink(ticket)
        case .verticalPair(let a, let b):
            HStack(alignment: .top, spacing: 16) {
                ticketLink(a)
                ticketLink(b)
            }
        case .verticalSingle(let ticket):
            HStack(alignment: .top, spacing: 16) {
                ticketLink(ticket)
                Color.clear
            }
        }
    }

    private func ticketLink(_ ticket: Ticket) -> some View {
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

    private var rows: [GridRow] {
        var out: [GridRow] = []
        var pending: Ticket?

        for ticket in store.tickets {
            switch ticket.orientation {
            case .horizontal:
                if let p = pending {
                    out.append(.verticalSingle(p))
                    pending = nil
                }
                out.append(.horizontal(ticket))
            case .vertical:
                if let p = pending {
                    out.append(.verticalPair(p, ticket))
                    pending = nil
                } else {
                    pending = ticket
                }
            }
        }
        if let p = pending { out.append(.verticalSingle(p)) }
        return out
    }
}

// MARK: - Previews

#Preview("Empty") {
    AllTicketsView()
        .environmentObject(TicketsStore())
        .environmentObject(CollectionsStore())
}

#Preview("Populated") {
    let store = TicketsStore()
    store.seedSamples()
    return AllTicketsView()
        .environmentObject(store)
        .environmentObject(CollectionsStore())
}
