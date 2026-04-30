//
//  MemorySortApplier.swift
//  Lumoria App
//
//  Pure sort over a memory's tickets. Nil dates always bucket last so a
//  lone undated ticket doesn't dominate the top of the list.
//

import Foundation

enum MemorySortApplier {

    static func apply(
        _ tickets: [Ticket],
        field: MemorySortField,
        ascending: Bool,
        memoryId: UUID
    ) -> [Ticket] {
        tickets.sorted { lhs, rhs in
            let l = key(for: lhs, field: field, memoryId: memoryId)
            let r = key(for: rhs, field: field, memoryId: memoryId)

            // Nil keys go last in either direction.
            switch (l, r) {
            case (nil, nil):
                return lhs.id.uuidString < rhs.id.uuidString
            case (nil, _):
                return false
            case (_, nil):
                return true
            case let (lDate?, rDate?):
                if lDate == rDate {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return ascending ? lDate < rDate : lDate > rDate
            }
        }
    }

    private static func key(
        for ticket: Ticket,
        field: MemorySortField,
        memoryId: UUID
    ) -> Date? {
        switch field {
        case .dateAdded:   return ticket.addedAtByMemory[memoryId]
        case .eventDate:   return ticket.eventDate
        case .dateCreated: return ticket.createdAt
        }
    }
}
