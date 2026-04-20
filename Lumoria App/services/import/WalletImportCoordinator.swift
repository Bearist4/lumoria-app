//
//  WalletImportCoordinator.swift
//  Lumoria App
//
//  Carries a pending Apple Wallet `.pkpass` payload from the app-root
//  `onOpenURL` handler down to `AllTicketsView`, which presents the
//  new-ticket funnel with the data pre-loaded. The coordinator is an
//  `@StateObject` on the app root and injected as an environment
//  object; any view in the tree can set `pending` or observe it.
//

import Combine
import Foundation

@MainActor
final class WalletImportCoordinator: ObservableObject {

    /// The most recent `.pkpass` payload delivered via `onOpenURL`.
    /// Consumed once by the first observer that reads it and clears it
    /// back to nil, so a second scene-activation of the same URL
    /// doesn't accidentally re-trigger the funnel.
    @Published var pending: Data? = nil

    func enqueue(_ data: Data) {
        pending = data
    }

    /// Atomically reads and clears the pending payload. Returns nil if
    /// nothing's queued.
    func consume() -> Data? {
        guard let data = pending else { return nil }
        pending = nil
        return data
    }
}
