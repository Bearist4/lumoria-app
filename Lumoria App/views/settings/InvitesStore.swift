//
//  InvitesStore.swift
//  Lumoria App
//
//  Owns the signed-in user's single invite. One non-revoked row per user is
//  enforced by a partial unique index in Postgres; the "send" action retries
//  on the rare token collision.
//

import Combine
import Foundation
import Supabase
import SwiftUI

@MainActor
final class InvitesStore: ObservableObject {

    enum ViewState: Equatable {
        case loading
        case notSent
        case sent(Invite)
        case redeemed(Invite)
    }

    @Published private(set) var state: ViewState = .loading
    @Published var errorMessage: String? = nil

    /// Nonisolated so it can be used as a SwiftUI view-init default arg
    /// from nonisolated contexts. All stored properties are simple
    /// defaults that don't require actor access at init time.
    nonisolated init() {}

    #if DEBUG
    /// Preview-only flag: once seeded, `load()` becomes a no-op so the
    /// live Supabase fetch can't stomp the preview state.
    private var skipLoadForPreview = false

    /// Preview-only: seed `state` without going through Supabase so
    /// `#Preview` blocks can render each `ViewState` variant.
    func setStateForPreview(_ state: ViewState) {
        self.state = state
        skipLoadForPreview = true
    }
    #endif

    // MARK: - Load

    func load() async {
        #if DEBUG
        if skipLoadForPreview { return }
        #endif

        guard (try? await supabase.auth.session) != nil else {
            state = .notSent
            return
        }

        do {
            let rows: [InviteRow] = try await supabase
                .from("invites")
                .select()
                .is("revoked_at", value: nil)
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value

            if let invite = rows.first?.toInvite() {
                state = invite.isRedeemed ? .redeemed(invite) : .sent(invite)
            } else {
                state = .notSent
            }
            errorMessage = nil
        } catch is CancellationError {
        } catch let error as URLError where error.code == .cancelled {
        } catch {
            errorMessage = "Couldn’t load your invite. \(error.localizedDescription)"
            print("[InvitesStore] load failed:", error)
        }
    }

    // MARK: - Send

    /// Generates a fresh token and inserts a row. Retries once on a token
    /// collision; any further insert error surfaces to the UI.
    @discardableResult
    func sendInvite() async -> Invite? {
        guard let userId = supabase.auth.currentUser?.id else {
            errorMessage = "You need to be signed in to send an invite."
            return nil
        }

        for attempt in 0..<2 {
            let row = NewInviteRow(inviterId: userId, token: InviteToken.make())
            do {
                let inserted: InviteRow = try await supabase
                    .from("invites")
                    .insert(row)
                    .select()
                    .single()
                    .execute()
                    .value
                let invite = inserted.toInvite()
                state = .sent(invite)
                errorMessage = nil
                let tokenHash = AnalyticsIdentity.hashString(invite.token)
                Analytics.track(.inviteGenerated(isFirstTime: attempt == 0))
                Analytics.updateUserProperties(["invites_sent": 1])
                _ = tokenHash
                return invite
            } catch {
                let message = "\(error)"
                // Token collision: retry once. Every other error is terminal.
                let isUniqueViolation = message.contains("invites_token_key")
                    || message.contains("duplicate key value")
                if isUniqueViolation, attempt == 0 { continue }

                errorMessage = "Couldn’t send your invite. \(error.localizedDescription)"
                print("[InvitesStore] send failed:", error)
                return nil
            }
        }
        return nil
    }

    // MARK: - Revoke

    func revoke(_ invite: Invite) async {
        do {
            let patch = RevokeInvitePatch(revokedAt: Date())
            try await supabase
                .from("invites")
                .update(patch)
                .eq("id", value: invite.id.uuidString)
                .execute()
            state = .notSent
            errorMessage = nil
        } catch {
            errorMessage = "Couldn’t revoke the invite. \(error.localizedDescription)"
            print("[InvitesStore] revoke failed:", error)
        }
    }

    // MARK: - Claim (post-signup, invitee side)

    /// Attaches the given token to the signed-in user's account. Called from
    /// the auth flow once we have a session and there's a pending token from
    /// a deep-link. Errors are logged but not shown — the invitee may not
    /// realize an invite exists, and shouldn't see an error if they don't.
    static func claim(token: String) async {
        let started = Date()
        let tokenHash = AnalyticsIdentity.hashString(token)
        do {
            _ = try await supabase.rpc(
                "claim_invite",
                params: ["p_token": token]
            ).execute()
            let ms = Int(Date().timeIntervalSince(started) * 1000)
            Analytics.track(.inviteClaimed(
                inviteTokenHash: tokenHash,
                role: .invitee,
                timeToClaimMs: ms
            ))
        } catch {
            print("[InvitesStore] claim failed for token \(token):", error)
            Analytics.track(.appError(
                domain: .invite,
                code: (error as NSError).code.description,
                viewContext: "InvitesStore.claim"
            ))
        }
    }
}
