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
    @EnvironmentObject private var walletImport: WalletImportCoordinator
    @EnvironmentObject private var onboardingCoordinator: OnboardingCoordinator
    @EnvironmentObject private var widgetRouter: WidgetDeepLinkRouter

    @State private var selectedTab: Int = 0
    /// `.pkpass` bytes delivered via the share extension. When non-nil
    /// the funnel is presented over whatever tab the user is on, so the
    /// import flow doesn't depend on `AllTicketsView` being visible.
    @State private var pendingImportPassData: Data? = nil
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
}

#Preview {
    ContentView()
        .environmentObject(WalletImportCoordinator())
}
