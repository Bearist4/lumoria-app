//
//  ProfileView.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=970-22520
//

import SwiftUI
import Auth
import Supabase

struct ProfileView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var ticketsStore: TicketsStore
    @EnvironmentObject private var memoriesStore: MemoriesStore
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var onboardingCoordinator: OnboardingCoordinator
    @Environment(EntitlementStore.self) private var entitlement

    @State private var showMenu = false
    @State private var showEdit = false

    @State private var showDeleteConfirm = false
    @State private var isDeletingAccount = false
    @State private var deleteError: String? = nil

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s4) {
                    topBar
                        .padding(.top, 6)

                    Text("Profile")
                        .font(.largeTitle.bold())
                        .foregroundStyle(Color.Text.primary)

                    headerCard

                    statsGrid
                }
                .padding(.horizontal, Spacing.s4)
                .padding(.bottom, 120)
            }
            .background(Color.Background.default.ignoresSafeArea())

            if showMenu {
                menuOverlay
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { Analytics.track(.profileViewed) }
        .sheet(isPresented: $showEdit) {
            EditProfileView()
                .environmentObject(profileStore)
        }
        .alert("Delete your account?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task { await deleteAccount() }
            }
            .disabled(isDeletingAccount)
        } message: {
            Text("This permanently removes your profile, tickets, memories, and invites. This cannot be undone.")
        }
        .alert(
            "Couldn't delete your account",
            isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            LumoriaIconButton(
                systemImage: "chevron.left",
                position: .onBackground,
                action: { dismiss() }
            )

            Spacer(minLength: 0)

            LumoriaIconButton(
                systemImage: "ellipsis",
                position: .onBackground,
                isActive: showMenu,
                action: {
                    withAnimation(.easeOut(duration: 0.15)) { showMenu.toggle() }
                }
            )
        }
    }

    // MARK: - Header card

    private var headerCard: some View {
        HStack(alignment: .top, spacing: Spacing.s4) {
            avatar
                .frame(width: 128, height: 128)

            infoCard
        }
    }

    private var avatar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color("Colors/Blue/50"))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.Border.default, lineWidth: 1)
                )
            avatarContent
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private var avatarContent: some View {
        if let ui = profileStore.avatarImage {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .frame(width: 128, height: 128)
                .clipped()
        } else {
            Text(avatarInitial)
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(Color.Text.secondary)
        }
    }

    private var avatarInitial: String {
        guard let first = profileStore.name.first else { return "?" }
        return String(first).uppercased()
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(profileStore.name)
                .font(.title2.bold())
                .foregroundStyle(Color.Text.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            LumoriaPlanBadge(
                tier: entitlement.isEarlyAdopter ? .earlyAdopter : .free
            )

            Spacer(minLength: 8)

            if let joined = profileStore.joinedDate {
                Text("Joined \(joinedFormatter.string(from: joined))")
                    .font(.caption)
                    .foregroundStyle(Color.Text.tertiary)
            }
        }
        .padding(Spacing.s4)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.Background.elevated)
        )
    }

    /// `Joined Apr. 2026` style — abbreviated month + 4-digit year.
    private var joinedFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f
    }

    // MARK: - Stats grid

    private var statsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 16
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
            LumoriaDataCard(
                content: .value(
                    "\(ticketsThisYear)",
                    caption: "tickets created this year"
                ),
                accentColorFamily: "Pink"
            )
            LumoriaDataCard(
                content: longestGapContent,
                accentColorFamily: "Yellow"
            )
            LumoriaDataCard(
                content: .value(
                    mostUsedCategoryName,
                    caption: "Most used category"
                ),
                accentColorFamily: "Lime"
            )
        }
        .padding(.top, Spacing.s4)
    }

    // MARK: - Stats

    private var ticketsThisMonth: Int {
        ticketsStore.tickets
            .filter { Calendar.current.isDate($0.createdAt, equalTo: .now, toGranularity: .month) }
            .count
    }

    private var ticketsThisYear: Int {
        ticketsStore.tickets
            .filter { Calendar.current.isDate($0.createdAt, equalTo: .now, toGranularity: .year) }
            .count
    }

    /// Largest interval between two consecutive tickets' creation dates.
    /// Returns `.valueWithSuffix` in months if the gap is ≥ 1 month, else
    /// in days. `.value("—", …)` when fewer than 2 tickets exist.
    private var longestGapContent: LumoriaDataCardContent {
        let sorted = ticketsStore.tickets
            .map(\.createdAt)
            .sorted()
        guard sorted.count >= 2 else {
            return .value("—", caption: "Longest gap between tickets")
        }
        let intervals = zip(sorted.dropFirst(), sorted)
            .map { $0.timeIntervalSince($1) }
        guard let maxSeconds = intervals.max(), maxSeconds > 0 else {
            return .value("—", caption: "Longest gap between tickets")
        }
        let days = Int(maxSeconds / 86_400)
        if days >= 30 {
            let months = days / 30
            return .valueWithSuffix(
                "\(months)",
                suffix: months == 1 ? "month" : "months",
                caption: "Longest gap between tickets"
            )
        }
        return .valueWithSuffix(
            "\(days)",
            suffix: days == 1 ? "day" : "days",
            caption: "Longest gap between tickets"
        )
    }

    /// Category the user has created the most tickets in. Returns "—"
    /// when the user has no tickets yet.
    private var mostUsedCategoryName: String {
        let counts = Dictionary(
            grouping: ticketsStore.tickets,
            by: { $0.kind.categoryStyle }
        )
        .mapValues(\.count)
        guard let winner = counts.max(by: { $0.value < $1.value })?.key else {
            return "—"
        }
        return winner.displayName
    }

    // MARK: - Menu overlay

    private var menuOverlay: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.12)) { showMenu = false }
                }

            LumoriaContextualMenu(items: [
                LumoriaMenuItem(title: "Edit") {
                    showMenu = false
                    showEdit = true
                },
                LumoriaMenuItem(title: "Restart onboarding") {
                    showMenu = false
                    Task { await restartOnboarding() }
                },
                LumoriaMenuItem(title: "Delete my account", kind: .destructive) {
                    showMenu = false
                    showDeleteConfirm = true
                },
            ])
            .padding(.top, 62)
            .padding(.trailing, 16)
            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)))
        }
    }

    // MARK: - Restart onboarding

    /// Flips the user's `show_onboarding` flag back to `true` and resets
    /// `onboarding_step` to `welcome` in Supabase via the coordinator,
    /// which also surfaces the Welcome sheet. Dismisses Profile so
    /// ContentView's tab-switch (driven by `showWelcome`) lands the
    /// user back on Memories.
    private func restartOnboarding() async {
        await onboardingCoordinator.resetForReplay()
        dismiss()
    }

    // MARK: - Account deletion

    /// Calls the `delete-account` edge function. The server wipes every
    /// user-scoped row, then auth.admin.deleteUser removes the auth row,
    /// which fires `.signedOut` on the auth listener and tears the rest
    /// of the local state down.
    private func deleteAccount() async {
        guard !isDeletingAccount else { return }
        isDeletingAccount = true
        defer { isDeletingAccount = false }

        do {
            // Grab a fresh session explicitly so we know which token the
            // edge function receives. Supabase Swift's shared Functions
            // client is normally kept in sync via the auth listener, but
            // passing the access token in headers removes any ambiguity
            // if that wiring hasn't propagated yet.
            let session = try await supabase.auth.session
            try await supabase.functions.invoke(
                "delete-account",
                options: FunctionInvokeOptions(
                    headers: ["Authorization": "Bearer \(session.accessToken)"],
                    body: ["confirmation": "DELETE"]
                )
            )
            try? await supabase.auth.signOut()
        } catch {
            deleteError = String(
                localized: "Couldn’t delete your account. \(error.localizedDescription) If the problem persists, contact support."
            )
            Analytics.track(.appError(
                domain: .auth,
                code: (error as NSError).code.description,
                viewContext: "ProfileView.deleteAccount"
            ))
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ProfileView()
    }
    .environmentObject(TicketsStore())
    .environmentObject(MemoriesStore())
    .environmentObject(ProfileStore())
    .environment(EntitlementStore.previewInstance(
        tier: .free,
        monetisationEnabled: false
    ))
}
