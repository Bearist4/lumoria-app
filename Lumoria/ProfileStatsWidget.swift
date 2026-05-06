//
//  ProfileStatsWidget.swift
//  Lumoria (widget)
//
//  Small stat tile that mirrors a single value from the ProfileView stats
//  grid. Reads the App Group snapshot written by `WidgetSnapshotWriter`;
//  the widget process never touches Supabase or the encryption key.
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=2010-140978
//

import SwiftUI
import WidgetKit

// MARK: - Entry

struct ProfileStatsEntry: TimelineEntry {
    let date: Date
    let configuration: ProfileStatsConfigurationIntent
    /// Resolved counts — `nil` when no snapshot has been written yet
    /// (signed-out / fresh install). The view falls back to `0` placeholders.
    let stats: WidgetProfileStats?
}

// MARK: - Provider

struct ProfileStatsProvider: AppIntentTimelineProvider {

    func placeholder(in context: Context) -> ProfileStatsEntry {
        ProfileStatsEntry(
            date: Date(),
            configuration: ProfileStatsConfigurationIntent(),
            stats: Self.sampleStats
        )
    }

    func snapshot(
        for configuration: ProfileStatsConfigurationIntent,
        in context: Context
    ) async -> ProfileStatsEntry {
        let stats = WidgetSnapshotStore.load()?.profileStats ?? Self.sampleStats
        return ProfileStatsEntry(date: Date(), configuration: configuration, stats: stats)
    }

    func timeline(
        for configuration: ProfileStatsConfigurationIntent,
        in context: Context
    ) async -> Timeline<ProfileStatsEntry> {
        let stats = WidgetSnapshotStore.load()?.profileStats
        let entry = ProfileStatsEntry(
            date: Date(),
            configuration: configuration,
            stats: stats
        )
        // Snapshot writes already trigger `WidgetCenter.reloadAllTimelines()`
        // — this fallback ensures the "this month" rollover still updates
        // even if the user never opens the app.
        let next = Calendar.current.date(byAdding: .hour, value: 6, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(next))
    }

    /// Used in the widget gallery and on first launch before the snapshot
    /// writer has run.
    private static var sampleStats: WidgetProfileStats {
        WidgetProfileStats(memoriesCount: 3, ticketsThisMonth: 24)
    }
}

// MARK: - Widget

struct ProfileStatsWidget: Widget {
    let kind: String = "ProfileStatsWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ProfileStatsConfigurationIntent.self,
            provider: ProfileStatsProvider()
        ) { entry in
            ProfileStatsWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.Background.default
                }
        }
        .configurationDisplayName("Stats")
        .description("A glance at your Lumoria activity.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

// MARK: - Entry view

struct ProfileStatsWidgetEntryView: View {
    let entry: ProfileStatsEntry

    var body: some View {
        EarlyAdopterWidgetGate {
            ZStack(alignment: .center) {
                glow
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

                VStack(alignment: .leading, spacing: 0) {
                    Text(primaryValue)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(accentColor)
                        .lineLimit(1)
                    Text(caption)
                        .font(.system(size: 19, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.Text.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                WidgetBrandBadge()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
            .padding(.vertical, 29)
            .padding(.horizontal,24)
            .widgetURL(URL(string: "lumoria://profile"))
        }
    }

    // MARK: Subviews

    private var glow: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [accentColor.opacity(0.35), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 70
                )
            )
            .frame(width: 140, height: 140)
            .blur(radius: 18)
            .offset(x: 28, y: -40)
            .allowsHitTesting(false)
    }

    // MARK: Derived

    private var statType: ProfileStatType {
        entry.configuration.statType
    }

    private var primaryValue: String {
        let stats = entry.stats ?? WidgetProfileStats(memoriesCount: 0, ticketsThisMonth: 0)
        switch statType {
        case .memoriesCreated:  return "\(stats.memoriesCount)"
        case .ticketsThisMonth: return "\(stats.ticketsThisMonth)"
        }
    }

    private var caption: String {
        switch statType {
        case .memoriesCreated:  return "memories\ncreated"
        case .ticketsThisMonth: return "tickets created\nthis month"
        }
    }

    private var accentColor: Color {
        switch statType {
        case .memoriesCreated:  return Color("Colors/Orange/400")
        case .ticketsThisMonth: return Color("Colors/Blue/400")
        }
    }
}

// MARK: - Preview

private func previewIntent(_ stat: ProfileStatType) -> ProfileStatsConfigurationIntent {
    let intent = ProfileStatsConfigurationIntent()
    intent.statType = stat
    return intent
}

#Preview("Memories", as: .systemSmall) {
    ProfileStatsWidget()
} timeline: {
    ProfileStatsEntry(
        date: .now,
        configuration: previewIntent(.memoriesCreated),
        stats: WidgetProfileStats(memoriesCount: 3, ticketsThisMonth: 24)
    )
}

#Preview("Tickets", as: .systemSmall) {
    ProfileStatsWidget()
} timeline: {
    ProfileStatsEntry(
        date: .now,
        configuration: previewIntent(.ticketsThisMonth),
        stats: WidgetProfileStats(memoriesCount: 3, ticketsThisMonth: 24)
    )
}
