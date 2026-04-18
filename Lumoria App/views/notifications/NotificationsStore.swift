//
//  NotificationsStore.swift
//  Lumoria App
//
//  Loads the current user's notification feed from Supabase. The table
//  is written to exclusively by backend jobs (cron, triggers, staff-run
//  `broadcast_news()`), so this store only ever reads + updates
//  `read_at` / `dismissed_at` on its own rows.
//

import Combine
import Foundation
import Supabase
import SwiftUI

@MainActor
final class NotificationsStore: ObservableObject {

    @Published private(set) var notifications: [LumoriaNotification] = []
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        defer { isLoading = false }

        guard supabase.auth.currentUser != nil else {
            notifications = []
            return
        }

        do {
            let rows: [NotificationRow] = try await supabase
                .from("notifications")
                .select()
                .is("dismissed_at", value: nil)
                .order("created_at", ascending: false)
                .execute()
                .value

            notifications = rows.compactMap { $0.toNotification() }
            errorMessage = nil
        } catch is CancellationError {
            // View dismissed mid-load — normal, don't surface.
        } catch let error as URLError where error.code == .cancelled {
            // URLSession cancellation — same treatment.
        } catch {
            errorMessage = String(localized: "Couldn’t load notifications. \(error.localizedDescription)")
            print("[NotificationsStore] load failed:", error)
            Analytics.track(.appError(domain: .notification, code: (error as NSError).code.description, viewContext: "NotificationsStore.load"))
        }
    }

    // MARK: - Mark read

    /// Stamps `read_at = now()` on every currently-unread row. Updates
    /// local state optimistically; network write is fire-and-forget.
    func markAllRead() {
        let unread = notifications.filter { !$0.isRead }
        guard !unread.isEmpty else { return }

        for i in notifications.indices where !notifications[i].isRead {
            notifications[i].isRead = true
        }

        let ids = unread.map(\.id)
        Task { [weak self] in
            await self?.patch(ids: ids, fields: ["read_at": .date(Date())])
        }
    }

    // MARK: - Dismiss

    /// Hides a single notification for the current user by stamping
    /// `dismissed_at = now()`. Removes it from local state optimistically.
    func delete(_ notification: LumoriaNotification) {
        notifications.removeAll { $0.id == notification.id }

        Task { [weak self] in
            await self?.patch(ids: [notification.id], fields: ["dismissed_at": .date(Date())])
        }
    }

    /// Hides every notification currently visible for this user.
    func clearAll() {
        let ids = notifications.map(\.id)
        notifications.removeAll()
        guard !ids.isEmpty else { return }

        Task { [weak self] in
            await self?.patch(ids: ids, fields: ["dismissed_at": .date(Date())])
        }
    }

    // MARK: - Patch helper

    private func patch(ids: [UUID], fields: [String: PatchValue]) async {
        guard !ids.isEmpty else { return }
        let payload = fields.mapValues { $0 }
        do {
            try await supabase
                .from("notifications")
                .update(payload)
                .in("id", values: ids.map(\.uuidString))
                .execute()
        } catch {
            print("[NotificationsStore] patch failed:", error)
        }
    }
}

// MARK: - Patch value

/// Small wrapper so the `update()` call can pass a `Date` (encoded as an
/// ISO8601 timestamp) without falling foul of the `AnyEncodable` limits
/// in the Supabase client.
private enum PatchValue: Encodable {
    case date(Date)
    case null

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .date(let d): try container.encode(d)
        case .null:        try container.encodeNil()
        }
    }
}

// MARK: - DB row shape

private struct NotificationRow: Decodable {
    let id: UUID
    let kind: String
    let title: String
    let message: String
    let memoryId: UUID?
    let templateKind: String?
    let createdAt: Date
    let readAt: Date?
    let dismissedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, kind, title, message
        case memoryId     = "memory_id"
        case templateKind = "template_kind"
        case createdAt    = "created_at"
        case readAt       = "read_at"
        case dismissedAt  = "dismissed_at"
    }

    func toNotification() -> LumoriaNotification? {
        guard let k = LumoriaNotification.Kind(rawValue: kind) else { return nil }
        return LumoriaNotification(
            id: id,
            kind: k,
            title: title,
            message: message,
            createdAt: createdAt,
            isRead: readAt != nil,
            memoryId: memoryId,
            templateKind: templateKind.flatMap(TicketTemplateKind.init(rawValue:))
        )
    }
}
