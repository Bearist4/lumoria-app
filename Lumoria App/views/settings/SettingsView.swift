//
//  SettingsView.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=970-22037
//

import SwiftUI
import Auth
import Supabase

enum SettingsDestination: Hashable {
    case profile
    case notifications
    case appearance
    case referral
    case plan
}

struct SettingsView: View {

    @State private var path: [SettingsDestination] = []

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
                        settingsRow(icon: "gift",           title: "Referral / Invite", right: .chevron) {
                            path.append(.referral)
                        }
                        settingsRow(icon: "rosette",        title: "Plan",             right: .chevron) {
                            path.append(.plan)
                        }
                    }

                    sectionCard {
                        settingsRow(icon: "doc.text",       title: "Terms of Service", right: .external) {
                            openURL("https://lumoria.app/terms")
                        }
                        settingsRow(icon: "lock.shield",    title: "Privacy Policy",   right: .external) {
                            openURL("https://lumoria.app/privacy")
                        }
                        settingsRow(icon: "lifepreserver",  title: "Contact support",  right: .external) {
                            openURL("mailto:support@lumoria.app")
                        }
                    }

                    footer
                        .padding(.top, 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(Color.Background.default)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: SettingsDestination.self) { dest in
                switch dest {
                case .profile:       ProfileView()
                case .notifications: NotificationsView()
                case .appearance:    AppearanceView()
                case .referral:      InviteView()
                case .plan:          placeholderView("Plan")
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
                .font(.system(size: 34, weight: .bold))
                .padding(.top, 100)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Background.default)
    }

    // MARK: - Header

    private var header: some View {
        Text("Settings")
            .font(.system(size: 34, weight: .bold))
            .tracking(0.4)
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
                        .font(.system(size: 17, weight: .regular))
                        .tracking(-0.43)
                        .foregroundStyle(Color.Text.primary)
                        .lineLimit(1)

                    Text("Show profile")
                        .font(.system(size: 15, weight: .regular))
                        .tracking(-0.23)
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

            Text(profileInitial)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.Text.secondary)
        }
    }

    private var profileName: String {
        if let email = supabase.auth.currentUser?.email, !email.isEmpty {
            return email
        }
        return String(localized: "Your profile")
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
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.Text.primary)
                    .frame(width: 32, height: 32)

                Text(title)
                    .font(.system(size: 17, weight: .regular))
                    .tracking(-0.43)
                    .foregroundStyle(Color.Text.primary)

                Spacer(minLength: 0)

                Image(systemName: right == .chevron ? "chevron.right" : "arrow.up.right")
                    .font(.system(size: 15, weight: .semibold))
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
            Image("brand/default/full")
                .resizable()
                .scaledToFit()
                .frame(height: 60)

            HStack(spacing: 8) {
                Text(appVersion)
                Text("Build")
            }
            .font(.system(size: 15, weight: .regular))
            .tracking(-0.23)
            .foregroundStyle(Color.Text.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return v
    }
}

// MARK: - Preview

#Preview {
    TabView {
        SettingsView()
            .tabItem { Label("Settings", systemImage: "gearshape") }
    }
}
