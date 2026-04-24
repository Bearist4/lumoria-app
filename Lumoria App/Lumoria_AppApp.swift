//
//  Lumoria_AppApp.swift
//  Lumoria App
//
//  Created by Benjamin Caillet on 13/04/2026.
//

import Supabase
import SwiftUI
import SwiftData
import TipKit

// Analytics bootstrapping. Runs once at process start, before any view
// is constructed. Missing API key falls back to NoopAnalyticsService.
private let analyticsBootstrap: Void = {
    if let service = AmplitudeAnalyticsService() {
        Analytics.configure(service)
    }
    Analytics.track(.sdkInitialized)
    try? Tips.configure([
        .displayFrequency(.immediate),
        .datastoreLocation(.applicationDefault),
    ])
}()

@main
struct Lumoria_AppApp: App {
    @UIApplicationDelegateAdaptor(LumoriaAppDelegate.self) private var appDelegate
    @StateObject private var authManager = AuthManager()
    @StateObject private var pushService = PushNotificationService.shared
    @StateObject private var notificationPrefs = NotificationPrefsStore()
    @StateObject private var walletImport = WalletImportCoordinator()
    @StateObject private var onboardingCoordinator = OnboardingCoordinator()
    @AppStorage("appearance.mode") private var storedMode: String = AppearanceMode.system.rawValue
    @AppStorage("appearance.highContrast") private var highContrast: Bool = false
    @AppStorage("appearance.iconName") private var storedIconName: String = ""
    @AppStorage("auth.hasCache") private var authHasCache: Bool = false
    @AppStorage("auth.lastKnownAuthenticated") private var authLastKnown: Bool = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        _ = analyticsBootstrap
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        // Xcode Preview sandbox can't always create a persistent
        // SwiftData store — force in-memory when running under
        // `XCODE_RUNNING_FOR_PREVIEWS` so the preview shell stops
        // trapping on `fatalError` during app init.
        let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isPreview
        )

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
                        .environmentObject(walletImport)
                        .environmentObject(onboardingCoordinator)
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
            .onChange(of: scenePhase, initial: true) { _, newPhase in
                switch newPhase {
                case .active:
                    TiltMotionManager.shared.start()
                    drainPendingWalletImport()
                case .background: TiltMotionManager.shared.stop()
                default:          break
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }

    /// Safety net for the Share Extension → main app hand-off. If the
    /// extension's `openURL:` call didn't round-trip for any reason
    /// (scene was already foregrounded, KVC dispatch no-op'd, etc.),
    /// the pkpass bytes are still sitting in the App Group container.
    /// Pick them up whenever the main app becomes active.
    private func drainPendingWalletImport() {
        let groupId = "group.bearista.Lumoria-App"
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: groupId) else {
            NSLog("[Lumoria] drain: containerURL nil (App Group missing on main app)")
            return
        }
        let file = container.appendingPathComponent("pending-pass.pkpass")
        guard FileManager.default.fileExists(atPath: file.path) else {
            NSLog("[Lumoria] drain: no pending pass at %@", file.path)
            return
        }
        guard let data = try? Data(contentsOf: file) else {
            NSLog("[Lumoria] drain: failed to read %@", file.path)
            return
        }
        // Remove before enqueue so a re-entrant .active (common during
        // launch → settle) doesn't enqueue the same bytes twice.
        try? FileManager.default.removeItem(at: file)
        NSLog("[Lumoria] drain: enqueued %ld bytes", data.count)
        walletImport.enqueue(data)
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
        // .pkpass hand-offs from Wallet's share sheet (or Mail / AirDrop)
        // arrive here as a file URL pointing into our Inbox. Read the
        // bytes synchronously before the scope closes, then route to
        // the wallet-import coordinator — AllTicketsView presents the
        // funnel with the pass pre-loaded.
        if url.isFileURL, url.pathExtension.lowercased() == "pkpass" {
            let didStart = url.startAccessingSecurityScopedResource()
            defer {
                if didStart { url.stopAccessingSecurityScopedResource() }
            }
            if let data = try? Data(contentsOf: url) {
                walletImport.enqueue(data)
            }
            return
        }

        // Share extension handoff — the extension wrote the pass into
        // the shared App Group container and opened a URL to wake the
        // main app. Accept either the universal link (iOS 26 routes
        // this reliably from share extensions) or the custom scheme.
        let normalizedHost = url.host?
            .lowercased()
            .replacingOccurrences(of: "www.", with: "", options: .anchored)
        let isImportUniversal = url.scheme?.lowercased() == "https"
            && normalizedHost == "getlumoria.app"
            && url.path.lowercased() == "/import/pkpass"
        let isImportCustom = url.scheme == "lumoria"
            && url.host == "import"
            && url.path == "/pkpass"
        if isImportUniversal || isImportCustom {
            let groupId = "group.bearista.Lumoria-App"
            if let container = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: groupId) {
                let file = container.appendingPathComponent("pending-pass.pkpass")
                if let data = try? Data(contentsOf: file) {
                    walletImport.enqueue(data)
                }
                try? FileManager.default.removeItem(at: file)
            }
            return
        }

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
