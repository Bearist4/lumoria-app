//
//  LumoriaAirportField.swift
//  Lumoria App
//
//  Labeled search field that finds airports via MapKit. On selection the
//  binding is populated with a `TicketLocation` whose `subtitle` is the
//  IATA code, extracted from the airport's display name when possible.
//  Users can edit the IATA field after picking, in case the extraction
//  misses (regional strips, carriers that prefer an ICAO-like code, etc.).
//

import Combine
import CoreLocation
import MapKit
import SwiftUI

// MARK: - Autocomplete bridge

@MainActor
final class AirportSearchModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var query: String = "" {
        didSet { completer.queryFragment = query }
    }
    @Published var suggestions: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.resultTypes = [.pointOfInterest]
        completer.pointOfInterestFilter = MKPointOfInterestFilter(including: [.airport])
        completer.delegate = self
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            self.suggestions = completer.results
        }
    }

    /// Resolves an autocomplete suggestion into a concrete `TicketLocation`
    /// by running a full `MKLocalSearch` and reading the first map item.
    /// IATA resolution uses a cascade: regex on the MapKit-provided name,
    /// then the bundled `AirportDatabase` by coordinate, then a last-ditch
    /// fallback that takes the first three letters of the cleaned name so
    /// the field is never left blank. Returns nil only if the search
    /// itself fails.
    func resolve(_ completion: MKLocalSearchCompletion) async -> TicketLocation? {
        let request = MKLocalSearch.Request(completion: completion)
        request.resultTypes = [.pointOfInterest]
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.airport])
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            guard let item = response.mapItems.first else { return nil }
            let coord = item.placemark.coordinate
            let mapKitName = item.name ?? completion.title
            let cleanedName = Self.cleanName(mapKitName)

            // 1. Fast path — parse IATA from the MapKit-provided name.
            let parsedIATA = Self.extractIATA(from: mapKitName)

            // 2. Authoritative path — match against the static airport DB by
            // coordinate. Wins over the regex parse so "Charles de Gaulle"
            // resolves to CDG even when MapKit omits the parenthetical code.
            let dbMatch = AirportDatabase.nearest(to: coord)

            // 3. Last-resort fallback — first three letters of the cleaned
            // name, uppercased. Better than a blank code slot on the ticket;
            // the user is free to edit it later if they care.
            let resolvedIATA = dbMatch?.iata
                ?? parsedIATA
                ?? Self.fallbackIATA(from: cleanedName)

            return TicketLocation(
                name: dbMatch?.name ?? cleanedName,
                subtitle: resolvedIATA,
                city: dbMatch?.city ?? item.placemark.locality,
                country: dbMatch?.country ?? item.placemark.country,
                countryCode: dbMatch?.countryCode ?? item.placemark.isoCountryCode,
                lat: coord.latitude,
                lng: coord.longitude,
                kind: .airport
            )
        } catch {
            return nil
        }
    }

    /// First three alphabetic characters of the cleaned name, uppercased.
    /// Example: "Narita International" → "NAR". A crude guess, but keeps
    /// the code slot from reading blank when neither the regex parse nor
    /// the DB lookup resolves an IATA.
    static func fallbackIATA(from cleanedName: String) -> String? {
        let letters = cleanedName.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        guard letters.count >= 3 else { return nil }
        return String(String(String.UnicodeScalarView(letters.prefix(3))).uppercased())
    }

    /// Pulls a 3-letter uppercase code out of an airport name — covers the
    /// common "Charles de Gaulle Airport (CDG)" pattern. Returns nil if no
    /// match; the user can fill the IATA manually.
    static func extractIATA(from name: String) -> String? {
        let pattern = #"\(([A-Z]{3})\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(name.startIndex..<name.endIndex, in: name)
        guard let match = regex.firstMatch(in: name, range: range),
              let codeRange = Range(match.range(at: 1), in: name)
        else { return nil }
        return String(name[codeRange])
    }

    /// Strips a trailing "(CDG)" tag and "Airport" suffix so the stored
    /// display name reads cleanly on the ticket.
    static func cleanName(_ raw: String) -> String {
        var out = raw
        if let parenRange = out.range(of: #"\s*\([A-Z]{3}\)\s*$"#, options: .regularExpression) {
            out.removeSubrange(parenRange)
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Field

struct LumoriaAirportField: View {
    var label: LocalizedStringKey
    var isRequired: Bool = true
    var placeholder: LocalizedStringKey = "Search an airport"
    var assistiveText: LocalizedStringKey? = nil

    @Binding var selected: TicketLocation?

    @StateObject private var model = AirportSearchModel()
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
        // Sync the inner search model's query with an externally-set
        // `selected` value (e.g. from the edit-funnel prefill path). The
        // `isEmpty` guard keeps user-typed text from being clobbered.
        .onChange(of: selected, initial: true) { _, sel in
            guard let sel, model.query.isEmpty else { return }
            model.query = [sel.subtitle, sel.name]
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

    /// Leading icon in the input row — the country's flag emoji when a
    /// location is selected, otherwise a plain airplane glyph.
    @ViewBuilder
    private var leadingAffordance: some View {
        if let flag = selected?.flagEmoji {
            Text(flag)
                .font(.title3)
        } else {
            Image(systemName: "airplane")
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
                        Image(systemName: "airplane.circle.fill")
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
            model.query = [resolved.subtitle, resolved.name]
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
                LumoriaAirportField(
                    label: "From",
                    assistiveText: "Search for the departure airport.",
                    selected: $origin
                )
                LumoriaAirportField(
                    label: "To",
                    assistiveText: "Search for the arrival airport.",
                    selected: $destination
                )
                Spacer()
            }
            .padding(24)
        }
    }
    return Host()
}
