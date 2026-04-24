//
//  MemoriesView.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=948-12558
//

import SwiftUI

struct MemoriesView: View {

    @EnvironmentObject private var store: MemoriesStore
    @EnvironmentObject private var ticketsStore: TicketsStore
    @EnvironmentObject private var notificationsStore: NotificationsStore
    @EnvironmentObject private var pushService: PushNotificationService
    @EnvironmentObject private var onboardingCoordinator: OnboardingCoordinator
    @State private var showNewMemory = false
    @State private var showNotificationCenter = false
    @State private var pendingNotification: LumoriaNotification? = nil
    @State private var showNewTicketFunnel = false
    @State private var activeTemplateKind: TicketTemplateKind? = nil
    @State private var navigationPath = NavigationPath()

    private let columns = [
        GridItem(.flexible(), spacing: 24),
        GridItem(.flexible(), spacing: 24),
    ]

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                header

                if store.memories.isEmpty && !store.isLoading {
                    Spacer(minLength: 0)
                    emptyCopy
                        .padding(.horizontal, 40)
                    Spacer(minLength: 0)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 24) {
                            ForEach(store.memories) { m in
                                let tickets = ticketsStore.tickets(in: m.id)
                                NavigationLink(value: m) {
                                    MemoryCard(
                                        title: m.name,
                                        subtitle: tickets.count == 1 ? "1 ticket" : "\(tickets.count) tickets",
                                        state: .normal,
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
                                .contextMenu {
                                    Button(role: .destructive) {
                                        Task { await store.delete(m) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .onboardingAnchor(
                                    m.id == store.memories.first?.id
                                        ? "memories.newTile"
                                        : "unused.tile.\(m.id.uuidString)"
                                )
                            }

                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                    }
                    .refreshable {
                        await store.load()
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                }

                if let error = store.errorMessage {
                    errorBanner(error)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Memory.self) { m in
                MemoryDetailView(memory: m)
            }
            .task { await store.load() }
            .sheet(isPresented: $showNewMemory) {
                NewMemoryView { name, color, emoji, startDate, endDate in
                    guard let color else { return }
                    Task {
                        await store.create(
                            name: name,
                            colorFamily: color.family,
                            emoji: emoji,
                            startDate: startDate,
                            endDate: endDate
                        )
                    }
                }
            }
            .sheet(isPresented: $showNotificationCenter) {
                NotificationCenterView { notification in
                    pendingNotification = notification
                }
            }
            .fullScreenCover(isPresented: $showNewTicketFunnel) {
                NewTicketFunnelView()
                    .environmentObject(ticketsStore)
                    .environmentObject(onboardingCoordinator)
            }
            .sheet(item: $activeTemplateKind) { kind in
                TemplateDetailsSheet(kind: kind)
            }
            .onChange(of: showNotificationCenter) { _, isPresented in
                // Route the pending notification once the center dismisses
                // — presenting a new sheet/cover while another is still
                // on screen drops the new one.
                guard !isPresented, let notification = pendingNotification else { return }
                pendingNotification = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    route(notification)
                }
            }
            .onChange(of: pushService.pendingDeepLink) { _, link in
                guard let link else { return }
                pushService.pendingDeepLink = nil
                routePush(link)
            }
            .onChange(of: notificationsStore.unreadCount) { _, count in
                pushService.setBadgeCount(count)
            }
            .onboardingOverlay(
                step: .createMemory,
                coordinator: onboardingCoordinator,
                anchorID: "memories.plus",
                tip: OnboardingTipCopy(
                    title: "Create a memory",
                    body: "Memories gather tickets into one place. Create one by tapping the + button."
                )
            )
            .onboardingOverlay(
                step: .memoryCreated,
                coordinator: onboardingCoordinator,
                anchorID: "memories.newTile",
                tip: OnboardingTipCopy(
                    title: "Your memory has been created",
                    body: "Once you will have tickets added to this memory, they will appear on this tile. Tap this memory to open it."
                )
            )
        }
    }

    // MARK: - Notification routing

    private func route(_ notification: LumoriaNotification) {
        switch notification.kind {
        case .throwback:
            if let id = notification.memoryId,
               let memory = store.memories.first(where: { $0.id == id }) {
                navigationPath.append(memory)
            }
        case .onboarding:
            showNewTicketFunnel = true
        case .news:
            activeTemplateKind = notification.templateKind ?? .express
        case .link:
            showNewMemory = true
        }
    }

    /// Routes a push tap. Same semantics as `route()` but constructs
    /// the temporary LumoriaNotification from the push payload so the
    /// user doesn't need the full server row to be resident locally.
    private func routePush(_ link: PushNotificationService.DeepLink) {
        let temp = LumoriaNotification(
            id: link.notificationId ?? UUID(),
            kind: link.kind,
            title: "",
            message: "",
            createdAt: Date(),
            isRead: true,
            memoryId: link.memoryId,
            templateKind: link.templateKind
        )
        Task { await notificationsStore.load() }
        route(temp)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Text("Memories")
                .font(.largeTitle.bold())
                .foregroundStyle(Color.Text.primary)

            Spacer()

            HStack(spacing: 8) {
                LumoriaIconButton(
                    systemImage: "bell",
                    badgeCount: notificationsStore.unreadCount
                ) {
                    showNotificationCenter = true
                }
                LumoriaIconButton(systemImage: "plus") {
                    showNewMemory = true
                }
                .onboardingAnchor("memories.plus")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Empty copy

    private var emptyCopy: some View {
        VStack(spacing: 8) {
            Text("No memories yet")
                .font(.title2.bold())
                .foregroundStyle(Color.Text.tertiary)

            VStack(spacing: 0) {
                Text("Gather tickets by trip or theme.")

                HStack(spacing: 4) {
                    Text("Tap")
                    EmptyStateInlineBadge(systemImage: "plus")
                    Text("to start one.")
                }
            }
            .font(.body)
            .foregroundStyle(Color.Text.tertiary)
            .multilineTextAlignment(.center)
        }
    }

    // MARK: - Error banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.Feedback.Danger.icon)
            Text(message)
                .font(.footnote)
                .foregroundStyle(Color.Feedback.Danger.text)
                .lineLimit(2)
            Spacer(minLength: 0)
            Button {
                store.errorMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(Color.Feedback.Danger.text)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.Feedback.Danger.subtle)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

#Preview("Empty") {
    TabView {
        MemoriesView()
            .tabItem { Label("Memories", systemImage: "square.grid.2x2") }
    }
    .environmentObject(MemoriesStore())
    .environmentObject(TicketsStore())
    .environmentObject(NotificationsStore())
    .environmentObject(PushNotificationService.shared)
    .environmentObject(OnboardingCoordinator())
}

#Preview("Memories with 7 tickets") {
    let memoriesStore = MemoriesStore()
    let ticketsStore = TicketsStore()

    let summer = Memory(
        id: UUID(),
        userId: UUID(),
        name: "Summer 2026",
        colorFamily: "Orange",
        emoji: "🌴",
        createdAt: Date(),
        updatedAt: Date()
    )

    let japan = Memory(
        id: UUID(),
        userId: UUID(),
        name: "Japan 2026",
        colorFamily: "Pink",
        emoji: "🗾",
        createdAt: Date(),
        updatedAt: Date()
    )

    memoriesStore.seedForPreview([summer, japan])

    // 7 tickets per memory so each card renders its 5+ state with the
    // bottom-most slot clipped at the peek line. `sampleTickets` only
    // has 3 entries, so cycle them with fresh IDs.
    let samples = TicketsStore.sampleTickets
    func ticketsFor(_ memory: Memory) -> [Ticket] {
        (0..<3).map { i in
            let src = samples[i % samples.count]
            return Ticket(
                id: UUID(),
                createdAt: src.createdAt,
                updatedAt: src.updatedAt,
                orientation: src.orientation,
                payload: src.payload,
                memoryIds: [memory.id],
                originLocation: src.originLocation,
                destinationLocation: src.destinationLocation,
                styleId: src.styleId
            )
        }
    }
    ticketsStore.seedForPreview(ticketsFor(summer) + ticketsFor(japan))

    return TabView {
        MemoriesView()
            .tabItem { Label("Memories", systemImage: "square.grid.2x2") }
    }
    .environmentObject(memoriesStore)
    .environmentObject(ticketsStore)
    .environmentObject(NotificationsStore())
    .environmentObject(PushNotificationService.shared)
    .environmentObject(OnboardingCoordinator())
}
