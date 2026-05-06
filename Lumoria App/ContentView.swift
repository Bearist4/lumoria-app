//
//  ContentView.swift
//  Lumoria App
//
//  Root container for authenticated users. Hosts the main tab navigation
//  and owns the shared stores so ticket/memory counts stay in sync
//  across tabs.
//

import SwiftUI

struct ContentView: View {

    @StateObject private var ticketsStore = TicketsStore()
    @StateObject private var memoriesStore = MemoriesStore()
    @StateObject private var profileStore = ProfileStore()
    @StateObject private var notificationsStore = NotificationsStore()
    @StateObject private var sortPresenter = MemorySortPresenter()
    @StateObject private var colorPresenter = MemoryColorPresenter()
    @StateObject private var emojiPresenter = MemoryEmojiPresenter()
    @StateObject private var allTicketsSortPresenter = AllTicketsSortPresenter()
    @EnvironmentObject private var walletImport: WalletImportCoordinator
    @EnvironmentObject private var shareImport: ShareImportCoordinator
    @EnvironmentObject private var onboardingCoordinator: OnboardingCoordinator
    @EnvironmentObject private var widgetRouter: WidgetDeepLinkRouter
    @Environment(EntitlementStore.self) private var entitlement
    @Environment(Paywall.PresentationState.self) private var paywallState
    @Environment(InviteRewardCoordinator.self) private var inviteRewardCoordinator

    @State private var selectedTab: Int = 0
    /// Chained from `NoSlotsSheet` — when the user picks
    /// "Become an early adopter" we dismiss the paywall sheet, wait a
    /// beat for SwiftUI to settle, and then present the promo sheet.
    @State private var showEarlyAdopterPromoChained: Bool = false
    /// `.pkpass` bytes delivered via the share extension. When non-nil
    /// the funnel is presented over whatever tab the user is on, so the
    /// import flow doesn't depend on `AllTicketsView` being visible.
    @State private var pendingImportPassData: Data? = nil
    /// Parsed share-extension payload delivered via the App Group
    /// drain. Same presentation pattern as `pendingImportPassData`.
    @State private var pendingShareResult: ShareImportResult? = nil
    @EnvironmentObject private var authManager: AuthManager
    var body: some View {
        // iOS 18+ `Tab` API — renders the new liquid-glass floating
        // tab bar by default on iOS 26, letting each screen's content
        // run full-bleed behind the bar (matches the design specs).
        TabView(selection: $selectedTab) {
            Tab("Memories", systemImage: "square.grid.2x2", value: 0) {
                MemoriesView()
            }

            Tab("All tickets", systemImage: "ticket", value: 1) {
                AllTicketsView()
            }

            Tab("Settings", systemImage: "gearshape", value: 2) {
                SettingsView()
            }
        }
        // Keep the tab bar in its expanded full-width state — it
        // otherwise minimizes to a compact pill on scroll.
        .tabBarMinimizeBehavior(.never)
        .sensoryFeedback(.impact(weight: .light), trigger: selectedTab)
        .environmentObject(ticketsStore)
        .environmentObject(memoriesStore)
        .environmentObject(profileStore)
        .environmentObject(notificationsStore)
        .environmentObject(sortPresenter)
        .environmentObject(colorPresenter)
        .environmentObject(emojiPresenter)
        .environmentObject(allTicketsSortPresenter)
        .floatingBottomSheet(isPresented: $allTicketsSortPresenter.isPresented) {
            AllTicketsSortSheet(
                initialField: allTicketsSortPresenter.field,
                initialAscending: allTicketsSortPresenter.ascending,
                onCommit: { field, ascending in
                    allTicketsSortPresenter.commit(field: field, ascending: ascending)
                },
                onDismiss: { allTicketsSortPresenter.dismiss() }
            )
        }
        .floatingBottomSheet(isPresented: colorSheetBinding) {
            if let initial = colorPresenter.initialColor {
                MemoryColorPickerSheet(
                    initialColor: initial,
                    onCommit: { picked in
                        colorPresenter.onCommit?(picked)
                    },
                    onDismiss: { colorPresenter.dismiss() }
                )
            }
        }
        .floatingBottomSheet(isPresented: emojiSheetBinding) {
            EmojiPickerSheet(
                initialEmoji: emojiPresenter.initialEmoji,
                onCommit: { picked in
                    emojiPresenter.onCommit?(picked)
                },
                onDismiss: { emojiPresenter.dismiss() }
            )
        }
        .floatingBottomSheet(isPresented: sortSheetBinding) {
            if let id = sortPresenter.memoryId,
               let memory = memoriesStore.memories.first(where: { $0.id == id }) {
                MemorySortSheet(
                    initialField: memory.sortField,
                    initialAscending: memory.sortAscending,
                    onCommit: { field, ascending in
                        Task {
                            await memoriesStore.updateSort(
                                memoryId: memory.id,
                                field: field,
                                ascending: ascending
                            )
                            Analytics.track(.memorySortChanged(
                                field: field.rawValue,
                                ascending: ascending,
                                memoryIdHash: AnalyticsIdentity.hashUUID(memory.id)
                            ))
                        }
                    },
                    onDismiss: { sortPresenter.dismiss() }
                )
            }
        }
        .task {
            memoriesStore.onboardingCoordinator = onboardingCoordinator
            WidgetSnapshotWriter.shared.observe(
                memoriesStore: memoriesStore,
                ticketsStore: ticketsStore
            )
            WidgetSnapshotWriter.shared.refreshBrandLogomark()
            await memoriesStore.load()
            await ticketsStore.load()
            await profileStore.load()
            await notificationsStore.load()
            // Delay the welcome / resume sheet by 3 seconds so the user
            // lands on MemoriesView first, per spec.
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            onboardingCoordinator.maybePresentEntry()
        }
        .floatingBottomSheet(isPresented: $onboardingCoordinator.showWelcome) {
            WelcomeSheetView()
                .environmentObject(onboardingCoordinator)
        }
        .floatingBottomSheet(isPresented: $onboardingCoordinator.showResume) {
            ResumeSheetView()
                .environmentObject(onboardingCoordinator)
        }
        .floatingBottomSheet(isPresented: $onboardingCoordinator.showEndCover) {
            OnboardingEndSheetView()
                .environmentObject(onboardingCoordinator)
        }
        .alert(
            "Leave the tutorial?",
            isPresented: $onboardingCoordinator.showLeaveAlert
        ) {
            Button("Leave", role: .destructive) {
                Task { await onboardingCoordinator.confirmLeaveTutorial() }
            }
            Button("Stay", role: .cancel) {
                onboardingCoordinator.showLeaveAlert = false
            }
        } message: {
            Text("You can replay it anytime from Settings.")
        }
        .onChange(of: onboardingCoordinator.showWelcome) { _, isShowing in
            if isShowing { selectedTab = 0 }
        }
        .onChange(of: onboardingCoordinator.showResume) { _, isShowing in
            if isShowing { selectedTab = 0 }
        }
        .onChange(of: onboardingCoordinator.showEndCover) { _, isShowing in
            if isShowing { selectedTab = 0 }
        }
        .onChange(of: widgetRouter.pendingMemoryId) { _, id in
            if id != nil { selectedTab = 0 }
        }
        .onChange(of: walletImport.pending) { _, data in
            guard let data else { return }
            pendingImportPassData = data
            walletImport.pending = nil
        }
        .onChange(of: shareImport.pending) { _, result in
            guard let result else { return }
            pendingShareResult = result
            shareImport.pending = nil
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { pendingImportPassData != nil },
                set: { if !$0 { pendingImportPassData = nil } }
            )
        ) {
            // `.fullScreenCover` builds an isolated hierarchy — store
            // environment objects must be re-injected or the success
            // step's "Add to Memory" sheet and others crash on read.
            NewTicketFunnelView(
                initialImportSource: .wallet,
                initialPassData: pendingImportPassData
            )
            .environmentObject(ticketsStore)
            .environmentObject(memoriesStore)
            .environmentObject(profileStore)
            .environmentObject(notificationsStore)
            .environmentObject(onboardingCoordinator)
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { pendingShareResult != nil },
                set: { if !$0 { pendingShareResult = nil } }
            )
        ) {
            NewTicketFunnelView(
                initialImportSource: .share,
                initialShareImport: pendingShareResult,
                initialCategory: ShareImportTranslator.category(
                    from: pendingShareResult?.classification.category
                )
            )
            .environmentObject(ticketsStore)
            .environmentObject(memoriesStore)
            .environmentObject(profileStore)
            .environmentObject(notificationsStore)
            .environmentObject(onboardingCoordinator)
        }
        // Paywall router. Branches on (kPaymentsEnabled, trigger,
        // invite-redeemed) to pick between the StoreKit paywall, the
        // invite-bonus landing, and the early-adopter NoSlotsSheet for
        // users who've already redeemed their invite reward. Lives on
        // ContentView (not the App root) so the NoSlotsSheet can read
        // live ticket / memory counts and chain into
        // `EarlyAdopterPromoSheet`.
        .sheet(isPresented: Binding(
            get: { paywallState.isPresented },
            set: { paywallState.isPresented = $0 }
        )) {
            if let trigger = paywallState.trigger {
                paywallContent(for: trigger)
            }
        }
        .sheet(isPresented: $showEarlyAdopterPromoChained) {
            EarlyAdopterPromoSheet()
                .environment(entitlement)
        }
        // Invite-reward sheet (referrer + referree). Coordinator drives
        // presentation — see `InviteRewardCoordinator` for the trigger
        // matrix (onboarding done, first-ticket fallback, app launch,
        // live push / claim signal).
        .sheet(isPresented: inviteRewardSheetBinding) {
            inviteRewardSheetContent
        }
        .onChange(of: ticketsStore.tickets.count) { oldCount, newCount in
            // Invitee fallback: when the user creates their first
            // ticket OUTSIDE the onboarding flow, fire the reward
            // sheet 2 s after the success animation lands. The
            // coordinator no-ops if onboarding is active (that path
            // fires from the .done step transition below).
            guard oldCount == 0, newCount == 1 else { return }
            inviteRewardCoordinator.handleFirstTicketCreated(
                skipIfOnboardingActive: onboardingCoordinator.showOnboarding
            )
        }
        .onChange(of: onboardingCoordinator.currentStep) { oldStep, newStep in
            // Invitee primary path: tutorial wraps up, end-cover
            // dismisses, currentStep flips to .done — at which point
            // the user has already created their first ticket as
            // part of the onboarding. Re-evaluate so the reward
            // sheet pops over Memories.
            guard newStep == .done, oldStep != .done else { return }
            inviteRewardCoordinator.evaluateAfterOnboardingDone()
        }
        .modifier(NotificationSignalListeners(
            onInviteRewardSignal: {
                Task { await inviteRewardCoordinator.evaluate() }
            },
            onShowEarlyAdopterPromo: {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showEarlyAdopterPromoChained = true
                }
            }
        ))
    }

    @ViewBuilder
    private func paywallContent(for trigger: PaywallTrigger) -> some View {
        if EntitlementStore.kPaymentsEnabled {
            PaywallView(trigger: trigger, entitlement: entitlement)
        } else if trigger.isLimitReached, entitlement.inviteRewardKind != nil {
            // Invite already redeemed — invite-based bonus is exhausted.
            // Pitch the early-adopter seat instead.
            NoSlotsSheet(
                trigger: trigger,
                currentCount: currentCount(for: trigger),
                onBecomeEarlyAdopter: {
                    paywallState.isPresented = false
                    // Wait for the dismiss animation so SwiftUI doesn't
                    // drop the second sheet on top of an in-flight one.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showEarlyAdopterPromoChained = true
                    }
                }
            )
        } else {
            InviteLandingView(trigger: trigger)
        }
    }

    /// Live count of the resource the trigger refers to. Used by
    /// `NoSlotsSheet` to render "You have currently X tickets…".
    private func currentCount(for trigger: PaywallTrigger) -> Int {
        switch trigger.limitedResource {
        case .memories: return memoriesStore.memories.count
        case .tickets:  return ticketsStore.tickets.count
        case .none:     return 0
        }
    }

    /// Binding that maps the sort presenter's memoryId to a Bool the
    /// `.floatingBottomSheet` modifier can drive. Setting `false` clears
    /// the presenter so the sheet truly hides on swipe-/backdrop-dismiss
    /// flows in the future.
    private var sortSheetBinding: Binding<Bool> {
        Binding(
            get: { sortPresenter.memoryId != nil },
            set: { if !$0 { sortPresenter.dismiss() } }
        )
    }

    private var colorSheetBinding: Binding<Bool> {
        Binding(
            get: { colorPresenter.isPresented },
            set: { if !$0 { colorPresenter.dismiss() } }
        )
    }

    private var emojiSheetBinding: Binding<Bool> {
        Binding(
            get: { emojiPresenter.isPresented },
            set: { if !$0 { emojiPresenter.dismiss() } }
        )
    }

    private var inviteRewardSheetBinding: Binding<Bool> {
        Binding(
            get: { inviteRewardCoordinator.pending != nil },
            set: { if !$0 { inviteRewardCoordinator.dismiss() } }
        )
    }

    @ViewBuilder
    private var inviteRewardSheetContent: some View {
        if let role = inviteRewardCoordinator.pending {
            InviteRewardSheet(role: role) {
                inviteRewardCoordinator.consume()
            }
            .environment(entitlement)
        }
    }
}

/// Wraps the two NotificationCenter listeners ContentView relies on
/// — extracted as a ViewModifier so SwiftUI's body type-check stays
/// inside its budget. Both signals fire from outside the SwiftUI
/// tree (push handler, claim RPC, widget deep link).
private struct NotificationSignalListeners: ViewModifier {
    let onInviteRewardSignal: () -> Void
    let onShowEarlyAdopterPromo: () -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(
                NotificationCenter.default
                    .publisher(for: .lumoriaInviteRewardSignal)
            ) { _ in onInviteRewardSignal() }
            .onReceive(
                NotificationCenter.default
                    .publisher(for: .lumoriaShowEarlyAdopterPromo)
            ) { _ in onShowEarlyAdopterPromo() }
    }
}

#Preview {
    ContentView()
        .environmentObject(WalletImportCoordinator())
}
