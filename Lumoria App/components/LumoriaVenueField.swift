//
//  LumoriaVenueField.swift
//  Lumoria App
//
//  Venue search field used by single-venue templates (concerts, etc.).
//  Mirrors `LumoriaStationField` but searches the full POI catalog so
//  stadiums, arenas, theatres, clubs and parks all surface. On pick the
//  binding is populated with a `TicketLocation` whose `kind == .venue`.
//

import Combine
import CoreLocation
import MapKit
import SwiftUI

// MARK: - Autocomplete bridge

@MainActor
final class VenueSearchModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var query: String = "" {
        didSet { completer.queryFragment = query }
    }
    @Published var suggestions: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        // No POI category filter — concert venues span stadiums,
        // theaters, clubs, parks and more. Letting MapKit bring back
        // anything POI-shaped plus address results maps the user's
        // mental model best ("O2 Arena", "Madison Square Garden",
        // "Hyde Park" all work).
        completer.resultTypes = [.pointOfInterest]
        completer.delegate = self
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            self.suggestions = completer.results
        }
    }

    /// Resolves a suggestion into a `TicketLocation` with `kind == .venue`.
    /// The resolved name is used as-is — venue names are already the
    /// marketing brand in most cases ("O2 Arena", "Accor Arena"), so we
    /// don't strip suffixes like the station field does.
    func resolve(_ completion: MKLocalSearchCompletion) async -> TicketLocation? {
        let request = MKLocalSearch.Request(completion: completion)
        request.resultTypes = [.pointOfInterest]
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            guard let item = response.mapItems.first else { return nil }
            let coord = item.placemark.coordinate
            let name = (item.name ?? completion.title)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return TicketLocation(
                name: name,
                subtitle: nil,
                city: item.placemark.locality,
                country: item.placemark.country,
                countryCode: item.placemark.isoCountryCode,
                lat: coord.latitude,
                lng: coord.longitude,
                kind: .venue
            )
        } catch {
            return nil
        }
    }
}

// MARK: - Field

struct LumoriaVenueField: View {
    var label: LocalizedStringKey
    var isRequired: Bool = true
    var placeholder: LocalizedStringKey = "Search a venue"
    var assistiveText: LocalizedStringKey? = nil

    @Binding var selected: TicketLocation?

    @StateObject private var model = VenueSearchModel()
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
        // Keep the text field in sync with an externally-set
        // `selected` value (e.g. the edit-flow prefill).
        .onChange(of: selected, initial: true) { _, sel in
            guard let sel, model.query.isEmpty else { return }
            model.query = [sel.city, sel.name]
                .compactMap { $0 }
                .joined(separator: " · ")
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
            Image(systemName: "music.mic")
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
                        Image(systemName: "mappin.circle.fill")
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
        @State var venue: TicketLocation? = nil
        var body: some View {
            VStack(alignment: .leading, spacing: 24) {
                LumoriaVenueField(
                    label: "Venue",
                    assistiveText: "Search for the concert venue.",
                    selected: $venue
                )
                if let venue {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(venue.name).font(.headline)
                        Text(venue.city ?? "—").foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(24)
        }
    }
    return Host()
}
