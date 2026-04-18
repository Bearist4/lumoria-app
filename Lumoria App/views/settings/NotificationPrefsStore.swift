//
//  NotificationPrefsStore.swift
//  Lumoria App
//
//  Owns the signed-in user's per-category notification preferences.
//  Mirrors the `notification_prefs` Supabase table. The server-side
//  push sender calls `public.notification_allowed(recipient, kind)`
//  before firing each notification and skips the send when it returns
//  false — so flipping a toggle here actually prevents delivery.
//
//  We keep an `@AppStorage` cache so the UI has instant state even
//  before the row loads, and so the toggle animation doesn't lag on
//  the round-trip. Supabase is the source of truth on next load.
//

import Combine
import Foundation
import Supabase
import SwiftUI

@MainActor
final class NotificationPrefsStore: ObservableObject {

    // MARK: - Keys (mirrored in `NotificationsView` as @AppStorage)

    struct Keys {
        static let friendAcceptedInvite = "notifications.friendAcceptedInvite"
        static let newTemplates         = "notifications.newTemplates"
        static let onThisDay            = "notifications.onThisDay"
        static let memoryMilestones     = "notifications.memoryMilestones"
    }

    // MARK: - Published state (for callers that want observation)

    @Published private(set) var friendAcceptedInvite: Bool = true
    @Published private(set) var newTemplates: Bool         = true
    @Published private(set) var onThisDay: Bool            = true
    @Published private(set) var memoryMilestones: Bool     = true
    @Published var errorMessage: String? = nil

    // MARK: - Row type

    private struct Row: Codable {
        let userId: UUID
        let friendAcceptedInvite: Bool
        let newTemplates: Bool
        let onThisDay: Bool
        let memoryMilestones: Bool

        enum CodingKeys: String, CodingKey {
            case userId                = "user_id"
            case friendAcceptedInvite  = "friend_accepted_invite"
            case newTemplates          = "new_templates"
            case onThisDay             = "on_this_day"
            case memoryMilestones      = "memory_milestones"
        }
    }

    nonisolated init() {}

    // MARK: - Load

    /// Pulls the row from Supabase, falling back to all-true defaults
    /// when the user hasn't saved anything yet. Mirrors the result into
    /// `UserDefaults` so `@AppStorage` consumers stay in sync.
    func load() async {
        guard let userId = supabase.auth.currentUser?.id else { return }

        do {
            let rows: [Row] = try await supabase
                .from("notification_prefs")
                .select()
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
                .value

            if let row = rows.first {
                apply(row)
            } else {
                // No row yet — keep local defaults (all true) and
                // mirror them into storage so writes are consistent.
                pushLocalToStorage()
            }
            errorMessage = nil
        } catch is CancellationError {
        } catch let error as URLError where error.code == .cancelled {
        } catch {
            errorMessage = String(localized: "Couldn't load notification preferences. \(error.localizedDescription)")
            print("[NotificationPrefsStore] load failed:", error)
            Analytics.track(.appError(domain: .notification, code: (error as NSError).code.description, viewContext: "NotificationPrefsStore.load"))
        }
    }

    // MARK: - Save

    /// Upserts the current pref values for the signed-in user.
    /// Called on every toggle flip from `NotificationsView`.
    func save(
        friendAcceptedInvite: Bool,
        newTemplates: Bool,
        onThisDay: Bool,
        memoryMilestones: Bool
    ) async {
        // Update published state + UserDefaults immediately so the UI
        // reflects the change without waiting for the network.
        self.friendAcceptedInvite = friendAcceptedInvite
        self.newTemplates         = newTemplates
        self.onThisDay            = onThisDay
        self.memoryMilestones     = memoryMilestones
        pushLocalToStorage()

        guard let userId = supabase.auth.currentUser?.id else { return }

        let row = Row(
            userId: userId,
            friendAcceptedInvite: friendAcceptedInvite,
            newTemplates: newTemplates,
            onThisDay: onThisDay,
            memoryMilestones: memoryMilestones
        )

        do {
            try await supabase
                .from("notification_prefs")
                .upsert(row, onConflict: "user_id")
                .execute()
            errorMessage = nil
        } catch is CancellationError {
        } catch let error as URLError where error.code == .cancelled {
        } catch {
            errorMessage = String(localized: "Couldn't save notification preferences. \(error.localizedDescription)")
            print("[NotificationPrefsStore] save failed:", error)
            Analytics.track(.appError(domain: .notification, code: (error as NSError).code.description, viewContext: "NotificationPrefsStore.save"))
        }
    }

    // MARK: - Sync helpers

    private func apply(_ row: Row) {
        friendAcceptedInvite = row.friendAcceptedInvite
        newTemplates         = row.newTemplates
        onThisDay            = row.onThisDay
        memoryMilestones     = row.memoryMilestones
        pushLocalToStorage()
    }

    /// Mirror published state → `UserDefaults` so `@AppStorage` wrappers
    /// in views observe the server-loaded values.
    private func pushLocalToStorage() {
        let d = UserDefaults.standard
        d.set(friendAcceptedInvite, forKey: Keys.friendAcceptedInvite)
        d.set(newTemplates,         forKey: Keys.newTemplates)
        d.set(onThisDay,            forKey: Keys.onThisDay)
        d.set(memoryMilestones,     forKey: Keys.memoryMilestones)
    }
}
