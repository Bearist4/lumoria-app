//
//  Lumoria_AppApp.swift
//  Lumoria App
//
//  Created by Benjamin Caillet on 13/04/2026.
//

import SwiftUI
import SwiftData
import CoreText

@main
struct Lumoria_AppApp: App {
    @StateObject private var authManager = AuthManager()
    @AppStorage("appearance.mode") private var storedMode: String = AppearanceMode.system.rawValue

    init() {
        Self.registerBundledFonts()
    }

    private static func registerBundledFonts() {
        let names = ["Doto-Black"]
        for name in names {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else {
                continue
            }
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        }
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

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    ContentView()
                        .environmentObject(authManager)
                } else {
                    AuthNavigationView()
                        .environmentObject(authManager)
                }
            }
            .preferredColorScheme(colorScheme)
            .onOpenURL { url in
                handleIncomingURL(url)
            }
        }
        .modelContainer(sharedModelContainer)
    }

    /// Catches incoming universal links (https://getlumoria.app/invite/…) and
    /// custom-scheme links (lumoria://invite/…). Stashes the token so the
    /// auth flow can claim it once the invitee has a session.
    private func handleIncomingURL(_ url: URL) {
        guard let token = InviteLink.token(from: url) else { return }
        PendingInviteTokenStore.save(token)

        // If the recipient is already signed in (e.g. taps on the same
        // device), claim right away so it doesn't sit until next launch.
        if authManager.isAuthenticated {
            Task {
                guard let pending = PendingInviteTokenStore.take() else { return }
                await InvitesStore.claim(token: pending)
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
