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

    var body: some View {
        // iOS 18+ `Tab` API — renders the new liquid-glass floating
        // tab bar by default on iOS 26, letting each screen's content
        // run full-bleed behind the bar (matches the design specs).
        TabView {
            Tab("Memories", systemImage: "square.grid.2x2") {
                MemoriesView()
            }

            Tab("All tickets", systemImage: "ticket") {
                AllTicketsView()
            }

            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
        // Keep the tab bar in its expanded full-width state — it
        // otherwise minimizes to a compact pill on scroll.
        .tabBarMinimizeBehavior(.never)
        .environmentObject(ticketsStore)
        .environmentObject(memoriesStore)
        .environmentObject(profileStore)
        .environmentObject(notificationsStore)
        .task {
            await memoriesStore.load()
            await ticketsStore.load()
            await profileStore.load()
            await notificationsStore.load()
        }
    }
}

#Preview {
    ContentView()
}
