//
//  Lumoria_AppApp.swift
//  Lumoria App
//
//  Created by Benjamin Caillet on 13/04/2026.
//

import Supabase
import SwiftUI
import SwiftData

// Analytics bootstrapping. Runs once at process start, before any view
// is constructed. Missing API key falls back to NoopAnalyticsService.
private let analyticsBootstrap: Void = {
    if let service = AmplitudeAnalyticsService() {
        Analytics.configure(service)
    }
    Analytics.track(.sdkInitialized)
}()

@main
struct Lumoria_AppApp: App {
    @UIApplicationDelegateAdaptor(LumoriaAppDelegate.self) private var appDelegate
    @StateObject private var authManager = AuthManager()
    @StateObject private var pushService = PushNotificationService.shared
    @StateObject private var notificationPrefs = NotificationPrefsStore()
    @AppStorage("appearance.mode") private var storedMode: String = AppearanceMode.system.rawValue
    @AppStorage("appearance.highContrast") private var highContrast: Bool = false
    @AppStorage("appearance.iconName") private var storedIconName: String = ""
    @AppStorage("auth.hasCache") private var authHasCache: Bool = false
    @AppStorage("auth.lastKnownAuthenticated") private var authLastKnown: Bool = false

    init() {
        _ = analyticsBootstrap
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    private var colorScheme: ColorScheme? {
        AppearanceMode(rawValue: storedMode)?.colorScheme
    }

    /// Route the first paint based on the last known session outcome so
    /// returning signed-in users never see the landing screen flash
    /// while Supabase restores their session asynchronously.
    private var shouldShowAuthedUI: Bool {
        if authManager.isRestoring { return authHasCache && authLastKnown }
        return authManager.isAuthenticated
    }

    /// Render the landing screen directly when we know the last state
    /// was signed-out — no splash, no flash.
    private var shouldShowLanding: Bool {
        if authManager.isRestoring { return authHasCache && !authLastKnown }
        return !authManager.isAuthenticated
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if shouldShowAuthedUI {
                    ContentView()
                        .environmentObject(authManager)
                        .environmentObject(pushService)
                        .environmentObject(notificationPrefs)
                } else if shouldShowLanding {
                    AuthNavigationView()
                        .environmentObject(authManager)
                } else {
                    AuthRestoringSplash()
                }
            }
            .preferredColorScheme(colorScheme)
            .environment(\.brandSlug, BrandArt.slug(from: storedIconName.isEmpty ? nil : storedIconName))
            .onChange(of: highContrast, initial: true) { _, on in
                applyHighContrast(on)
            }
            .onOpenURL { url in
                handleIncomingURL(url)
            }
            .task {
                Analytics.track(.appOpened(source: .cold))
                await pushService.requestAuthorization()
            }
            .onChange(of: authManager.isAuthenticated) { _, isAuthed in
                if isAuthed {
                    pushService.authDidChange()
                    Task { await notificationPrefs.load() }
                } else {
                    Task { await pushService.signedOut() }
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }

    /// Forces the asset-catalog "contrast=high" variant on every active
    /// window when the user toggles the in-app High Contrast switch.
    /// Uses `UIWindow.traitOverrides` (iOS 17+). Propagates to all
    /// `Color("…")` lookups and UIColor-based assets.
    private func applyHighContrast(_ on: Bool) {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.traitOverrides.accessibilityContrast = on ? .high : .normal
            }
        }
    }

    /// Catches incoming universal links (https://getlumoria.app/invite/…,
    /// https://getlumoria.app/auth/…) and custom-scheme links (lumoria://invite/…).
    /// Auth callbacks complete the PKCE exchange; invite links stash the token
    /// so the auth flow can claim it once the invitee has a session.
    private func handleIncomingURL(_ url: URL) {
        let scheme = url.scheme ?? "unknown"
        let host = url.host
        let isAuthCallback = host?.lowercased() == "getlumoria.app"
            && url.path.lowercased().hasPrefix("/auth/")
        let token = InviteLink.token(from: url)
        let kind: DeepLinkKindProp = isAuthCallback ? .other : (token != nil ? .invite : .other)

        Analytics.track(.deepLinkOpened(scheme: scheme, host: host, kind: kind))

        if isAuthCallback {
            Task {
                do {
                    _ = try await supabase.auth.session(from: url)
                } catch {
                    print("[Auth] callback exchange failed:", error)
                }
            }
            return
        }

        guard let token else { return }
        let tokenHash = AnalyticsIdentity.hashString(token)
        let wasAuthenticated = authManager.isAuthenticated
        Analytics.track(.inviteLinkOpened(
            inviteTokenHash: tokenHash,
            wasAuthenticated: wasAuthenticated
        ))

        PendingInviteTokenStore.save(token)

        // If the recipient is already signed in (e.g. taps on the same
        // device), claim right away so it doesn't sit until next launch.
        if wasAuthenticated {
            Task {
                guard let pending = PendingInviteTokenStore.take() else { return }
                await InvitesStore.claim(token: pending)
                Analytics.track(.inviteAutoClaimed(inviteTokenHash: tokenHash))
            }
        }
    }
}

/// Root container for the unauthenticated flow.
/// LandingView owns all auth sheet presentations.
private struct AuthNavigationView: View {
    var body: some View {
        LandingView()
    }
}

/// Neutral splash shown while the saved Supabase session is being
/// restored. Matches the launch-screen logomark so the handoff from
/// system launch screen → first SwiftUI frame has no visible jump.
private struct AuthRestoringSplash: View {
    @Environment(\.brandSlug) private var brandSlug

    var body: some View {
        ZStack {
            Color.Background.default.ignoresSafeArea()
            Image("brand/\(brandSlug)/logomark")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .opacity(0.6)
        }
    }
}
