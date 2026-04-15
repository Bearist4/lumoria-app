//
//  ContentView.swift
//  Lumoria App
//
//  Root container for authenticated users. Hosts the main tab navigation
//  and owns the shared stores so ticket/collection counts stay in sync
//  across tabs.
//

import SwiftUI

struct ContentView: View {

    @StateObject private var ticketsStore = TicketsStore()
    @StateObject private var collectionsStore = CollectionsStore()

    var body: some View {
        TabView {
            CollectionsView()
                .tabItem {
                    Label("Collections", systemImage: "square.grid.2x2")
                }

            AllTicketsView()
                .tabItem {
                    Label("All tickets", systemImage: "ticket")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .environmentObject(ticketsStore)
        .environmentObject(collectionsStore)
        .task {
            await collectionsStore.load()
            await ticketsStore.load()
        }
    }
}

#Preview {
    ContentView()
}
