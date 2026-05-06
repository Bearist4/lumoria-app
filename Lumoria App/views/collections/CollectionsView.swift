//
//  MemoriesView.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=948-12558
//

import ProgressiveBlurHeader
import SwiftUI

struct MemoriesView: View {

    @EnvironmentObject private var store: MemoriesStore
    @EnvironmentObject private var ticketsStore: TicketsStore
    @EnvironmentObject private var notificationsStore: NotificationsStore
    @EnvironmentObject private var pushService: PushNotificationService
    @EnvironmentObject private var onboardingCoordinator: OnboardingCoordinator
    @EnvironmentObject private var widgetRouter: WidgetDeepLinkRouter
    @Environment(EntitlementStore.self) private var entitlement
    @Environment(Paywall.PresentationState.self) private var paywallState
    @State private var showNewMemory = false
    @State private var showNotificationCenter = false
    @State private var pendingNotification: LumoriaNotification? = nil
    @State private var showNewTicketFunnel = false
    @State private var activeTemplateKind: TicketTemplateKind? = nil
    @State private var navigationPath = NavigationPath()
    /// Drives the per-tile locked alert. Set when the user taps a
    /// memory that's beyond the Free-tier cap (former early adopter).
    @State private var showLockedAlert: Bool = false
    /// Drives the early-adopter promo sheet route from the locked alert
    /// when the user has already claimed their invite reward and
    /// "Become an early adopter" is the only remaining unlock path.
    @State private var showEarlyAdopterPromo: Bool = false
    /// Once true, the first-load intro animation has played for this
    /// view instance — subsequent appearances render steady.
    @State private var hasIntroducedOnce = false

    private let columns = [
        GridItem(.flexible(), spacing: 24),
        GridItem(.flexible(), spacing: 24),
    ]

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if store.memories.isEmpty && !store.isLoading {
                    VStack(spacing: 0) {
                        header
                        Spacer(minLength: 0)
                        emptyCopy
                            .padding(.horizontal, 40)
                        Spacer(minLength: 0)
                        if let error = store.errorMessage {
                            errorBanner(error)
                        }
                    }
                } else {
                    // Match the memory-detail blur: always-on
                    // progressive 8pt blur with a 56pt fade extension
                    // and no white tint, so the header reads as a
                    // soft seam over scrolled cards.
                    StickyBlurHeader(
                        maxBlurRadius: 8,
                        fadeExtension: 56,
                        tintOpacityTop: 0,
                        tintOpacityMiddle: 0
                    ) {
                        header
                    } content: {
                        VStack(spacing: 0) {
                            LazyVGrid(columns: columns, spacing: 24) {
                                let lockedIds = lockedMemoryIds
                                ForEach(Array(store.memories.enumerated()), id: \.element.id) { idx, m in
                                    let tickets = ticketsStore.tickets(in: m.id)
                                    let isLocked = lockedIds.contains(m.id)
                                    NavigationLink(value: m) {
                                        MemoryCard(
                                            title: m.name,
                                            subtitle: tickets.count == 1 ? "1 ticket" : "\(tickets.count) tickets",
                                            state: .normal,
                                            emoji: m.emoji,
                                            filledCount: min(tickets.count, 5),
                                            colorFamily: m.colorFamily,
                                            cardSeed: UInt64(bitPattern: Int64(m.id.hashValue)),
                                            introDelay: hasIntroducedOnce ? nil : Double(idx) * 0.08
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
                                    .freeTierLocked(isLocked) { showLockedAlert = true }
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

                            if let error = store.errorMessage {
                                errorBanner(error)
                            }
                        }
                    }
                    .refreshable {
                        await store.load()
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(
                onboardingCoordinator.shouldHideTabBar ? .hidden : .visible,
                for: .tabBar
            )
            .navigationDestination(for: Memory.self) { m in
                MemoryDetailView(memory: m)
            }
            .task { await store.load() }
            .task(id: store.memories.isEmpty) {
                guard !store.memories.isEmpty, !hasIntroducedOnce else { return }
                // Cards have just rendered with their staggered
                // `introDelay` baked into MemoryCard's @State. Lock
                // the flag immediately — @State persists across
                // re-renders, so the in-flight animation completes
                // even when subsequent renders pass `introDelay: nil`.
                // Sleeping here would let a quick nav-and-return
                // (under the sleep duration) re-trigger the whole
                // staggered intro on each card, which is what made
                // the gallery feel laggy on returns.
                hasIntroducedOnce = true
            }
            .onChange(of: widgetRouter.pendingMemoryId, initial: true) { _, id in
                tryConsumePendingWidgetMemory(id: id)
            }
            .onChange(of: store.memories) { _, _ in
                tryConsumePendingWidgetMemory(id: widgetRouter.pendingMemoryId)
            }
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
            .sheet(isPresented: $showEarlyAdopterPromo) {
                EarlyAdopterPromoSheet()
                    .environment(entitlement)
            }
            .alert(
                "Memory locked",
                isPresented: $showLockedAlert
            ) {
                Button("Cancel", role: .cancel) { }
                if entitlement.inviteRewardKind == nil {
                    Button("Invite a friend") {
                        Paywall.present(
                            for: .memoryLimit,
                            entitlement: entitlement,
                            state: paywallState
                        )
                    }
                } else {
                    Button("Become an early adopter") {
                        showEarlyAdopterPromo = true
                    }
                }
            } message: {
                Text(lockedMemoryAlertMessage)
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
            .onChange(of: onboardingCoordinator.pendingResumeRoute) { _, route in
                guard let route else { return }
                onboardingCoordinator.pendingResumeRoute = nil
                // Resume sheet is still animating out; presenting a new
                // sheet/cover here would be dropped (same race as the
                // notification routing path below).
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    consumeResumeRoute(route)
                }
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

    // MARK: - Widget deep link

    /// Pushes the memory referenced by a widget tap onto the navigation
    /// stack. No-op until both the id and the loaded memory are present —
    /// caller invokes this from both `onChange` paths so cold launch (id
    /// arrives before store load) and warm tap (load already done) both
    /// land on detail. Resets path first so user always sees detail at
    /// the top, regardless of prior navigation state.
    private func tryConsumePendingWidgetMemory(id: UUID?) {
        guard let id,
              let memory = store.memories.first(where: { $0.id == id })
        else { return }
        navigationPath = NavigationPath()
        navigationPath.append(memory)
        widgetRouter.pendingMemoryId = nil
    }

    // MARK: - Onboarding resume routing

    /// Sends the user back to where the tutorial left off. Memory steps
    /// stay here on the root grid, so this only handles `.enterMemory`
    /// (push first memory) and the funnel-stage steps (present funnel).
    private func consumeResumeRoute(_ route: OnboardingResumeRoute) {
        switch route {
        case .openFirstMemory:
            guard let first = store.memories.first else { return }
            navigationPath.append(first)
        case .openNewTicketFunnel:
            presentNewTicketOrPaywall()
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
            presentNewTicketOrPaywall()
        case .news:
            activeTemplateKind = notification.templateKind ?? .express
        case .link:
            presentNewMemoryOrPaywall()
        }
    }

    /// IDs of memories locked under the current Free-tier cap. Empty
    /// for premium / grandfathered users (no caps fire) and for users
    /// who haven't exceeded the cap. Drives the lock affordance on
    /// each grid tile after a former early adopter revokes their seat.
    private var lockedMemoryIds: Set<UUID> {
        FreeCaps.lockedIDs(
            items: store.memories,
            cap: FreeCaps.memoryCap(rewardKind: entitlement.inviteRewardKind),
            isPremium: entitlement.tier.hasPremium,
            createdAt: \.createdAt
        )
    }

    /// Body copy for the per-tile locked alert. Branches on whether the
    /// user can still claim an invite reward — if they can, we point
    /// them at the invite flow; otherwise we surface the delete /
    /// early-adopter unlocks.
    private var lockedMemoryAlertMessage: String {
        let cap = FreeCaps.memoryCap(rewardKind: entitlement.inviteRewardKind)
        if entitlement.inviteRewardKind == nil {
            return String(localized: "You're at the Free tier limit of \(cap) memories. Invite a friend to unlock 1 more slot.")
        }
        return String(localized: "You're at the Free tier limit of \(cap) memories. Delete an older memory to free this one up, or become an early adopter for unlimited slots.")
    }

    /// Gated entry to the new-memory sheet. Free-tier users at the
    /// memory cap see the paywall instead.
    private func presentNewMemoryOrPaywall() {
        if store.canCreate(entitlement: entitlement) {
            showNewMemory = true
        } else {
            Paywall.present(
                for: .memoryLimit,
                entitlement: entitlement,
                state: paywallState
            )
        }
    }

    /// Gated entry to the new-ticket funnel. Free-tier users at the
    /// ticket cap see the paywall instead.
    private func presentNewTicketOrPaywall() {
        if ticketsStore.canCreate(entitlement: entitlement) {
            showNewTicketFunnel = true
        } else {
            Paywall.present(
                for: .ticketLimit,
                entitlement: entitlement,
                state: paywallState
            )
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
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Memories")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color.Text.primary)

                slotIndicator
            }

            Spacer()

            HStack(spacing: 8) {
                LumoriaIconButton(
                    systemImage: "bell",
                    badgeCount: notificationsStore.unreadCount
                ) {
                    showNotificationCenter = true
                }
                LumoriaIconButton(systemImage: "plus") {
                    presentNewMemoryOrPaywall()
                }
                .onboardingAnchor("memories.plus")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var slotIndicator: some View {
        // Tier-level hasPremium so we always show slots for free users,
        // even while the kill-switch is off (the kill-switch only
        // applies to premium-feature gates, not hard caps).
        if !entitlement.tier.hasPremium {
            let cap = FreeCaps.memoryCap(rewardKind: entitlement.inviteRewardKind)
            let remaining = max(0, cap - store.memories.count)
            if remaining == 0 {
                if entitlement.inviteRewardKind == nil {
                    // Invite still available — surface the +1 reward.
                    Button {
                        Paywall.present(
                            for: .memoryLimit,
                            entitlement: entitlement,
                            state: paywallState
                        )
                    } label: {
                        LumoriaUpgradeIncentive(resource: .memory)
                    }
                    .buttonStyle(.plain)
                } else {
                    // Invite already redeemed — mirror the warning
                    // subheadline used by AllTicketsView so the two
                    // gallery surfaces speak the same language at the
                    // hard cap.
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.Feedback.Warning.icon)
                        Text("No slots available")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.Feedback.Warning.text)
                    }
                }
            } else {
                Text("\(remaining) available slots")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.Text.tertiary)
            }
        }
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
