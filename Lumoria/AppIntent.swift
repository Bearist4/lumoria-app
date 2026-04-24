//
//  AppIntent.swift
//  Lumoria
//
//  Configuration intent for the Memory widget: the user picks which
//  memory to surface and how often the medium variant re-shuffles its
//  featured tickets.
//

import AppIntents
import WidgetKit

// MARK: - Refresh cadence

enum MemoryWidgetRefreshInterval: String, AppEnum {
    case tenMinutes  = "ten_minutes"
    case thirtyMinutes = "thirty_minutes"
    case oneHour     = "one_hour"

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Shuffle every")
    }

    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .tenMinutes:    DisplayRepresentation(title: "10 minutes"),
        .thirtyMinutes: DisplayRepresentation(title: "30 minutes"),
        .oneHour:       DisplayRepresentation(title: "1 hour"),
    ]

    /// Seconds between timeline entries.
    var seconds: TimeInterval {
        switch self {
        case .tenMinutes:    return 10 * 60
        case .thirtyMinutes: return 30 * 60
        case .oneHour:       return 60 * 60
        }
    }
}

// MARK: - Memory picker entity

/// Lightweight entity surfaced to the widget configuration picker. Loaded
/// from the shared App Group snapshot written by the main app.
struct MemoryWidgetEntity: AppEntity {
    let id: UUID
    let name: String
    let colorFamily: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Memory")
    }

    static var defaultQuery = MemoryWidgetEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct MemoryWidgetEntityQuery: EntityQuery {

    func entities(for identifiers: [MemoryWidgetEntity.ID]) async throws -> [MemoryWidgetEntity] {
        loadAll().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [MemoryWidgetEntity] {
        loadAll()
    }

    func defaultResult() async -> MemoryWidgetEntity? {
        loadAll().first
    }

    private func loadAll() -> [MemoryWidgetEntity] {
        WidgetSnapshotStore.load()?.memories.map {
            MemoryWidgetEntity(id: $0.id, name: $0.name, colorFamily: $0.colorFamily)
        } ?? []
    }
}

// MARK: - Configuration intent

struct MemoryWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Memory Widget" }
    static var description: IntentDescription {
        IntentDescription("Pick a memory and how often the featured tickets shuffle.")
    }

    @Parameter(title: "Memory")
    var memory: MemoryWidgetEntity?

    @Parameter(title: "Shuffle every", default: .thirtyMinutes)
    var refreshInterval: MemoryWidgetRefreshInterval
}
