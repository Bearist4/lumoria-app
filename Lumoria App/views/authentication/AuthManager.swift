//
//  AuthManager.swift
//  Lumoria App
//

import Combine
import Supabase
import SwiftUI

@MainActor
final class AuthManager: ObservableObject {
    @Published var isAuthenticated = false {
        didSet { AuthCache.lastKnownAuthenticated = isAuthenticated }
    }
    @Published var isBetaSubscriber = false
    /// True while the initial session restore is in flight. The app root
    /// shows a neutral splash instead of the landing screen during this
    /// window so returning signed-in users never see a landing flash.
    @Published var isRestoring = true

    init() {
        Task {
            // Restore any saved session before the auth listener fires so
            // `supabase.auth.currentUser` is populated by the time downstream
            // stores hit PostgREST.
            let session = try? await supabase.auth.session
            isAuthenticated = session != nil
            if let uid = session?.user.id {
                provisionDataKey(for: uid)
            }
            AuthCache.hasCache = true
            isRestoring = false
            await listenForAuthChanges()
        }
    }

    private func listenForAuthChanges() async {
        for await (event, session) in supabase.auth.authStateChanges {
            switch event {
            case .initialSession:
                let valid = session.map { !$0.isExpired } ?? false
                isAuthenticated = valid
                Analytics.track(.sessionRestored(hadCache: AuthCache.hasCache))
                if valid, let user = session?.user {
                    provisionDataKey(for: user.id)
                    identifyUser(user)
                    await checkBetaStatus()
                    await claimPendingInviteIfAny()
                }
            case .signedIn, .tokenRefreshed, .userUpdated:
                isAuthenticated = session != nil
                if let user = session?.user {
                    provisionDataKey(for: user.id)
                    if event == .signedIn {
                        let domain = AnalyticsIdentity.emailDomain(user.email ?? "") ?? "unknown"
                        let wasFromInvite = PendingInviteTokenStore.current != nil
                        Analytics.track(.loginSucceeded(
                            emailDomain: domain,
                            wasFromInvite: wasFromInvite
                        ))
                    }
                    identifyUser(user)
                    await checkBetaStatus()
                    await claimPendingInviteIfAny()
                }
            case .signedOut:
                isAuthenticated = false
                isBetaSubscriber = false
                Analytics.track(.logout)
                Analytics.reset()
            default:
                break
            }
        }
    }

    private func identifyUser(_ user: User) {
        let userId = user.id.uuidString
        let domain = AnalyticsIdentity.emailDomain(user.email ?? "") ?? "unknown"
        Analytics.identify(userId: userId, userProperties: [
            "email_domain": domain,
        ])
    }

    /// Loads or generates the local encryption key for this user. Running
    /// it right after auth state settles means subsequent store reads can
    /// decrypt without hitting a cold-start race.
    private func provisionDataKey(for userId: UUID) {
        do {
            _ = try EncryptionService.keyFor(userId: userId)
        } catch {
            print("[AuthManager] key provisioning failed:", error)
        }
    }

    /// Consumes any token saved by a deep-link tap and attaches it to the
    /// current user. Silent on failure: an invitee who isn't aware of the
    /// link shouldn't be bothered by errors.
    private func claimPendingInviteIfAny() async {
        guard let token = PendingInviteTokenStore.take() else { return }
        await InvitesStore.claim(token: token)
    }

    private func checkBetaStatus() async {
        guard let userId = supabase.auth.currentUser?.id.uuidString else { return }
        do {
            let records: [WaitlistRecord] = try await supabase
                .from("waitlist_subscribers")
                .select()
                .eq("supabase_user_id", value: userId)
                .execute()
                .value
            isBetaSubscriber = !records.isEmpty
        } catch {
            print("[AuthManager] Beta status check failed: \(error)")
        }
    }
}

/// Persisted hint about the last session outcome. Lets the app root
/// route the first frame to the correct surface (ContentView for
/// signed-in returners, LandingView for signed-out ones) while the
/// async session restore is still in flight.
enum AuthCache {
    private static let hasCacheKey = "auth.hasCache"
    private static let lastKnownAuthedKey = "auth.lastKnownAuthenticated"

    static var hasCache: Bool {
        get { UserDefaults.standard.bool(forKey: hasCacheKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasCacheKey) }
    }

    static var lastKnownAuthenticated: Bool {
        get { UserDefaults.standard.bool(forKey: lastKnownAuthedKey) }
        set { UserDefaults.standard.set(newValue, forKey: lastKnownAuthedKey) }
    }
}

struct WaitlistRecord: Decodable {
    let id: String
    let email: String
    let supabaseUserId: String?

    enum CodingKeys: String, CodingKey {
        case id, email
        case supabaseUserId = "supabase_user_id"
    }
}
