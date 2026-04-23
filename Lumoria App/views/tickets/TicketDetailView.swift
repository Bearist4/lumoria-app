//
//  TicketDetailView.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=955-14489
//
//  Shows a single ticket in full. The Memories section below the details
//  card is context-aware:
//
//  - No memories at all             → "Create memory…" menu, empty copy
//  - Memories exist, not in any     → "Create memory…" + "Add to…"
//  - Ticket is in ≥1 memory         → + "Remove from memory…"
//  - Remove mode active             → cards show a red remove badge;
//                                     tapping any card triggers a confirm
//                                     alert before detaching.
//

import SwiftUI
import ProgressiveBlurHeader

struct TicketDetailView: View {

    let ticket: Ticket
    var openedFromSource: TicketSourceProp = .gallery

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var ticketsStore: TicketsStore
    @EnvironmentObject private var memoriesStore: MemoriesStore
    @EnvironmentObject private var onboardingCoordinator: OnboardingCoordinator

    @State private var showNewMemory = false
    @State private var showAddToMemory = false
    @State private var inRemoveMode = false
    @State private var memoryPendingRemoval: Memory? = nil

    @State private var showExport = false
    @State private var showDeleteConfirm = false
    @State private var showEdit = false
    /// Bumped after the edit flow dismisses so the scroll container
    /// rebuilds with the refreshed store data. SwiftUI's `.id` change
    /// is the most reliable way to drop cached sub-view state.
    @State private var refreshToken: UUID = UUID()
    /// Gates the post-edit loader overlay.
    @State private var isReloading: Bool = false
    /// Populated by the edit funnel just before it dismisses. The
    /// presenter (this view) is responsible for running `store.update`
    /// + `store.load` so the loader is only shown once, outside the
    /// funnel.
    @State private var pendingEdit: Ticket? = nil

    var body: some View {
        // Scroll-fading blur so the header dim is invisible until the
        // user actually scrolls content behind it — avoids a
        // permanent dark band when opened as a sheet from the map.
        ScrollFadingBlurHeader(
            maxBlurRadius: 8,
            fadeExtension: 0,
            tintOpacityTop: 1.0,
            tintOpacityMiddle: 1.0
        ) {
            header
        } content: {
            VStack(alignment: .leading, spacing: 24) {
                TicketPreview(ticket: currentTicket, isCentered: true)
                    .padding(.horizontal, currentTicket.orientation == .horizontal ? 16 : 64)

                detailsCard
                    .padding(.horizontal, 16)
            }
            .padding(.vertical, 16)
            .id(refreshToken)
        }
        .blur(radius: isReloading ? 8 : 0)
        .allowsHitTesting(!isReloading)
        .overlay {
            if isReloading {
                LumoriaLoader()
                    .transition(.opacity)
            }
        }
        .animation(MotionTokens.editorial, value: isReloading)
        .background(Color.Background.default.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            Analytics.track(.ticketOpened(
                category: ticket.kind.analyticsCategory,
                template: ticket.kind.analyticsTemplate,
                source: openedFromSource
            ))
        }
        .sheet(isPresented: $showNewMemory) {
            NewMemoryView { name, color, emoji, startDate, endDate in
                guard let color else { return }
                Task {
                    await memoriesStore.create(
                        name: name,
                        colorFamily: color.family,
                        emoji: emoji,
                        startDate: startDate,
                        endDate: endDate
                    )
                }
            }
        }
        .sheet(isPresented: $showAddToMemory) {
            AddToMemorySheet(ticket: currentTicket)
        }
        .sheet(isPresented: $showExport) {
            ExportSheet(ticket: currentTicket)
        }
        .fullScreenCover(isPresented: $showEdit, onDismiss: {
            // Edit flow handoff: the funnel's Done button wrote the
            // prepared ticket to `pendingEdit` before dismissing. Run
            // the save + app-wide reload with the loader visible on the
            // detail view. Reloading both stores keeps upstream surfaces
            // (memories, gallery) in sync so popping back shows the
            // edited ticket everywhere, not just here.
            guard let updated = pendingEdit else { return }
            pendingEdit = nil
            isReloading = true
            Task {
                _ = await ticketsStore.update(updated)
                await ticketsStore.load()
                await memoriesStore.load()
                refreshToken = UUID()
                isReloading = false
            }
        }) {
            NewTicketFunnelView(
                initialTicket: currentTicket,
                pendingEdit: $pendingEdit
            )
            .environmentObject(ticketsStore)
            .environmentObject(onboardingCoordinator)
        }
        .alert(
            "Delete this ticket?",
            isPresented: $showDeleteConfirm
        ) {
            Button("Delete ticket", role: .destructive) {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                Task {
                    let wasInMemory = !currentTicket.memoryIds.isEmpty
                    await ticketsStore.delete(currentTicket)
                    Analytics.track(.ticketDeleted(
                        category: ticket.kind.analyticsCategory,
                        template: ticket.kind.analyticsTemplate,
                        wasInMemory: wasInMemory
                    ))
                    UIAccessibility.post(notification: .announcement, argument: String(localized: "Deleted."))
                    dismiss()
                }
            }
            Button("Keep ticket", role: .cancel) { }
        } message: {
            Text("This will permanently remove the ticket from your gallery and any memories it’s in. This can’t be undone.")
        }
        .alert(
            "Remove this ticket?",
            isPresented: Binding(
                get: { memoryPendingRemoval != nil },
                set: { if !$0 { memoryPendingRemoval = nil } }
            ),
            presenting: memoryPendingRemoval
        ) { memory in
            Button("Remove from memory", role: .destructive) {
                Task {
                    await ticketsStore.toggleMembership(
                        ticketId: currentTicket.id,
                        memoryId: memory.id
                    )
                    Analytics.track(.ticketRemovedFromMemory(
                        memoryIdHash: AnalyticsIdentity.hashUUID(memory.id)
                    ))
                    if associatedMemories.count <= 1 {
                        inRemoveMode = false
                    }
                }
            }
            Button("Keep in memory", role: .cancel) { }
        } message: { _ in
            Text("Remove this ticket from the memory? You can add it back later.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            LumoriaIconButton(systemImage: "chevron.left") { dismiss() }
            Spacer()
            LumoriaContextualMenuButton(items: headerMenuItems) {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .foregroundStyle(Color.Text.primary)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Color.Background.fieldFill))
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
                showEdit = true
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
        TicketDetailsCard(
            creationDate: Self.formatted(currentTicket.createdAt),
            lastEditDate: Self.formatted(currentTicket.updatedAt),
            category: currentTicket.kind.categoryStyle,
            location: currentTicket.originLocation,
            menuItems: memoriesMenuItems,
            memoriesContent: { memoriesBody }
        )
    }

    // MARK: - Memories section menu

    private var memoriesMenuItems: [LumoriaMenuItem] {
        var out: [LumoriaMenuItem] = [
            .init(title: "Create memory…") { showNewMemory = true },
        ]
        if !memoriesStore.memories.isEmpty {
            out.append(.init(title: "Add to a memory…") {
                showAddToMemory = true
            })
        }
        if !associatedMemories.isEmpty {
            out.append(.init(
                title: inRemoveMode ? "Done" : "Remove from memory…",
                kind: .destructive
            ) {
                inRemoveMode.toggle()
            })
        }
        return out
    }

    // MARK: - Memories body

    private let memoriesColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    @ViewBuilder
    private var memoriesBody: some View {
        if associatedMemories.isEmpty {
            Text(emptyCopy)
                .font(.subheadline)
                .foregroundStyle(Color.Text.secondary)
        } else {
            LazyVGrid(columns: memoriesColumns, spacing: 16) {
                ForEach(associatedMemories) { m in
                    let tickets = ticketsStore.tickets(in: m.id)
                    Button {
                        if inRemoveMode {
                            memoryPendingRemoval = m
                        }
                    } label: {
                        MemoryCard(
                            title: m.name,
                            subtitle: tickets.count == 1
                                ? String(localized: "1 ticket")
                                : String(localized: "\(tickets.count) tickets"),
                            state: inRemoveMode ? .removable : .normal,
                            emoji: m.emoji,
                            filledCount: min(tickets.count, 5),
                            colorFamily: m.colorFamily
                        ) { idx in
                            if idx < tickets.count {
                                MemoryCardSlot.frameForSlot(
                                    TicketPreview(ticket: tickets[idx]),
                                    orientation: tickets[idx].orientation
                                )
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

    // MARK: - Derived state

    /// Live snapshot of the ticket, so memory edits propagate without
    /// forcing the view to re-init.
    private var currentTicket: Ticket {
        ticketsStore.ticket(with: ticket.id) ?? ticket
    }

    private var associatedMemories: [Memory] {
        let ids = Set(currentTicket.memoryIds)
        return memoriesStore.memories.filter { ids.contains($0.id) }
    }

    private var emptyCopy: String {
        if memoriesStore.memories.isEmpty {
            return String(localized: "You have no memories yet. To create a memory, tap the + icon.")
        } else {
            return String(localized: "This ticket is not part of a memory. Memories help you group tickets by trip, event, or place.")
        }
    }

    // MARK: - Formatting

    /// Formats dates for the Created / Edited tiles. Goals:
    ///   - Stay compact. The tiles are narrow; long months like
    ///     "September" / "settembre" / "septiembre" push the year
    ///     to a second line.
    ///   - Stay locale-native. German/French/etc. readers see their
    ///     own month names; CJK users see a fully native `yyyy年M月d日`
    ///     style via `DateFormatter.longStyle`.
    ///
    /// For Latin-script locales we cap the month name at 4 characters,
    /// which is long enough to stay unambiguous (Apri / Sept / Dece)
    /// without overflowing the tile.
    private static func formatted(_ date: Date) -> String {
        let locale = Locale.current
        let lang = locale.language.languageCode?.identifier ?? "en"

        // CJK: let the system pick its fully-localized long format.
        if ["ko", "ja", "zh"].contains(lang) {
            let df = DateFormatter()
            df.locale = locale
            df.dateStyle = .long
            return df.string(from: date)
        }

        let monthFormatter = DateFormatter()
        monthFormatter.locale = locale
        monthFormatter.dateFormat = "MMM."
        var month = monthFormatter.string(from: date)
        if month.count > 4 {
            month = String(month.prefix(4))
        }

        let components = Calendar.current.dateComponents([.day, .year], from: date)
        let day = components.day ?? 0
        let year = components.year ?? 0
        return "\(day) \(month) \(year)"
    }
}

// MARK: - Preview

private enum TicketDetailPreview {

    /// Stock locations used in previews so the map card actually renders.
    static let sin = TicketLocation(
        name: "Singapore Changi", subtitle: "SIN",
        city: "Singapore", country: "Singapore", countryCode: "SG",
        lat: 1.3644, lng: 103.9915, kind: .airport
    )
    static let hnd = TicketLocation(
        name: "Tokyo Haneda", subtitle: "HND",
        city: "Tokyo", country: "Japan", countryCode: "JP",
        lat: 35.5494, lng: 139.7798, kind: .airport
    )
    static let hkg = TicketLocation(
        name: "Hong Kong", subtitle: "HKG",
        city: "Hong Kong", country: "Hong Kong", countryCode: "HK",
        lat: 22.3080, lng: 113.9185, kind: .airport
    )

    /// Builds a ticket + stores populated for a given preview flavor.
    @MainActor
    static func scenario(
        template index: Int = 0,
        origin: TicketLocation? = nil,
        destination: TicketLocation? = nil,
        memories: [Memory] = []
    ) -> (Ticket, TicketsStore, MemoriesStore) {
        var ticket = TicketsStore.sampleTickets[index]
        ticket.originLocation = origin
        ticket.destinationLocation = destination
        ticket.memoryIds = memories.map(\.id)

        let ticketsStore = TicketsStore()
        ticketsStore.seedForPreview([ticket])

        let memoriesStore = MemoriesStore()
        memoriesStore.seedForPreview(memories)

        return (ticket, ticketsStore, memoriesStore)
    }

    static func memory(name: String, color: String, emoji: String?) -> Memory {
        Memory(
            id: UUID(), userId: UUID(),
            name: name, colorFamily: color, emoji: emoji,
            createdAt: .now, updatedAt: .now
        )
    }
}

#Preview("Prism · both locations, 2 memories") {
    let japanTrip = TicketDetailPreview.memory(
        name: "Japan 2026", color: "Red", emoji: "🗾"
    )
    let asiaTour = TicketDetailPreview.memory(
        name: "Asia tour", color: "Blue", emoji: "✈️"
    )
    let (ticket, ticketsStore, memoriesStore) = TicketDetailPreview.scenario(
        template: 0,
        origin: TicketDetailPreview.sin,
        destination: TicketDetailPreview.hnd,
        memories: [japanTrip, asiaTour]
    )
    return NavigationStack {
        TicketDetailView(ticket: ticket)
            .environmentObject(ticketsStore)
            .environmentObject(memoriesStore)
    }
}

#Preview("Heritage · location only") {
    let (ticket, ticketsStore, memoriesStore) = TicketDetailPreview.scenario(
        template: 1,
        origin: TicketDetailPreview.hkg,
        destination: nil,
        memories: []
    )
    return NavigationStack {
        TicketDetailView(ticket: ticket)
            .environmentObject(ticketsStore)
            .environmentObject(memoriesStore)
    }
}

#Preview("Studio · no location, memories exist") {
    let weekendMemory = TicketDetailPreview.memory(
        name: "Weekend breaks", color: "Green", emoji: "🌿"
    )
    let (ticket, ticketsStore, memoriesStore) = TicketDetailPreview.scenario(
        template: 2,
        origin: nil,
        destination: nil,
        memories: [weekendMemory] // exists in store, ticket not in it
    )
    return NavigationStack {
        TicketDetailView(ticket: ticket)
            .environmentObject(ticketsStore)
            .environmentObject(memoriesStore)
    }
}

#Preview("Prism · bare (no location, no memories)") {
    let (ticket, ticketsStore, memoriesStore) = TicketDetailPreview.scenario(
        template: 0
    )
    return NavigationStack {
        TicketDetailView(ticket: ticket)
            .environmentObject(ticketsStore)
            .environmentObject(memoriesStore)
    }
}
