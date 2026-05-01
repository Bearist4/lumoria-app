//
//  MemoryEmojiPresenter.swift
//  Lumoria App
//
//  Hoists the memory emoji picker to the root TabView so the floating
//  bottom-sheet layers above the iOS 26 floating glass tab bar.
//  Mirrors `MemoryColorPresenter`.
//

import Combine
import Foundation

@MainActor
final class MemoryEmojiPresenter: ObservableObject {
    @Published private(set) var isPresented: Bool = false
    private(set) var initialEmoji: String?
    private(set) var onCommit: ((String?) -> Void)?

    func present(
        initialEmoji: String?,
        onCommit: @escaping (String?) -> Void
    ) {
        self.initialEmoji = initialEmoji
        self.onCommit = onCommit
        self.isPresented = true
    }

    func dismiss() {
        self.isPresented = false
        self.initialEmoji = nil
        self.onCommit = nil
    }
}
