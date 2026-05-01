//
//  ShareImportCoordinator.swift
//  Lumoria App
//
//  Carries a parsed share-extension payload from the app-root drain
//  handler down to AllTicketsView, which presents the new-ticket
//  funnel pre-filled. Mirrors WalletImportCoordinator's one-shot
//  consume pattern.
//

import Combine
import Foundation

@MainActor
final class ShareImportCoordinator: ObservableObject {

    @Published var pending: ShareImportResult?

    func enqueue(_ result: ShareImportResult) {
        pending = result
    }

    func consume() -> ShareImportResult? {
        guard let result = pending else { return nil }
        pending = nil
        return result
    }
}
