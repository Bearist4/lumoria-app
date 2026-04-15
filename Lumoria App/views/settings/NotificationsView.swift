//
//  NotificationsView.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=970-22835
//

import SwiftUI

struct NotificationsView: View {

    @Environment(\.dismiss) private var dismiss

    // MVP local state — wire to Supabase notification prefs table later.
    @State private var friendAcceptedInvite = true
    @State private var newTemplates = true
    @State private var onThisDay = true
    @State private var collectionMilestones = true

    var body: some View {
        ZStack(alignment: .top) {
            Color.Background.default.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Notifications")
                        .font(.system(size: 34, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(Color.Text.primary)
                        .padding(.top, 64)
                        .padding(.bottom, 8)

                    section(title: "Invites & collections") {
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
                            title: "Collection milestones",
                            subtitle: "When your collection reaches something worth celebrating.",
                            isOn: $collectionMilestones
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
                .font(.system(size: 20, weight: .semibold))
                .tracking(-0.45)
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
                    .font(.system(size: 17, weight: .regular))
                    .tracking(-0.43)
                    .foregroundStyle(Color.Text.primary)

                Text(subtitle)
                    .font(.system(size: 15, weight: .regular))
                    .tracking(-0.23)
                    .foregroundStyle(Color.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color("Colors/Green/500"))
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
