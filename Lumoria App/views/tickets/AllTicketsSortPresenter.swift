//
//  AllTicketsSortPresenter.swift
//  Lumoria App
//
//  Hoists the All tickets sort sheet to the root TabView so the
//  floating bottom sheet layers above the iOS 26 floating glass tab
//  bar — same pattern as `MemorySortPresenter` and
//  `MemoryColorPresenter`. Also owns the live sort selection so
//  `AllTicketsView` and the sheet read from a single source of truth.
//

import Combine
import Foundation

@MainActor
final class AllTicketsSortPresenter: ObservableObject {
    @Published var isPresented: Bool = false
    @Published var field: AllTicketsSortField?
    /// Direction toggle for date-keyed fields. Ignored for category
    /// fields whose direction is part of the field name (A-Z / Z-A).
    @Published var ascending: Bool = false  // newest first feels right for a gallery default

    func present() {
        isPresented = true
    }

    func dismiss() {
        isPresented = false
    }

    func commit(field: AllTicketsSortField?, ascending: Bool) {
        self.field = field
        self.ascending = ascending
    }
}
