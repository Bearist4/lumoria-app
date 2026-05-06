//
//  ManageEarlyAdopterStatusView.swift
//  Lumoria App
//
//  Status-management screen pushed from Settings once the user holds
//  an early-adopter seat. Re-states the deal, surfaces a couple of
//  vanity stats so revoking feels like real loss, then routes the
//  destructive "Revoke my status" CTA through a confirm alert before
//  hitting the revoke RPC.
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=2153-162836
//

import SwiftUI

struct ManageEarlyAdopterStatusView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(EntitlementStore.self) private var entitlement
    @EnvironmentObject private var memoriesStore: MemoriesStore
    @EnvironmentObject private var ticketsStore: TicketsStore

    @State private var showRevokeAlert: Bool = false
    @State private var isRevoking: Bool = false
    @State private var errorMessage: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                title

                Text("Early adopters help build Lumoria for everyone else by participating in research to improve the app and helping build a better app.")
                    .font(.body)
                    .foregroundStyle(Color.Text.primary)

                youCreatedSection

                youWillLoseSection

                revokeFooter
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color.Background.default.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                LumoriaIconButton(systemImage: "arrow.left") { dismiss() }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .alert(
            "Revoke early adopter status?",
            isPresented: $showRevokeAlert
        ) {
            Button("Keep my status", role: .cancel) { }
            Button("Revoke", role: .destructive) {
                Task { await revoke() }
            }
        } message: {
            Text("You'll fall back to the Free tier limits. Existing memories and tickets stay but new ones will be capped again.")
        }
        .alert(
            "Couldn't revoke status",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Title

    private var title: some View {
        Text("Manage your status")
            .font(.largeTitle.bold())
            .foregroundStyle(Color.Text.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - You created

    private var youCreatedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("You created")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.Text.primary)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 24
            ) {
                LumoriaDataCard(
                    content: .value(
                        "\(memoriesStore.memories.count)",
                        caption: "memories created"
                    ),
                    accentColorFamily: "Orange"
                )
                LumoriaDataCard(
                    content: .value(
                        "\(ticketsThisMonth)",
                        caption: "tickets created this month"
                    ),
                    accentColorFamily: "Blue"
                )
            }

            Text("If you decide to revoke your early adopter status, you will return back to the original limit of 3 memories and 10 tickets per account.")
                .font(.footnote)
                .foregroundStyle(Color.Text.secondary)
        }
    }

    private var ticketsThisMonth: Int {
        ticketsStore.tickets
            .filter {
                Calendar.current.isDate($0.createdAt, equalTo: .now, toGranularity: .month)
            }
            .count
    }

    // MARK: - You will also lose

    private var youWillLoseSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("You will also lose")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.Text.primary)

            benefitRow(icon: "infinity", title: "Unlimited memories and tickets")
            benefitRow(icon: "paintbrush.fill", title: "Premium ticket styles and recolouring")
            benefitRow(icon: "sparkles", title: "Early access to new features")
            benefitRow(icon: "checkmark.seal.fill", title: "A direct line to the team via research")
        }
    }

    private func benefitRow(icon: String, title: LocalizedStringKey) -> some View {
        HStack(alignment: .center, spacing: 4) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(Color.Text.primary)
                .frame(width: 32, height: 32)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.Text.primary)
        }
    }

    // MARK: - Revoke footer

    private var revokeFooter: some View {
        VStack(spacing: 16) {
            Text("Revoking your status means that you will lose benefits associated with being an early adopter. Your current content will remain but will be locked.")
                .font(.footnote)
                .foregroundStyle(Color.Text.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Button {
                if !isRevoking { showRevokeAlert = true }
            } label: {
                if isRevoking {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Revoke my status")
                }
            }
            .lumoriaButtonStyle(.danger, size: .large)
            .disabled(isRevoking)
        }
        .padding(.top, 16)
    }

    // MARK: - Revoke

    private func revoke() async {
        guard !isRevoking else { return }
        isRevoking = true
        defer { isRevoking = false }
        do {
            try await entitlement.revokeEarlyAdopterSeat()
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            dismiss()
        } catch {
            errorMessage = String(localized: "Something went wrong. Please try again.")
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        ManageEarlyAdopterStatusView()
            .environment(EntitlementStore.previewInstance(
                tier: .free,
                monetisationEnabled: false
            ))
            .environmentObject(MemoriesStore())
            .environmentObject(TicketsStore())
    }
}
#endif
