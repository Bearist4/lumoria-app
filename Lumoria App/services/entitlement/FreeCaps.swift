//
//  FreeCaps.swift
//  Lumoria App
//
//  Free-tier counter math. Mirrors the SQL trigger logic in
//  supabase/migrations/20260506000000_paywall_phase_1_foundation.sql.
//  Keep both sides in sync.
//

import Foundation

enum FreeCaps {
    static let baseMemoryCap = 3
    static let memoryRewardBonus = 1

    static let baseTicketCap = 5
    static let ticketRewardBonus = 2

    static func memoryCap(rewardKind: InviteRewardKind?) -> Int {
        baseMemoryCap + (rewardKind == .memory ? memoryRewardBonus : 0)
    }

    static func ticketCap(rewardKind: InviteRewardKind?) -> Int {
        baseTicketCap + (rewardKind == .tickets ? ticketRewardBonus : 0)
    }
}
