//
//  LumoriaCinemaField.swift
//  Lumoria App
//
//  Cinema search field used by the Lumiere movie template. Mirrors
//  `LumoriaVenueField` but restricts MapKit's autocomplete to movie-
//  theater POIs so the picker doesn't surface unrelated venues
//  (stadiums, parks, restaurants). On pick the binding is populated
//  with a `TicketLocation` whose `kind == .venue`.
//

import Combine
import CoreLocation
import MapKit
import SwiftUI

// MARK: - Autocomplete bridge

@MainActor
final class CinemaSearchModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var query: String = "" {
        didSet { completer.queryFragment = query }
    }
    @Published var suggestions: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.resultTypes = [.pointOfInterest]
        completer.pointOfInterestFilter = MKPointOfInterestFilter(
            including: [.movieTheater]
        )
        completer.delegate = self
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            self.suggestions = completer.results
        }
    }

    /// Resolves a suggestion into a `TicketLocation` with `kind == .venue`.
    /// Cinema names are usually their marketing brand verbatim (e.g.
    /// "Pathé Beaugrenelle", "AMC Empire 25"), so we use the resolved
    /// name as-is rather than splitting brand / location.
    func resolve(_ completion: MKLocalSearchCompletion) async -> TicketLocation? {
        let request = MKLocalSearch.Request(completion: completion)
        request.resultTypes = [.pointOfInterest]
        request.pointOfInterestFilter = MKPointOfInterestFilter(
            including: [.movieTheater]
        )
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

struct LumoriaCinemaField: View {
    var label: LocalizedStringKey
    var isRequired: Bool = true
    var placeholder: LocalizedStringKey = "Search a cinema"
    var assistiveText: LocalizedStringKey? = nil
    /// Optional seed text shown when the user hasn't picked a cinema
    /// yet. Used by the edit-flow prefill so a pre-existing string lands
    /// in the search field instead of a blank input.
    var initialQuery: String? = nil

    @Binding var selected: TicketLocation?

    @StateObject private var model = CinemaSearchModel()
    @FocusState private var isFocused: Bool
    @State private var didSeedInitialQuery = false

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
        .onChange(of: selected, initial: true) { _, sel in
            guard let sel, model.query.isEmpty else { return }
            model.query = [sel.city, sel.name]
                .compactMap { $0 }
                .joined(separator: " · ")
        }
        .onAppear {
            guard !didSeedInitialQuery,
                  let initial = initialQuery?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                  !initial.isEmpty,
                  selected == nil,
                  model.query.isEmpty else {
                didSeedInitialQuery = true
                return
            }
            model.query = initial
            didSeedInitialQuery = true
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
                    .foregroundStyle(Color.Feedback.Danger.border)
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
            Image(systemName: "popcorn.fill")
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
                        Image(systemName: "popcorn.fill")
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
        @State var cinema: TicketLocation? = nil
        var body: some View {
            VStack(alignment: .leading, spacing: 24) {
                LumoriaCinemaField(
                    label: "Cinema",
                    assistiveText: "Search for the cinema you’re going to.",
                    selected: $cinema
                )
                if let cinema {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(cinema.name).font(.headline)
                        Text(cinema.city ?? "—").foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(24)
        }
    }
    return Host()
}
