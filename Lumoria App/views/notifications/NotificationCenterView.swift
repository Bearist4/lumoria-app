//
//  NotificationCenterView.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1051-53774
//
//  Full-screen sheet listing every notification. Swipe any card left to
//  reveal a red "delete" action. The trash in the toolbar clears the
//  whole feed at once. Tapping a card bubbles the notification up via
//  `onSelect` so the host (MemoriesView) can route to the right
//  destination — the center itself doesn't know about funnels, sheets,
//  or navigation.
//

import SwiftUI

struct NotificationCenterView: View {

    @EnvironmentObject private var store: NotificationsStore
    @Environment(\.dismiss) private var dismiss

    /// Fired when the user taps a notification. The host presents the
    /// right destination (collection, funnel, template sheet, new
    /// memory sheet) once the center dismisses.
    var onSelect: (LumoriaNotification) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            Text("Notifications")
                .font(.largeTitle.bold())
                .foregroundStyle(Color.Text.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 16)

            content
        }
        .background(Color.Background.default)
        .task { await store.load() }
        .onAppear {
            Analytics.track(.notificationCenterOpened(unreadCount: store.notifications.filter { !$0.isRead }.count))
            store.markAllRead()
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            LumoriaIconButton(
                systemImage: "xmark",
                size: .large,
                position: .onBackground
            ) {
                dismiss()
            }

            Spacer()

            LumoriaIconButton(
                systemImage: "trash",
                size: .large,
                position: .onBackground
            ) {
                store.clearAll()
            }
            .disabled(store.notifications.isEmpty)
            .opacity(store.notifications.isEmpty ? 0.4 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if store.notifications.isEmpty {
            VStack(spacing: 8) {
                Spacer(minLength: 0)
                Text("All caught up")
                    .font(.title2.bold())
                    .foregroundStyle(Color.Text.tertiary)
                Text("New notifications will show up here.")
                    .font(.body)
                    .foregroundStyle(Color.Text.tertiary)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(store.notifications) { notification in
                    Button {
                        onSelect(notification)
                        dismiss()
                    } label: {
                        NotificationCard(notification: notification)
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 12, trailing: 24))
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            store.delete(notification)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.Background.default)
        }
    }
}

#Preview {
    NotificationCenterView()
        .environmentObject(NotificationsStore())
}
