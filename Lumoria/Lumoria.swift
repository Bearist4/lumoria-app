//
//  Lumoria.swift
//  Lumoria (widget)
//
//  Memory widget — small and medium variants. User picks a memory and a
//  shuffle interval; medium variant rotates 3 featured tickets per
//  timeline entry.
//

import SwiftUI
import WidgetKit

// MARK: - Entry

struct MemoryWidgetEntry: TimelineEntry {
    let date: Date
    let configuration: MemoryWidgetConfigurationIntent
    /// Memory resolved from the configured ID (or the first memory in the
    /// snapshot if none is configured). Nil when the snapshot is empty.
    let memory: WidgetMemorySnapshot?
    /// IDs of the 3 tickets featured at `date`. Medium variant renders
    /// these; small variant ignores them.
    let featuredTicketIds: [UUID]
}

// MARK: - Provider

struct MemoryWidgetProvider: AppIntentTimelineProvider {

    func placeholder(in context: Context) -> MemoryWidgetEntry {
        let sample = sampleMemory
        return MemoryWidgetEntry(
            date: Date(),
            configuration: MemoryWidgetConfigurationIntent(),
            memory: sample,
            featuredTicketIds: sample.ticketImageRefs.prefix(3).map(\.ticketId)
        )
    }

    func snapshot(
        for configuration: MemoryWidgetConfigurationIntent,
        in context: Context
    ) async -> MemoryWidgetEntry {
        // Gallery / picker previews hit this path with `isPreview == true`
        // before the user configures a memory. Fall back to the sample so
        // the drawer shows a populated widget instead of an empty shell.
        let memory = resolvedMemory(for: configuration) ?? sampleMemory
        let refs = memory.ticketImageRefs.prefix(3).map(\.ticketId)
        return MemoryWidgetEntry(
            date: Date(),
            configuration: configuration,
            memory: memory,
            featuredTicketIds: Array(refs)
        )
    }

    func timeline(
        for configuration: MemoryWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<MemoryWidgetEntry> {

        let memory = resolvedMemory(for: configuration)
        let interval = configuration.refreshInterval.seconds
        let entryCount = 12

        var entries: [MemoryWidgetEntry] = []
        let start = Date()

        for index in 0..<entryCount {
            let date = start.addingTimeInterval(Double(index) * interval)
            let featured = rotatingTicketIds(
                pool: memory?.ticketImageRefs ?? [],
                count: 3,
                // Seed per entry so the pick is deterministic (consistent
                // across placeholder / snapshot / timeline) yet different
                // every tick.
                seed: memory.map { "\($0.id.uuidString):\(Int(date.timeIntervalSince1970))" } ?? ""
            )
            entries.append(
                MemoryWidgetEntry(
                    date: date,
                    configuration: configuration,
                    memory: memory,
                    featuredTicketIds: featured
                )
            )
        }

        let reloadDate = start.addingTimeInterval(Double(entryCount) * interval)
        return Timeline(entries: entries, policy: .after(reloadDate))
    }

    // MARK: - Helpers

    private func resolvedMemory(
        for configuration: MemoryWidgetConfigurationIntent
    ) -> WidgetMemorySnapshot? {
        guard let snapshot = WidgetSnapshotStore.load() else {
            NSLog("[MemoryWidget] snapshot missing — widget will show empty state")
            return nil
        }
        if let id = configuration.memory?.id,
           let match = snapshot.memories.first(where: { $0.id == id }) {
            NSLog("[MemoryWidget] configured memory: %@ color=%@", match.name, match.colorFamily)
            return match
        }
        if let first = snapshot.memories.first {
            NSLog("[MemoryWidget] no configured memory — falling back to first: %@ color=%@", first.name, first.colorFamily)
            return first
        }
        return nil
    }

    private func rotatingTicketIds(
        pool: [WidgetTicketImageRef],
        count: Int,
        seed: String
    ) -> [UUID] {
        guard !pool.isEmpty else { return [] }
        var generator = SeededGenerator(seed: seed)
        let shuffled = pool.shuffled(using: &generator)
        return Array(shuffled.prefix(count).map(\.ticketId))
    }

    /// Fully-populated memory used by `placeholder` and as a fall-back in
    /// `snapshot` so the widget gallery always shows a realistic preview —
    /// three ticket-shaped slots, stats, category icons.
    private var sampleMemory: WidgetMemorySnapshot {
        let ticketRefs: [WidgetTicketImageRef] = [
            WidgetTicketImageRef(ticketId: UUID(), filename: "_sample_0", orientation: .vertical),
            WidgetTicketImageRef(ticketId: UUID(), filename: "_sample_1", orientation: .horizontal),
            WidgetTicketImageRef(ticketId: UUID(), filename: "_sample_2", orientation: .horizontal),
        ]
        return WidgetMemorySnapshot(
            id: UUID(),
            name: "Trip to Tokyo",
            emoji: "🗼",
            colorFamily: "Pink",
            ticketCount: 7,
            categoryStyleRawValues: ["plane", "train", "food", "museum", "publicTransit"],
            kmTotal: 9824,
            dayCount: 9,
            ticketImageRefs: ticketRefs
        )
    }
}

// MARK: - Deterministic RNG

/// Tiny splitmix64 wrapper so timeline entries shuffle reproducibly for a
/// given `(memoryId, entryDate)` — prevents visible flicker between
/// placeholder / snapshot / first timeline frame.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: String) {
        var hasher = Hasher()
        seed.hash(into: &hasher)
        self.state = UInt64(bitPattern: Int64(hasher.finalize()))
        if self.state == 0 { self.state = 0x9E3779B97F4A7C15 }
    }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// MARK: - Widget

struct MemoryWidget: Widget {
    let kind: String = "MemoryWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: MemoryWidgetConfigurationIntent.self,
            provider: MemoryWidgetProvider()
        ) { entry in
            MemoryWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Memory")
        .description("A memory and its tickets at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

// MARK: - Root entry view

struct MemoryWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MemoryWidgetEntry

    var body: some View {
        ZStack {
            if let memory = entry.memory {
                MemoryWidgetBackground(
                    memory: memory,
                    variant: family == .systemMedium ? .medium : .small
                )

                switch family {
                case .systemMedium:
                    MemoryWidgetMediumView(memory: memory, featuredTicketIds: entry.featuredTicketIds)
                default:
                    MemoryWidgetSmallView(memory: memory)
                }
            } else {
                EmptyMemoryState()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Empty state

private struct EmptyMemoryState: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "square.grid.2x2")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Create a memory to see it here")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    MemoryWidget()
} timeline: {
    MemoryWidgetEntry(
        date: .now,
        configuration: MemoryWidgetConfigurationIntent(),
        memory: WidgetMemorySnapshot(
            id: UUID(),
            name: "Trip to Tokyo",
            emoji: "🗼",
            colorFamily: "Pink",
            ticketCount: 7,
            categoryStyleRawValues: ["plane", "train", "food", "museum", "publicTransit"],
            kmTotal: 9824,
            dayCount: 9,
            ticketImageRefs: []
        ),
        featuredTicketIds: []
    )
}

#Preview(as: .systemMedium) {
    MemoryWidget()
} timeline: {
    MemoryWidgetEntry(
        date: .now,
        configuration: MemoryWidgetConfigurationIntent(),
        memory: WidgetMemorySnapshot(
            id: UUID(),
            name: "Trip to Tokyo",
            emoji: "🗼",
            colorFamily: "Pink",
            ticketCount: 7,
            categoryStyleRawValues: ["plane", "train", "food"],
            kmTotal: 9824,
            dayCount: 9,
            ticketImageRefs: []
        ),
        featuredTicketIds: []
    )
}
