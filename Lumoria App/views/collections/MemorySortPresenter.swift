//
//  MemorySortPresenter.swift
//  Lumoria App
//
//  Hoists the memory sort sheet to the root TabView so it can layer
//  above the iOS 26 floating glass tab bar. Per-memory detail views
//  call `present(memoryId:)` to open it; ContentView reads the
//  presenter and renders the actual `.floatingBottomSheet`.
//

import Combine
import Foundation

@MainActor
final class MemorySortPresenter: ObservableObject {
    /// The memory whose sort prefs are being edited. Nil = sheet hidden.
    @Published var memoryId: UUID?

    func present(memoryId: UUID) {
        self.memoryId = memoryId
    }

    func dismiss() {
        self.memoryId = nil
    }
}
