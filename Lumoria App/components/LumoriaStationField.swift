//
//  LumoriaStationField.swift
//  Lumoria App
//
//  Train-station search field. Mirrors `LumoriaAirportField` but uses
//  MapKit's `.publicTransport` POI filter so suggestions are stations
//  and stops rather than airports. On selection the binding is
//  populated with a `TicketLocation` whose `kind == .station`; the
//  station *name* maps to `location.name`, and the surrounding city
//  maps to `location.city` for downstream rendering.
//

import Combine
import CoreLocation
import MapKit
import SwiftUI

// MARK: - Autocomplete bridge

@MainActor
final class StationSearchModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var query: String = "" {
        didSet { completer.queryFragment = query }
    }
    @Published var suggestions: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.resultTypes = [.pointOfInterest]
        completer.pointOfInterestFilter = MKPointOfInterestFilter(including: [.publicTransport])
        completer.delegate = self
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            self.suggestions = completer.results
        }
    }

    /// Resolves an autocomplete suggestion into a concrete `TicketLocation`.
    /// Station naming conventions vary wildly — MapKit may return
    /// "Venice Santa Lucia", "Gare de Lyon", "Shinjuku Station", etc. —
    /// so we keep the raw name and let the caller derive a station
    /// "short name" by stripping the city prefix when helpful.
    func resolve(_ completion: MKLocalSearchCompletion) async -> TicketLocation? {
        let request = MKLocalSearch.Request(completion: completion)
        request.resultTypes = [.pointOfInterest]
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.publicTransport])
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            guard let item = response.mapItems.first else { return nil }
            let coord = item.placemark.coordinate
            let name = Self.cleanName(item.name ?? completion.title)

            return TicketLocation(
                name: name,
                subtitle: nil,
                city: item.placemark.locality,
                country: item.placemark.country,
                countryCode: item.placemark.isoCountryCode,
                lat: coord.latitude,
                lng: coord.longitude,
                kind: .station
            )
        } catch {
            return nil
        }
    }

    /// Strips a trailing " Station" / " Railway Station" suffix for a
    /// cleaner display name on the ticket. Also trims whitespace.
    static func cleanName(_ raw: String) -> String {
        var out = raw
        for suffix in [" Railway Station", " Train Station", " Station"] {
            if out.hasSuffix(suffix) {
                out = String(out.dropLast(suffix.count))
                break
            }
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Field

struct LumoriaStationField: View {
    var label: LocalizedStringKey
    var isRequired: Bool = true
    var placeholder: LocalizedStringKey = "Search a station"
    var assistiveText: LocalizedStringKey? = nil

    @Binding var selected: TicketLocation?

    @StateObject private var model = StationSearchModel()
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            labelRow
            inputField
            if isFocused && !model.suggestions.isEmpty {
                suggestionsList
            } else if let assistiveText, selected == nil {
                Text(assistiveText)
                    .font(.caption2)
                    .foregroundStyle(Color.Feedback.Neutral.text)
                    .lineSpacing(2)
                    .padding(.top, 2)
            }
        }
    }

    // MARK: Label

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

    // MARK: Input

    private var inputField: some View {
        HStack(spacing: 8) {
            leadingAffordance

            TextField(placeholder, text: $model.query)
                .focused($isFocused)
                .font(.body)
                .foregroundStyle(Color.Text.primary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .submitLabel(.search)
                .onSubmit { Task { await pickFirstSuggestion() } }

            if !model.query.isEmpty {
                Button {
                    model.query = ""
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

    @ViewBuilder
    private var leadingAffordance: some View {
        if let flag = selected?.flagEmoji {
            Text(flag)
                .font(.title3)
        } else {
            Image(systemName: "tram.fill")
                .font(.subheadline)
                .foregroundStyle(Color.Text.tertiary)
        }
    }

    // MARK: Suggestions

    private var suggestionsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(model.suggestions.prefix(5).enumerated()), id: \.offset) { idx, s in
                Button {
                    Task { await pick(s) }
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "tram.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.Text.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.Text.primary)
                            if !s.subtitle.isEmpty {
                                Text(s.subtitle)
                                    .font(.footnote)
                                    .foregroundStyle(Color.Text.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .bottom) {
                        if idx != min(model.suggestions.count, 5) - 1 {
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

    // MARK: Picking

    private func pick(_ suggestion: MKLocalSearchCompletion) async {
        if let resolved = await model.resolve(suggestion) {
            selected = resolved
            model.query = [resolved.city, resolved.name]
                .compactMap { $0 }
                .joined(separator: " · ")
            isFocused = false
        }
    }

    private func pickFirstSuggestion() async {
        guard let first = model.suggestions.first else { return }
        await pick(first)
    }
}

// MARK: - Preview

#Preview {
    struct Host: View {
        @State var origin: TicketLocation? = nil
        @State var destination: TicketLocation? = nil
        var body: some View {
            VStack(alignment: .leading, spacing: 24) {
                LumoriaStationField(
                    label: "From",
                    assistiveText: "Search for the departure station.",
                    selected: $origin
                )
                LumoriaStationField(
                    label: "To",
                    assistiveText: "Search for the arrival station.",
                    selected: $destination
                )
                Spacer()
            }
            .padding(24)
        }
    }
    return Host()
}
