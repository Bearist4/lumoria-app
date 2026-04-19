//
//  NotificationsView.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=970-22835
//

import SwiftUI
import UIKit
import UserNotifications

struct NotificationsView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var prefsStore: NotificationPrefsStore

    // `@AppStorage` provides instant UI state. `NotificationPrefsStore`
    // mirrors these same keys into the Supabase `notification_prefs`
    // table on every change — so the server-side push sender reads the
    // authoritative value and actually skips sends the user disabled.
    @AppStorage(NotificationPrefsStore.Keys.friendAcceptedInvite) private var friendAcceptedInvite = true
    @AppStorage(NotificationPrefsStore.Keys.newTemplates)        private var newTemplates         = true
    @AppStorage(NotificationPrefsStore.Keys.onThisDay)           private var onThisDay             = true
    @AppStorage(NotificationPrefsStore.Keys.memoryMilestones)    private var memoryMilestones     = true

    @State private var systemAuthorized: Bool = true
    @State private var isCheckingSystemAuth = false

    var body: some View {
        ZStack(alignment: .top) {
            Color.Background.default.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Notifications")
                        .font(.largeTitle.bold())
                        .foregroundStyle(Color.Text.primary)
                        .padding(.top, 64)
                        .padding(.bottom, 8)

                    if !systemAuthorized {
                        systemDeniedBanner
                    }

                    section(title: "Invites & memories") {
                        toggleRow(
                            title: "Friend accepted your invite",
                            subtitle: "When someone joins using your link.",
                            isOn: $friendAcceptedInvite
                        )
                    }

                    section(title: "New content") {
                        toggleRow(
                            title: "New templates",
                            subtitle: "When fresh designs land in the app",
                            isOn: $newTemplates
                        )
                    }

                    section(title: "Memories") {
                        toggleRow(
                            title: "On this day",
                            subtitle: "A look back at a trip from this date, one year later.",
                            isOn: $onThisDay
                        )
                        toggleRow(
                            title: "Memory milestones",
                            subtitle: "When your memory reaches something worth celebrating.",
                            isOn: $memoryMilestones
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 120)
            }

            topBar
                .padding(.horizontal, 16)
                .padding(.top, 6)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await refreshSystemAuth()
            await prefsStore.load()
        }
        // Every toggle flip writes the full pref snapshot upstream. The
        // `@AppStorage` bindings have already captured the new value by
        // the time `onChange` fires, so reading them here is safe.
        .onChange(of: friendAcceptedInvite) { _, on in
            Analytics.track(.notificationPrefsChanged(notificationType: "friend_accepted_invite", enabled: on))
            syncPrefs()
        }
        .onChange(of: newTemplates) { _, on in
            Analytics.track(.notificationPrefsChanged(notificationType: "new_templates", enabled: on))
            syncPrefs()
        }
        .onChange(of: onThisDay) { _, on in
            Analytics.track(.notificationPrefsChanged(notificationType: "on_this_day", enabled: on))
            syncPrefs()
        }
        .onChange(of: memoryMilestones) { _, on in
            Analytics.track(.notificationPrefsChanged(notificationType: "memory_milestones", enabled: on))
            syncPrefs()
        }
    }

    private func syncPrefs() {
        Task {
            await prefsStore.save(
                friendAcceptedInvite: friendAcceptedInvite,
                newTemplates: newTemplates,
                onThisDay: onThisDay,
                memoryMilestones: memoryMilestones
            )
        }
    }

    // MARK: - System-auth banner

    /// iOS-level notification permission. When denied/undetermined, the
    /// toggles below are inert — iOS won't deliver anything regardless.
    /// Surface this so users know where to fix it.
    private var systemDeniedBanner: some View {
        Button {
            openSystemSettings()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "bell.slash.fill")
                    .foregroundStyle(Color.Feedback.Warning.icon)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Notifications are off in system Settings")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.Text.primary)

                    Text("The toggles below won't take effect until you enable notifications for Lumoria in iOS Settings. Tap to open.")
                        .font(.subheadline)
                        .foregroundStyle(Color.Text.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.Feedback.Warning.subtle)
            )
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func refreshSystemAuth() async {
        guard !isCheckingSystemAuth else { return }
        isCheckingSystemAuth = true
        defer { isCheckingSystemAuth = false }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        systemAuthorized = settings.authorizationStatus == .authorized
                        || settings.authorizationStatus == .provisional
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            LumoriaIconButton(
                systemImage: "chevron.left",
                position: .onBackground
            ) { dismiss() }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Section wrapper

    @ViewBuilder
    private func section<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(Color.Text.primary)

            content()
        }
    }

    // MARK: - Toggle row

    private func toggleRow(
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(Color.Text.primary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color("Colors/Green/500"))
                .sensoryFeedback(.impact(weight: .light), trigger: isOn.wrappedValue)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.Background.elevated)
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        NotificationsView()
    }
}
