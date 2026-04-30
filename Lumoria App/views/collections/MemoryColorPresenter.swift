//
//  MemoryColorPresenter.swift
//  Lumoria App
//
//  Hoists the memory color picker to the root TabView so the floating
//  bottom-sheet layers above the iOS 26 floating glass tab bar.
//  Mirrors `MemorySortPresenter`. The buffered-edit caller registers
//  the initial color + a closure to receive the picked color; the
//  presenter owns the lifecycle.
//

import Combine
import Foundation

@MainActor
final class MemoryColorPresenter: ObservableObject {
    @Published var initialColor: ColorOption?
    private(set) var onCommit: ((ColorOption) -> Void)?

    var isPresented: Bool { initialColor != nil }

    func present(
        initialColor: ColorOption,
        onCommit: @escaping (ColorOption) -> Void
    ) {
        self.initialColor = initialColor
        self.onCommit = onCommit
    }

    func dismiss() {
        self.initialColor = nil
        self.onCommit = nil
    }
}
