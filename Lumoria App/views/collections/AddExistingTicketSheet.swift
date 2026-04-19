//
//  AddExistingTicketSheet.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1684-33028
//
//  Picker sheet for attaching an already-created ticket to a memory. Same
//  column layout as `AllTicketsView` — horizontal tickets span both
//  columns, vertical tickets pair up — but filtered to tickets that are
//  NOT already in this memory, and a tap commits the selection.
//

import SwiftUI

struct AddExistingTicketSheet: View {

    let memoryId: UUID

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var ticketsStore: TicketsStore
    /// ID of the ticket closest to vertical centre of the sheet. Drives
    /// the shimmer's `isActive` so only the focused card consumes motion.
    @State private var centredId: UUID?

    var body: some View {
        VStack(spacing: 0) {
            header

            if availableTickets.isEmpty {
                emptyState
            } else {
                ScrollView {
                    grid
                }
            }
        }
        .background(Color.Background.default)
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                LumoriaIconButton(systemImage: "xmark") { dismiss() }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Text("Select a ticket")
                .font(.largeTitle.bold())
                .foregroundStyle(Color.Text.primary)
                .padding(.horizontal, 24)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)

            Text("Nothing left to add")
                .font(.title2.bold())
                .foregroundStyle(Color.Text.tertiary)

            Text("Every ticket you've made is already in this memory.")
                .font(.body)
                .foregroundStyle(Color.Text.tertiary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }

    // MARK: - Grid

    private var grid: some View {
        VStack(spacing: 16) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                rowView(for: row)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 32)
    }

    @ViewBuilder
    private func rowView(for row: GridRow) -> some View {
        switch row {
        case .horizontal(let ticket):
            ticketTile(ticket)
        case .verticalPair(let a, let b):
            HStack(alignment: .top, spacing: 8) {
                ticketTile(a)
                ticketTile(b)
            }
        case .verticalSingle(let ticket):
            HStack(alignment: .top, spacing: 8) {
                ticketTile(ticket)
                Color.clear
            }
        }
    }

    private func ticketTile(_ ticket: Ticket) -> some View {
        Button {
            Task {
                await ticketsStore.toggleMembership(
                    ticketId: ticket.id,
                    memoryId: memoryId
                )
                dismiss()
            }
        } label: {
            TicketPreview(ticket: ticket, isCentered: centredId == ticket.id)
                .trackCenteredRow(id: ticket.id, into: $centredId)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Data

    /// Tickets not already in this memory — the picker should only show
    /// things the user can actually add.
    private var availableTickets: [Ticket] {
        ticketsStore.tickets.filter { !$0.memoryIds.contains(memoryId) }
    }

    // MARK: - Row partitioning (mirrors AllTicketsView)

    private enum GridRow {
        case horizontal(Ticket)
        case verticalPair(Ticket, Ticket)
        case verticalSingle(Ticket)
    }

    private var rows: [GridRow] {
        var out: [GridRow] = []
        var pending: Ticket?

        for ticket in availableTickets {
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

// MARK: - Preview

#if DEBUG
#Preview("Populated") {
    let ticketsStore = TicketsStore()
    ticketsStore.seedSamples()
    let memoriesStore = MemoriesStore()
    let sampleMemoryId = UUID()

    return AddExistingTicketSheet(memoryId: sampleMemoryId)
        .environmentObject(ticketsStore)
        .environmentObject(memoriesStore)
}

#Preview("Empty") {
    AddExistingTicketSheet(memoryId: UUID())
        .environmentObject(TicketsStore())
        .environmentObject(MemoriesStore())
}
#endif
