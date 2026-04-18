//
//  AllTicketsView.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=955-16025 (empty)
//          figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=955-14104 (populated)
//          figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1728-79133 (sort menu)
//          figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1728-79886 (sorted sections)
//
//  Gallery of the user's tickets. Horizontal templates span both grid
//  columns; vertical templates pair up in a 2-column layout. The sort
//  icon opens a contextual menu with date / category options; when a
//  sort is active tickets are rendered in grouped sections with a
//  relative-time or category header, and the icon gets a red badge dot.
//

import SwiftUI

// MARK: - Sort option

enum TicketSortOption {
    case date
    case category
}

struct AllTicketsView: View {

    @EnvironmentObject private var store: TicketsStore
    @State private var showFunnel = false
    @State private var sort: TicketSortOption? = nil

    var body: some View {
        NavigationStack {
            Group {
                if store.tickets.isEmpty {
                    VStack(spacing: 0) {
                        header
                        emptyState
                    }
                } else {
                    ScrollFadingBlurHeader(
                        fadeExtension: 0,
                        tintOpacityTop: 1.0,
                        tintOpacityMiddle: 1.0
                    ) {
                        header
                    } content: {
                        content
                    }
                    .refreshable {
                        await store.load()
                        Analytics.track(.galleryRefreshed(ticketCount: store.tickets.count))
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: sort) { _, newValue in
                let prop: GallerySortProp = {
                    switch newValue {
                    case .date:     return .date
                    case .category: return .category
                    case nil:       return GallerySortProp.none
                    }
                }()
                Analytics.track(.gallerySortApplied(sortType: prop))
            }
            .navigationDestination(for: Ticket.self) { ticket in
                TicketDetailView(ticket: ticket)
            }
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
                .font(.largeTitle.bold())
                .foregroundStyle(Color.Text.primary)

            Spacer()

            HStack(spacing: 8) {
                if !store.tickets.isEmpty {
                    LumoriaIconButton(
                        systemImage: "arrow.up.arrow.down",
                        showBadge: sort != nil,
                        menuItems: sortMenuItems
                    )
                }
                LumoriaIconButton(systemImage: "plus") { showFunnel = true }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 16)
        // Always-on solid backdrop so content scrolling behind the
        // title and icon buttons is fully covered, independent of
        // the progressive blur underneath (which only fades in on
        // scroll and lives in the fadeExtension region *below*
        // this header).
        .background(Color.Background.default.ignoresSafeArea(edges: .top))
        .zIndex(1)
    }

    private var sortMenuItems: [LumoriaMenuItem] {
        var items: [LumoriaMenuItem] = [
            .init(
                title: "Sort by date",
                isActive: sort == .date,
                action: { sort = .date }
            ),
            .init(
                title: "Sort by category",
                isActive: sort == .category,
                action: { sort = .category }
            ),
        ]
        if sort != nil {
            items.append(
                .init(
                    title: "Remove sorting",
                    kind: .destructive,
                    action: { sort = nil }
                )
            )
        }
        return items
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)

            Text("Your gallery starts here")
                .font(.title2.bold())
                .foregroundStyle(Color.Text.tertiary)

            HStack(spacing: 4) {
                Text("Tap")
                EmptyStateInlineBadge(systemImage: "plus")
                Text("to craft your first ticket.")
            }
            .font(.body)
            .foregroundStyle(Color.Text.tertiary)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }

    // MARK: - Content router

    @ViewBuilder
    private var content: some View {
        switch sort {
        case nil:
            grid(for: store.tickets)
        case .date?:
            groupedSections(
                groups: TicketGrouping.byDate(store.tickets, now: Date())
            )
        case .category?:
            groupedSections(
                groups: TicketGrouping.byCategory(store.tickets)
            )
        }
    }

    // MARK: - Populated grid

    private func grid(for tickets: [Ticket]) -> some View {
        VStack(spacing: 32) {
            ForEach(Array(rows(for: tickets).enumerated()), id: \.offset) { _, row in
                rowView(for: row)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    // MARK: - Grouped layout

    private func groupedSections(groups: [TicketGroup]) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(groups) { group in
                VStack(alignment: .leading, spacing: 16) {
                    Text(group.title)
                        .font(.title3.bold())
                        .foregroundStyle(Color.Text.primary)
                        .padding(.horizontal, 24)

                    VStack(spacing: 32) {
                        ForEach(Array(rows(for: group.tickets).enumerated()), id: \.offset) { _, row in
                            rowView(for: row)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
        .padding(.bottom, 24)
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

    /// Packs vertical tickets into side-by-side pairs regardless of
    /// horizontal tickets interleaved between them. Preserves each
    /// ticket's original creation order: the first vertical stays
    /// in place and pulls the next available vertical forward to
    /// pair with it. Horizontals keep their absolute position.
    private func rows(for tickets: [Ticket]) -> [GridRow] {
        var out: [GridRow] = []
        var remaining = tickets

        while !remaining.isEmpty {
            let first = remaining.removeFirst()
            switch first.orientation {
            case .horizontal:
                out.append(.horizontal(first))
            case .vertical:
                if let pairIdx = remaining.firstIndex(where: { $0.orientation == .vertical }) {
                    let partner = remaining.remove(at: pairIdx)
                    out.append(.verticalPair(first, partner))
                } else {
                    out.append(.verticalSingle(first))
                }
            }
        }
        return out
    }
}

// MARK: - Grouping model

struct TicketGroup: Identifiable {
    let id: String
    let title: LocalizedStringKey
    let tickets: [Ticket]
}

enum TicketGrouping {

    /// Groups by relative creation time: Today / This week / This month /
    /// This year / year label for older. Empty buckets are omitted. Groups
    /// list newest-first, tickets within a group list newest-first.
    static func byDate(_ tickets: [Ticket], now: Date) -> [TicketGroup] {
        let calendar = Calendar.current
        let sorted = tickets.sorted { $0.createdAt > $1.createdAt }

        var buckets: [(key: String, title: LocalizedStringKey, order: Int, tickets: [Ticket])] = []

        func appendTo(
            key: String,
            title: LocalizedStringKey,
            order: Int,
            ticket: Ticket
        ) {
            if let idx = buckets.firstIndex(where: { $0.key == key }) {
                buckets[idx].tickets.append(ticket)
            } else {
                buckets.append((key, title, order, [ticket]))
            }
        }

        for ticket in sorted {
            let date = ticket.createdAt
            if calendar.isDateInToday(date) {
                appendTo(key: "today", title: "Today", order: 0, ticket: ticket)
            } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
                appendTo(key: "week", title: "This week", order: 1, ticket: ticket)
            } else if calendar.isDate(date, equalTo: now, toGranularity: .month) {
                appendTo(key: "month", title: "This month", order: 2, ticket: ticket)
            } else if calendar.isDate(date, equalTo: now, toGranularity: .year) {
                appendTo(key: "year", title: "This year", order: 3, ticket: ticket)
            } else {
                let year = calendar.component(.year, from: date)
                // Negative order keeps older years after the relative
                // buckets while still sorting newer-year-first.
                appendTo(
                    key: "y-\(year)",
                    title: LocalizedStringKey("\(year)"),
                    order: 10_000 - year,
                    ticket: ticket
                )
            }
        }

        return buckets
            .sorted { $0.order < $1.order }
            .map { TicketGroup(id: $0.key, title: $0.title, tickets: $0.tickets) }
    }

    /// Groups by ticket category label (plane / train / …). Ordering
    /// mirrors first-occurrence in the source list so newly added
    /// categories appear where they naturally fall.
    static func byCategory(_ tickets: [Ticket]) -> [TicketGroup] {
        var buckets: [(key: String, tickets: [Ticket])] = []

        for ticket in tickets {
            let key = ticket.kind.categoryLabel
            if let idx = buckets.firstIndex(where: { $0.key == key }) {
                buckets[idx].tickets.append(ticket)
            } else {
                buckets.append((key, [ticket]))
            }
        }

        return buckets.map {
            TicketGroup(
                id: $0.key,
                title: LocalizedStringKey($0.key),
                tickets: $0.tickets
            )
        }
    }
}

// MARK: - Previews

#Preview("Empty") {
    AllTicketsView()
        .environmentObject(TicketsStore())
        .environmentObject(MemoriesStore())
}

#Preview("Populated") {
    let store = TicketsStore()
    store.seedSamples()
    return AllTicketsView()
        .environmentObject(store)
        .environmentObject(MemoriesStore())
}
