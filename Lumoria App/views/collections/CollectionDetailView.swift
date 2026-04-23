//
//  MemoryDetailView.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1166-42715
//

import SwiftUI
import ProgressiveBlurHeader
import TipKit

struct MemoryDetailView: View {

    let memory: Memory

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var ticketsStore: TicketsStore
    @EnvironmentObject private var memoriesStore: MemoriesStore
    @EnvironmentObject private var onboardingCoordinator: OnboardingCoordinator

    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var showMap = false
    @State private var showNewTicket = false
    @State private var showAddExistingTicket = false
    @State private var previewColorFamily: String?
    /// ID of the ticket closest to vertical centre of the screen. Drives
    /// the shimmer's `isActive` so only the focused card consumes motion.
    @State private var centredId: UUID?

    var body: some View {
        ZStack(alignment: .top) {
            // Base surface is the app default (white). Scroll-view
            // overscroll at the bottom reveals this directly — no
            // tinted bleed behind the bouncing card.
            Color.Background.default
                .ignoresSafeArea()

            // Tint is pinned to the top of the screen (not the scroll
            // content), so the title area keeps its colour even while
            // scrolling. Height is generous enough to cover the safe
            // area + top bar + title; any extra length is hidden by
            // the content card that overlays it from its rounded top
            // downward.
            tintBackground
                .frame(height: 420)
                .frame(maxWidth: .infinity, alignment: .top)
                .ignoresSafeArea(edges: [.top, .horizontal])
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
                        .padding(.horizontal, 24)
                        .padding(.top, 64)
                        .padding(.bottom, 64)

                    contentCard
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            Analytics.track(.memoryOpened(
                source: .memory,
                ticketCount: ticketsStore.tickets(in: memory.id).count,
                memoryIdHash: AnalyticsIdentity.hashUUID(memory.id)
            ))
        }
        .navigationDestination(for: Ticket.self) { ticket in
            TicketDetailView(ticket: ticket)
        }
        .sheet(isPresented: $showEdit, onDismiss: {
            previewColorFamily = nil
        }) {
            EditMemoryView(
                memory: currentMemory,
                previewColorFamily: $previewColorFamily
            )
            .environmentObject(memoriesStore)
        }
        .fullScreenCover(isPresented: $showNewTicket) {
            NewTicketFunnelView()
                .environmentObject(ticketsStore)
                .environmentObject(memoriesStore)
                .environmentObject(onboardingCoordinator)
        }
        .sheet(isPresented: $showAddExistingTicket) {
            AddExistingTicketSheet(memoryId: memory.id)
                .environmentObject(ticketsStore)
        }
        .alert(
            "Delete this memory?",
            isPresented: $showDeleteConfirm
        ) {
            Button("Delete memory", role: .destructive) {
                Task {
                    await memoriesStore.delete(currentMemory)
                    dismiss()
                }
            }
            Button("Keep memory", role: .cancel) { }
        } message: {
            Text("Tickets stay in your gallery. Can’t be undone.")
        }
        .fullScreenCover(isPresented: $showMap) {
            MemoryMapView(
                memory: currentMemory,
                tickets: ticketsStore.tickets(in: memory.id)
            )
        }
    }

    // MARK: - Map availability

    /// Any ticket in this memory with at least one attached location.
    private var hasAnyLocation: Bool {
        ticketsStore.tickets(in: memory.id).contains {
            $0.originLocation != nil || $0.destinationLocation != nil
        }
    }

    // MARK: - Derived

    /// Latest copy from the store so edits propagate without re-init.
    private var currentMemory: Memory {
        memoriesStore.memories.first(where: { $0.id == memory.id }) ?? memory
    }

    private var menuItems: [LumoriaMenuItem] {
        [
            .init(title: "Add existing ticket…") {
                showAddExistingTicket = true
            },
            .init(title: "Edit") { showEdit = true },
            .init(title: "Delete", kind: .destructive) { showDeleteConfirm = true },
        ]
    }

    // MARK: - Background

    private var activeColorFamily: String {
        previewColorFamily ?? currentMemory.colorFamily
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
                systemImage: "map",
                position: .onSurface
            ) {
                showMap = true
            }
            .disabled(!hasAnyLocation)
            .opacity(hasAnyLocation ? 1 : 0.5)

            LumoriaIconButton(
                systemImage: "plus",
                position: .onSurface
            ) {
                showNewTicket = true
            }

            LumoriaIconButton(
                systemImage: "ellipsis",
                position: .onSurface,
                menuItems: menuItems
            )
            .popoverTip(TicketTip())
        }
    }

    // MARK: - Title

    private var title: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let emoji = currentMemory.emoji, !emoji.isEmpty {
                Text(emoji)
                    .font(.system(size: 48, weight: .bold))
            }

            Text(currentMemory.name)
                .font(.title.bold())
                .lineSpacing(6)
                .foregroundStyle(Color.Text.OnColor.black)
                .lineLimit(2)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Content card

    @ViewBuilder
    private var contentCard: some View {
        let tickets = ticketsStore.tickets(in: memory.id)

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
        VStack(spacing: 8) {
            Text("This memory is empty. Add a ticket to begin.")
                .font(.title2.bold())
                .foregroundStyle(Color.Text.tertiary)
                .multilineTextAlignment(.center)

            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    Text("Add a ticket, or craft a new one in the")
                }
                HStack(spacing: 4) {
                    EmptyStateInlineBadge(systemImage: "ellipsis")
                    Text("menu.")
                }
            }
            .font(.body)
            .foregroundStyle(Color.Text.tertiary)
            .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
        .padding(.top, 48)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
            TicketPreview(ticket: ticket, isCentered: centredId == ticket.id)
                .trackCenteredRow(id: ticket.id, into: $centredId)
                .ticketInspect()
        }
        .buttonStyle(TicketCardButtonStyle())
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

private let previewMemory = Memory(
    id: UUID(),
    userId: UUID(),
    name: "Japan 2026",
    colorFamily: "Red",
    emoji: "🗾",
    createdAt: .now,
    updatedAt: .now
)

#Preview("Empty") {
    NavigationStack {
        MemoryDetailView(memory: previewMemory)
            .environmentObject(TicketsStore())
            .environmentObject(MemoriesStore())
    }
}

#Preview("5 tickets") {
    let store: TicketsStore = {
        let s = TicketsStore()
        s.seedSamples(in: previewMemory.id, count: 5)
        return s
    }()
    return NavigationStack {
        MemoryDetailView(memory: previewMemory)
            .environmentObject(store)
            .environmentObject(MemoriesStore())
    }
}
