//
//  CollectionsView.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=948-12558
//

import SwiftUI
import MapKit
import CoreLocation

struct CollectionsView: View {

    @EnvironmentObject private var store: CollectionsStore
    @EnvironmentObject private var ticketsStore: TicketsStore
    @State private var showNewCollection = false
    @State private var showMap = false

    private let columns = [
        GridItem(.flexible(), spacing: 24),
        GridItem(.flexible(), spacing: 24),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header

                if hasAnyLocation {
                    HStack(spacing: 8) {
                        ThumbnailPillButton(title: "View map", action: { showMap = true }) {
                            MiniMapThumbnail(
                                coordinate: store.collections.compactMap(\.coordinate).first
                            )
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(store.collections) { c in
                            let tickets = ticketsStore.tickets(in: c.id)
                            NavigationLink(value: c) {
                                CollectionCard(
                                    title: c.name,
                                    subtitle: tickets.count == 1 ? "1 ticket" : "\(tickets.count) tickets",
                                    state: .normal,
                                    filledCount: min(tickets.count, 5),
                                    colorFamily: c.colorFamily
                                ) { idx in
                                    if idx < tickets.count {
                                        TicketPreview(ticket: tickets[idx])
                                            .frame(width: 160)
                                    } else {
                                        EmptyView()
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    Task { await store.delete(c) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }

                        // Always-visible "Create new" card
                        Button {
                            showNewCollection = true
                        } label: {
                            CollectionCard(state: .new)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                .refreshable { await store.load() }

                if let error = store.errorMessage {
                    errorBanner(error)
                }

                if store.collections.isEmpty && !store.isLoading {
                    emptyCopy
                        .padding(.horizontal, 40)
                        .padding(.bottom, 32)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Collection.self) { c in
                CollectionDetailView(collection: c)
            }
            .task { await store.load() }
            .sheet(isPresented: $showNewCollection) {
                NewCollectionView { name, color, location in
                    guard let color else { return }
                    Task {
                        await store.create(
                            name: name,
                            colorFamily: color.family,
                            location: location
                        )
                    }
                }
            }
            .fullScreenCover(isPresented: $showMap) {
                CollectionsMapView(collections: store.collections)
            }
        }
    }

    // MARK: - Derived

    private var hasAnyLocation: Bool {
        store.collections.contains { $0.hasLocation }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Text("Collections")
                .font(.system(size: 34, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(Color.Text.primary)

            Spacer()

            HStack(spacing: 8) {
                LumoriaIconButton(systemImage: "bell", action: {})
                LumoriaIconButton(systemImage: "plus") {
                    showNewCollection = true
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Empty copy

    private var emptyCopy: some View {
        VStack(spacing: 8) {
            Text("No collections")
                .font(.system(size: 22, weight: .bold))
                .tracking(-0.26)
                .foregroundStyle(Color.Text.tertiary)

            Text("Collections are where your tickets come together. Group them by trip, theme, or memory to keep everything organized.")
                .font(.system(size: 17, weight: .regular))
                .tracking(-0.43)
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
                .font(.system(size: 13))
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

#Preview {
    TabView {
        CollectionsView()
            .tabItem { Label("Collections", systemImage: "square.grid.2x2") }
    }
}

// MARK: - Mini map thumbnail for the "View map" pill button

private struct MiniMapThumbnail: View {
    /// Ignored — the thumbnail shows a zoomed-out view of Earth so it reads
    /// as a globe at 32pt regardless of which collection is first.
    let coordinate: CLLocationCoordinate2D?

    var body: some View {
        // MapKit bakes a "Legal" link into every Map view. Render the map
        // larger than the 32pt pill thumbnail so the Legal badge (drawn in
        // the bottom-left corner) ends up outside the clip region applied
        // by ThumbnailPillButton.
        Map(
            initialPosition: .camera(
                MapCamera(
                    centerCoordinate: CLLocationCoordinate2D(latitude: 20, longitude: 0),
                    distance: 30_000_000   // ~30,000 km → full globe
                )
            ),
            interactionModes: []
        )
        .mapStyle(.standard)
        .allowsHitTesting(false)
        .frame(width: 96, height: 96)
        .fixedSize()
    }
}
