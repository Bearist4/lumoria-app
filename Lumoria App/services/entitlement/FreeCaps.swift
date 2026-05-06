//
//  FreeCaps.swift
//  Lumoria App
//
//  Free-tier counter math. Mirrors the SQL trigger logic in
//  supabase/migrations/20260504000000_bump_ticket_cap_to_10.sql
//  (and the original 20260506000000_paywall_phase_1_foundation.sql).
//  Keep both sides in sync.
//

import Foundation

enum FreeCaps {
    static let baseMemoryCap = 3
    static let memoryRewardBonus = 1

    static let baseTicketCap = 10
    static let ticketRewardBonus = 2

    static func memoryCap(rewardKind: InviteRewardKind?) -> Int {
        baseMemoryCap + (rewardKind == .memory ? memoryRewardBonus : 0)
    }

    static func ticketCap(rewardKind: InviteRewardKind?) -> Int {
        baseTicketCap + (rewardKind == .tickets ? ticketRewardBonus : 0)
    }

    /// Returns the IDs of items that should be locked under the current
    /// free-tier cap. Policy: the `cap` *oldest* items (by `createdAt`)
    /// stay unlocked; everything created after that is locked. Used by
    /// the gallery + memory grid to dim and gate items beyond the cap
    /// after a former early adopter revokes their seat.
    ///
    /// Returns an empty set when the user is premium / grandfathered or
    /// when total count is at-or-under the cap.
    static func lockedIDs<Item: Identifiable>(
        items: [Item],
        cap: Int,
        isPremium: Bool,
        createdAt: (Item) -> Date
    ) -> Set<Item.ID> {
        guard !isPremium, items.count > cap else { return [] }
        let oldestFirst = items.sorted { createdAt($0) < createdAt($1) }
        let kept = Set(oldestFirst.prefix(cap).map(\.id))
        return Set(items.map(\.id)).subtracting(kept)
    }

    /// Group-aware ticket lock policy. Multi-leg public-transport
    /// trips share a `groupId` and read as a single trip in the UI —
    /// splitting "legs 1–2 unlocked, 3–4 locked" looks broken, so the
    /// policy fits whole groups, not individual legs.
    ///
    /// Algorithm: bucket tickets by `groupId` (lone tickets become
    /// singleton groups), sort groups oldest-first by their oldest leg,
    /// walk the list and include each group whose leg count fits the
    /// remaining budget. Groups that don't fit lock all their legs
    /// together. The walk is *lenient* — a group that overshoots is
    /// skipped, but later (smaller) groups can still slot in. Worst
    /// case: a single group is bigger than the cap and the whole
    /// account locks until the user deletes it.
    static func lockedTicketIDs(
        tickets: [Ticket],
        cap: Int,
        isPremium: Bool
    ) -> Set<UUID> {
        guard !isPremium, tickets.count > cap else { return [] }

        // Bucket by group key. A lone ticket gets a synthetic key so
        // the same algorithm handles both shapes.
        struct Bucket {
            var ids: [UUID] = []
            var oldest: Date = .distantFuture
            var size: Int { ids.count }
        }
        var buckets: [String: Bucket] = [:]
        for t in tickets {
            let key = t.groupId?.uuidString ?? "single:\(t.id.uuidString)"
            var b = buckets[key] ?? Bucket()
            b.ids.append(t.id)
            if t.createdAt < b.oldest { b.oldest = t.createdAt }
            buckets[key] = b
        }

        let oldestFirst = buckets.values.sorted { $0.oldest < $1.oldest }
        var locked = Set<UUID>()
        var running = 0
        for bucket in oldestFirst {
            if running + bucket.size <= cap {
                running += bucket.size
            } else {
                locked.formUnion(bucket.ids)
            }
        }
        return locked
    }
}
