//
//  SettingsView.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=970-22037
//

import SwiftUI
import Auth
import ProgressiveBlurHeader
import Supabase

enum SettingsDestination: Hashable {
    case profile
    case notifications
    case appearance
    case referral
    case plan
    case helpCenter
    case helpArticle(String)
}

struct SettingsView: View {

    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var onboardingCoordinator: OnboardingCoordinator
    #if DEBUG
    @EnvironmentObject private var ticketsStore: TicketsStore
    @EnvironmentObject private var memoriesStore: MemoriesStore
    @State private var marketingSeedToast: String? = nil
    @State private var isSeedingMarketing = false
    #endif
    @Environment(\.brandSlug) private var brandSlug
    @State private var path: [SettingsDestination] = []
    @State private var showLogoutConfirm = false
    @State private var isSigningOut = false

    var body: some View {
        NavigationStack(path: $path) {
            StickyBlurHeader(maxBlurRadius: 8, fadeExtension: 48) {
                // No top-bar controls on the root settings screen — a thin
                // spacer is enough for the blur to cover the status bar area
                // once content scrolls under it.
                Color.clear.frame(height: 8)
            } content: {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    profileCard

                    sectionCard {
                        settingsRow(icon: "bell",           title: "Notifications",    right: .chevron) {
                            path.append(.notifications)
                        }
                        settingsRow(icon: "paintbrush",     title: "Appearance",       right: .chevron) {
                            path.append(.appearance)
                        }
                    }

                    sectionCard {
                        settingsRow(icon: "questionmark.circle", title: "Help center", right: .chevron) {
                            path.append(.helpCenter)
                        }
                        settingsRow(icon: "arrow.counterclockwise", title: "Replay onboarding", right: .chevron) {
                            Task { await onboardingCoordinator.reset() }
                        }
                    }

                    sectionCard {
                        settingsRow(icon: "doc.text",       title: "Terms of Service", right: .external) {
                            Analytics.track(.legalLinkOpened(linkType: .tos))
                            openURL("https://lumoria.app/terms")
                        }
                        settingsRow(icon: "lock.shield",    title: "Privacy Policy",   right: .external) {
                            Analytics.track(.legalLinkOpened(linkType: .privacy))
                            openURL("https://lumoria.app/privacy")
                        }
                    }

                    #if DEBUG
                    sectionCard {
                        settingsRow(
                            icon: "wand.and.stars",
                            title: "Seed marketing content",
                            right: .chevron
                        ) {
                            Task { await runMarketingSeed() }
                        }
                        .disabled(isSeedingMarketing)
                        .opacity(isSeedingMarketing ? 0.5 : 1)
                    }
                    #endif

                    sectionCard {
                        logoutRow
                    }

                    footer
                        .padding(.top, 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color.Background.default.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { Analytics.track(.settingsOpened) }
            #if DEBUG
            .lumoriaToast($marketingSeedToast)
            #endif
            .alert(
                "Log out of Lumoria?",
                isPresented: $showLogoutConfirm
            ) {
                Button("Stay signed in", role: .cancel) { }
                Button("Log out", role: .destructive) {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    Task { await signOut() }
                }
            } message: {
                Text("You can log back in anytime with the same email.")
            }
            .navigationDestination(for: SettingsDestination.self) { dest in
                switch dest {
                case .profile:       ProfileView()
                case .notifications: NotificationsView()
                case .appearance:    AppearanceView()
                case .referral:      InviteView()
                case .plan:          placeholderView("Plan")
                case .helpCenter:
                    HelpCenterView { article in
                        path.append(.helpArticle(article.id))
                    }
                case .helpArticle(let id):
                    if let article = HelpCenterContent.article(id: id) {
                        HelpArticleView(article: article)
                    } else {
                        placeholderView("Article not found")
                    }
                }
            }
        }
    }

    private func openURL(_ string: String) {
        guard let url = URL(string: string) else { return }
        UIApplication.shared.open(url)
    }

    private func placeholderView(_ title: LocalizedStringKey) -> some View {
        VStack {
            Text(title)
                .font(.largeTitle.bold())
                .padding(.top, 100)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Background.default)
    }

    // MARK: - Header

    private var header: some View {
        Text("Settings")
            .font(.largeTitle.bold())
            .foregroundStyle(Color.Text.primary)
            .padding(.horizontal, 0)
            .padding(.top, 8)
            .padding(.bottom, 8)
    }

    // MARK: - Profile card

    private var profileCard: some View {
        Button {
            path.append(.profile)
        } label: {
            HStack(spacing: 12) {
                profileAvatar
                    .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 4) {
                    Text(profileName)
                        .font(.body)
                        .foregroundStyle(Color.Text.primary)
                        .lineLimit(1)

                    Text("Show profile")
                        .font(.subheadline)
                        .foregroundStyle(Color.Text.secondary)
                        .lineLimit(1)
                }
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(8)
            .frame(minHeight: 72)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.Background.elevated)
            )
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var profileAvatar: some View {
        ZStack {
            Circle()
                .fill(Color("Colors/Red/50"))

            if let ui = profileStore.avatarImage {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(profileInitial)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.Text.secondary)
            }
        }
        .clipShape(Circle())
    }

    private var profileName: String {
        let stored = profileStore.name
        return stored.isEmpty ? String(localized: "Your profile") : stored
    }

    private var profileInitial: String {
        guard let first = profileName.first else { return "?" }
        return String(first).uppercased()
    }

    // MARK: - Section card

    @ViewBuilder
    private func sectionCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.Background.elevated)
        )
    }

    // MARK: - Settings row

    private enum SettingsRowAccessory {
        case chevron
        case external
    }

    private func settingsRow(
        icon: String,
        title: LocalizedStringKey,
        right: SettingsRowAccessory,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(Color.Text.primary)
                    .frame(width: 32, height: 32)

                Text(title)
                    .font(.body)
                    .foregroundStyle(Color.Text.primary)

                Spacer(minLength: 0)

                Image(systemName: right == .chevron ? "chevron.right" : "arrow.up.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.Text.primary)
                    .frame(width: 32, height: 32)
            }
            .padding(8)
            .frame(height: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 8) {
            Image("brand/\(brandSlug)/full")
                .resizable()
                .scaledToFit()
                .frame(height: 60)

            HStack(spacing: 8) {
                Text(appVersion)
                Text("Build")
            }
            .font(.subheadline)
            .foregroundStyle(Color.Text.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return v
    }

    // MARK: - Log out

    private var logoutRow: some View {
        Button {
            showLogoutConfirm = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.headline)
                    .foregroundStyle(Color.Feedback.Danger.text)
                    .frame(width: 32, height: 32)

                Text("Log out")
                    .font(.body)
                    .foregroundStyle(Color.Feedback.Danger.text)

                Spacer(minLength: 0)

                if isSigningOut {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Color.Feedback.Danger.icon)
                        .padding(.trailing, 8)
                }
            }
            .padding(8)
            .frame(height: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isSigningOut)
    }

    private func signOut() async {
        guard !isSigningOut else { return }
        isSigningOut = true
        defer { isSigningOut = false }
        do {
            try await supabase.auth.signOut()
        } catch {
            print("[SettingsView] signOut failed:", error)
        }
    }

    // MARK: - Marketing seed (Debug only)

    #if DEBUG
    @MainActor
    private func runMarketingSeed() async {
        guard !isSeedingMarketing else { return }
        isSeedingMarketing = true
        defer { isSeedingMarketing = false }

        marketingSeedToast = "Seeding marketing content…"
        let result = await MarketingSeeder.seed(
            ticketsStore: ticketsStore,
            memoriesStore: memoriesStore
        )
        marketingSeedToast = "Seeded \(result.ticketCount) tickets and \(result.memoryCount) memories."
    }
    #endif
}

// MARK: - Preview

#Preview {
    TabView {
        SettingsView()
            .tabItem { Label("Settings", systemImage: "gearshape") }
    }
    .environmentObject(ProfileStore())
}
