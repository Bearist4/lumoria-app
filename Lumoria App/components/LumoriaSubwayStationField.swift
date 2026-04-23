//
//  LumoriaSubwayStationField.swift
//  Lumoria App
//
//  Station picker for underground-ticket flows. Searches the bundled
//  GTFS catalog directly rather than MapKit so the suggestions are
//  guaranteed to be actual subway stations (MapKit's
//  `.publicTransport` filter is wider than we want — it returns bus
//  stops, tram stops and ferry terminals too).
//
//  Identity-based picking: each suggestion is a concrete
//  `TransitStation` from the catalog, so downstream routing resolves
//  by name + coordinate without any fuzzy reconciliation.
//

import CoreLocation
import SwiftUI

struct LumoriaSubwayStationField: View {
    var label: LocalizedStringKey
    var isRequired: Bool = true
    var placeholder: LocalizedStringKey = "Search a station"
    var assistiveText: LocalizedStringKey? = nil

    @Binding var selected: TicketLocation?

    /// Catalog to search against. When nil, the field shows no
    /// suggestions — the caller is expected to wire a catalog via a
    /// city picker. Scoping to a single catalog keeps suggestions to
    /// one operator's network so the two station fields on the form
    /// can't end up in different cities.
    let catalog: TransitCatalog?

    @State private var query: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            labelRow
            inputField

            if isFocused, !filteredStations.isEmpty {
                suggestionsList
            } else if let assistiveText, selected == nil {
                Text(assistiveText)
                    .font(.caption2)
                    .foregroundStyle(Color.Feedback.Neutral.text)
                    .lineSpacing(2)
                    .padding(.top, 2)
            }
        }
        .onChange(of: selected, initial: true) { _, sel in
            guard let sel, query.isEmpty else { return }
            query = formattedQuery(for: sel)
        }
    }

    // MARK: - Label

    private var labelRow: some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.Text.primary)
            if isRequired {
                Text(verbatim: "*")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color("Colors/Red/400"))
            }
        }
    }

    // MARK: - Input

    private var inputField: some View {
        HStack(spacing: 8) {
            Image(systemName: "tram.fill")
                .font(.subheadline)
                .foregroundStyle(Color.Text.tertiary)

            TextField(placeholder, text: $query)
                .focused($isFocused)
                .font(.body)
                .foregroundStyle(Color.Text.primary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .submitLabel(.search)
                .onSubmit { pickFirstSuggestion() }

            if !query.isEmpty {
                Button {
                    query = ""
                    selected = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(Color.Text.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 50)
        .background(Color.Background.fieldFill)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.Border.hairline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Suggestions

    private var suggestionsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(filteredStations.prefix(6).enumerated()), id: \.offset) { idx, entry in
                Button {
                    pick(entry)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        stationGlyph(lines: entry.lines)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.station.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.Text.primary)
                            Text(subtitleLabel(for: entry))
                                .font(.footnote)
                                .foregroundStyle(Color.Text.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .bottom) {
                        if idx != min(filteredStations.count, 6) - 1 {
                            Rectangle()
                                .fill(Color.Background.fieldFill)
                                .frame(height: 1)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.Background.elevated)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.Border.default, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.top, 4)
    }

    private func stationGlyph(lines: [TransitLine]) -> some View {
        let tint = lines.first.map { Color(hex: $0.color) } ?? Color.Text.secondary
        let symbol = lines.first?.resolvedMode.symbol ?? "tram.fill"
        return ZStack {
            Circle().fill(tint.opacity(0.15))
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tint)
        }
        .frame(width: 28, height: 28)
    }

    /// Comma-joined list of line codes served by the station. Bus /
    /// tram stops often have 4+ lines — cap the visible tail with an
    /// "and N more" suffix so the suggestion row doesn't grow tall.
    private func lineListLabel(_ lines: [TransitLine]) -> String {
        let head = lines.prefix(5).map(\.shortName).joined(separator: " · ")
        let extra = lines.count - 5
        return extra > 0 ? "\(head) · +\(extra)" : head
    }

    /// Subtitle that goes below the station name. When searching a
    /// single city (catalog explicitly provided), shows just the
    /// lines. When searching across every bundled catalog, prepends
    /// the city so the user can tell otherwise-identically-named
    /// stations apart.
    private func subtitleLabel(for entry: StationEntry) -> String {
        let lines = lineListLabel(entry.lines)
        return catalog == nil ? "\(entry.city) · \(lines)" : lines
    }

    // MARK: - Picking

    private func pick(_ entry: StationEntry) {
        selected = TicketLocation(
            name: entry.station.name,
            subtitle: nil,
            city: entry.city,
            country: nil,
            countryCode: nil,
            lat: entry.station.lat,
            lng: entry.station.lng,
            kind: .station
        )
        query = formattedQuery(for: selected!)
        isFocused = false
    }

    private func pickFirstSuggestion() {
        guard let first = filteredStations.first else { return }
        pick(first)
    }

    private func formattedQuery(for location: TicketLocation) -> String {
        [location.city, location.name]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    // MARK: - Search

    /// One entry per unique station (deduped by transfer key) with all
    /// the lines that serve it and the city it belongs to. The city
    /// is carried here so cross-catalog results can be disambiguated
    /// in the suggestion row ("Stephansplatz · Vienna",
    /// "Châtelet · Paris").
    private struct StationEntry {
        let station: TransitStation
        let lines: [TransitLine]
        let city: String
        let operatorName: String
    }

    @MainActor
    private var allStations: [StationEntry] {
        guard let cat = catalog else { return [] }
        var byKey: [String: StationEntry] = [:]
        for line in cat.lines {
            for station in line.stations {
                let key = TransitCatalog.transferKey(station.name)
                if var existing = byKey[key] {
                    if !existing.lines.contains(where: { $0.id == line.id }) {
                        existing = StationEntry(
                            station: existing.station,
                            lines: existing.lines + [line],
                            city: existing.city,
                            operatorName: existing.operatorName
                        )
                        byKey[key] = existing
                    }
                } else {
                    byKey[key] = StationEntry(
                        station: station,
                        lines: [line],
                        city: cat.city,
                        operatorName: cat.operatorName
                    )
                }
            }
        }
        return byKey.values.sorted {
            // Locale-aware so German umlauts sort as readers expect
            // (Ä next to A, not after Z as default String `<` would).
            $0.station.name.localizedCaseInsensitiveCompare($1.station.name) == .orderedAscending
        }
    }

    private var filteredStations: [StationEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        // Skip the "Vienna · Stephansplatz" formatted query we just
        // re-injected on pick — otherwise the list stays open and the
        // user sees their chosen station as the top suggestion.
        if let sel = selected, trimmed == formattedQuery(for: sel) { return [] }

        let needle = Self.normalize(trimmed)
        return allStations
            .filter { entry in
                let hay = Self.normalize(entry.station.name)
                return hay.contains(needle) || needle.contains(hay)
            }
            .sorted {
                $0.station.name.localizedCaseInsensitiveCompare($1.station.name) == .orderedAscending
            }
    }

    private static func normalize(_ raw: String) -> String {
        raw.folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Preview

#Preview {
    struct Host: View {
        @State var origin: TicketLocation? = nil
        @State var destination: TicketLocation? = nil
        var body: some View {
            VStack(alignment: .leading, spacing: 24) {
                LumoriaSubwayStationField(
                    label: "From",
                    assistiveText: "Pick the station you're boarding at.",
                    selected: $origin,
                    catalog: nil
                )
                LumoriaSubwayStationField(
                    label: "To",
                    assistiveText: "Pick where you're getting off.",
                    selected: $destination,
                    catalog: nil
                )
                Spacer()
            }
            .padding(24)
        }
    }
    return Host()
}
