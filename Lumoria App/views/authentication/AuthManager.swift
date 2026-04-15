//
//  AuthManager.swift
//  Lumoria App
//

import Combine
import Supabase
import SwiftUI

@MainActor
final class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isBetaSubscriber = false

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
            await listenForAuthChanges()
        }
    }

    private func listenForAuthChanges() async {
        for await (event, session) in supabase.auth.authStateChanges {
            switch event {
            case .initialSession:
                let valid = session.map { !$0.isExpired } ?? false
                isAuthenticated = valid
                if valid, let uid = session?.user.id {
                    provisionDataKey(for: uid)
                    await checkBetaStatus()
                    await claimPendingInviteIfAny()
                }
            case .signedIn, .tokenRefreshed, .userUpdated:
                isAuthenticated = session != nil
                if let uid = session?.user.id {
                    provisionDataKey(for: uid)
                    await checkBetaStatus()
                    await claimPendingInviteIfAny()
                }
            case .signedOut:
                isAuthenticated = false
                isBetaSubscriber = false
            default:
                break
            }
        }
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

struct WaitlistRecord: Decodable {
    let id: String
    let email: String
    let supabaseUserId: String?

    enum CodingKeys: String, CodingKey {
        case id, email
        case supabaseUserId = "supabase_user_id"
    }
}
