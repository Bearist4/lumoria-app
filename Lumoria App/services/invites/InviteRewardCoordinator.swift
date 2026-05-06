//
//  InviteRewardCoordinator.swift
//  Lumoria App
//
//  Owns the "pending invite reward" sheet presentation. There are two
//  trigger paths:
//
//    - Referrer: the user's own invite was redeemed (server's
//      `fire_link_on_first_ticket` trigger stamped `redeemed_at`).
//      We pull the state on app launch and after a refresh.
//
//    - Referree: this user just created their first ticket, which
//      caused their `claimed_by` invite row to be redeemed. Two
//      sub-cases:
//        a) Onboarding active: present once `OnboardingCoordinator`
//           reaches `.done` (the user goes through end-cover).
//        b) Onboarding skipped: present 2 s after the first ticket
//           lands in `TicketsStore` so the success animation finishes.
//
//  In both cases the actual decision ("am I a referrer or a referree
//  with a pending reward?") goes through the `pending_invite_reward`
//  Postgres RPC — the coordinator just owns the timing.
//

import Foundation
import Observation

extension Notification.Name {
    /// Posted whenever something might have flipped the user's
    /// pending-reward state — currently: a successful
    /// `claim_invite` RPC on the invitee side, and any incoming
    /// `kind = "link"` push on the inviter side. ContentView
    /// listens and triggers `InviteRewardCoordinator.evaluate()`
    /// so the reward sheet pops without the user having to restart
    /// the app.
    static let lumoriaInviteRewardSignal = Notification.Name("lumoria.invite.reward.signal")
}

@MainActor
@Observable
final class InviteRewardCoordinator {

    /// Pending reward role (if any). When non-nil the matching sheet
    /// is presented in ContentView. Cleared after the user picks
    /// memory / tickets and the claim RPC succeeds.
    private(set) var pending: InvitesStore.PendingReward? = nil

    /// Latch that prevents the post-first-ticket fallback from firing
    /// twice in a single session. Once we've asked the server "is
    /// there a reward?", we don't re-poll on every TicketsStore mutation.
    private var hasEvaluatedFirstTicket: Bool = false

    /// Re-pulls the reward state from the server. Safe to call any
    /// number of times — the RPC is read-only and idempotent.
    func evaluate() async {
        let role = await InvitesStore.pendingReward()
        if pending != role {
            pending = role
        }
    }

    /// Hook for the new-ticket creation path. Schedules an evaluation
    /// 2 s after the first ticket persists (gives the success / print
    /// animation room to land), but only if the user is NOT in the
    /// middle of onboarding — that flow has its own completion
    /// trigger via `evaluateAfterOnboardingDone()`.
    func handleFirstTicketCreated(skipIfOnboardingActive: Bool) {
        guard !hasEvaluatedFirstTicket else { return }
        hasEvaluatedFirstTicket = true
        if skipIfOnboardingActive { return }
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await evaluate()
        }
    }

    /// Hook for the onboarding completion path. Fires immediately —
    /// the end-cover sheet has already dismissed by the time this
    /// runs, so the reward sheet pops cleanly afterwards.
    func evaluateAfterOnboardingDone() {
        hasEvaluatedFirstTicket = true
        Task { await evaluate() }
    }

    /// Called after the user picks memory / tickets and the claim
    /// RPC returns. Clears the pending state so the sheet dismisses
    /// and never re-presents in this session.
    func consume() {
        pending = nil
    }

    /// User-initiated dismiss without claiming — clears pending for
    /// this session. The next `evaluate()` (app launch / refresh)
    /// will re-populate it from the server, so the prompt will return
    /// later without nagging the user inside the same session.
    func dismiss() {
        pending = nil
    }
}
