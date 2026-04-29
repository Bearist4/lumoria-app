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
    case map
    case referral
    case plan
    case helpCenter
    case helpArticle(String)
}

struct SettingsView: View {

    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var authManager: AuthManager
    @Environment(EntitlementStore.self) private var entitlement
    @Environment(\.brandSlug) private var brandSlug
    @State private var path: [SettingsDestination] = []
    @State private var showLogoutConfirm = false
    @State private var isSigningOut = false
    @State private var showBetaRedemption = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
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
                        settingsRow(icon: "map",            title: "Map",              right: .chevron) {
                            path.append(.map)
                        }
                    }

                    if !authManager.isBetaSubscriber {
                        sectionCard {
                            settingsRow(icon: "ticket",     title: "Redeem beta code", right: .chevron) {
                                showBetaRedemption = true
                            }
                        }
                    }

                    sectionCard {
                        settingsRow(icon: "doc.text",       title: "Terms of Service", right: .external) {
                            Analytics.track(.legalLinkOpened(linkType: .tos))
                            openURL("https://getlumoria.app/terms")
                        }
                        settingsRow(icon: "lock.shield",    title: "Privacy Policy",   right: .external) {
                            Analytics.track(.legalLinkOpened(linkType: .privacy))
                            openURL("https://getlumoria.app/policy")
                        }
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
            .sheet(isPresented: $showBetaRedemption) {
                BetaCodeRedemptionView()
                    .environmentObject(authManager)
            }
            .navigationDestination(for: SettingsDestination.self) { dest in
                switch dest {
                case .profile:       ProfileView()
                case .notifications: NotificationsView()
                case .appearance:    AppearanceView()
                case .map:           MapPreferencesView()
                case .referral:      InviteView()
                case .plan:          PlanManagementView(entitlement: entitlement)
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
        HStack {
            Text("Settings")
                .font(.largeTitle.bold())
                .foregroundStyle(Color.Text.primary)
            Spacer()
            Button {
                showLogoutConfirm = true
            } label: {
                if isSigningOut {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Color.Text.primary)
                        .frame(width: 48, height: 48)
                        .background(Color(.black).opacity(0.05))
                        .clipShape(Circle())
                } else {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.Text.primary)
                        .frame(width: 48, height: 48)
                        .background(Color(.black).opacity(0.05))
                        .clipShape(Circle())
                }
            }
            .disabled(isSigningOut)
            .accessibilityLabel("Log out")
        }
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
                Text(verbatim: appBuild)
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

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    // MARK: - Log out

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

}

// MARK: - Preview

#Preview {
    TabView {
        SettingsView()
            .tabItem { Label("Settings", systemImage: "gearshape") }
    }
    .environmentObject(ProfileStore())
}
