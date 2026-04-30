//
//  MemorySortApplier.swift
//  Lumoria App
//
//  Pure sort over a memory's tickets. Date-keyed sorts (.dateAdded /
//  .eventDate / .dateCreated) and the manual int-keyed sort (.manual)
//  share the same nil-bucketing rule: nils go last in either direction.
//

import Foundation

enum MemorySortApplier {

    static func apply(
        _ tickets: [Ticket],
        field: MemorySortField,
        ascending: Bool,
        memoryId: UUID
    ) -> [Ticket] {
        switch field {
        case .manual:
            return manual(tickets, ascending: ascending, memoryId: memoryId)
        case .dateAdded, .eventDate, .dateCreated:
            return byDate(tickets, field: field, ascending: ascending, memoryId: memoryId)
        }
    }

    // MARK: - Date-keyed sort

    private static func byDate(
        _ tickets: [Ticket],
        field: MemorySortField,
        ascending: Bool,
        memoryId: UUID
    ) -> [Ticket] {
        tickets.sorted { lhs, rhs in
            let l = dateKey(for: lhs, field: field, memoryId: memoryId)
            let r = dateKey(for: rhs, field: field, memoryId: memoryId)
            switch (l, r) {
            case (nil, nil):
                return lhs.id.uuidString < rhs.id.uuidString
            case (nil, _): return false
            case (_, nil): return true
            case let (lDate?, rDate?):
                if lDate == rDate {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return ascending ? lDate < rDate : lDate > rDate
            }
        }
    }

    private static func dateKey(
        for ticket: Ticket,
        field: MemorySortField,
        memoryId: UUID
    ) -> Date? {
        switch field {
        case .dateAdded:   return ticket.addedAtByMemory[memoryId]
        case .eventDate:   return ticket.eventDate
        case .dateCreated: return ticket.createdAt
        case .manual:      return nil // unreachable — handled above
        }
    }

    // MARK: - Manual sort

    private static func manual(
        _ tickets: [Ticket],
        ascending: Bool,
        memoryId: UUID
    ) -> [Ticket] {
        tickets.sorted { lhs, rhs in
            let l = lhs.displayOrderByMemory[memoryId]
            let r = rhs.displayOrderByMemory[memoryId]
            switch (l, r) {
            case (nil, nil):
                return lhs.id.uuidString < rhs.id.uuidString
            case (nil, _): return false
            case (_, nil): return true
            case let (lOrder?, rOrder?):
                if lOrder == rOrder {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return ascending ? lOrder < rOrder : lOrder > rOrder
            }
        }
    }
}
