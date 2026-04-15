//
//  LumoriaLocationField.swift
//  Lumoria App
//
//  "Associated location" field used in the new-collection sheet.
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1016-20355
//
//  The field is a labeled text input that autocompletes place names through
//  `MKLocalSearchCompleter`. Picking a suggestion geocodes it and drops a pin
//  on the map shown just below the field.
//

import SwiftUI
import MapKit
import Combine

// MARK: - Selected location model

struct SelectedLocation: Equatable {
    var title: String
    var coordinate: CLLocationCoordinate2D

    static func == (a: SelectedLocation, b: SelectedLocation) -> Bool {
        a.title == b.title
            && a.coordinate.latitude == b.coordinate.latitude
            && a.coordinate.longitude == b.coordinate.longitude
    }
}

// MARK: - Autocomplete bridge

@MainActor
final class LocationSearchModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var query: String = "" {
        didSet {
            completer.queryFragment = query
        }
    }
    @Published var suggestions: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.resultTypes = [.address, .pointOfInterest]
        completer.delegate = self
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            self.suggestions = completer.results
        }
    }

    /// Resolves a completion into a concrete coordinate.
    func resolve(_ completion: MKLocalSearchCompletion) async -> SelectedLocation? {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            guard let item = response.mapItems.first else { return nil }
            let coord = item.placemark.coordinate
            let title = completion.title
            return SelectedLocation(title: title, coordinate: coord)
        } catch {
            return nil
        }
    }
}

// MARK: - Field

struct LumoriaLocationField: View {
    var label: String = "Associated location"
    var isRequired: Bool = false
    var placeholder: String = "Search a place"
    var assistiveText: String? =
        "Associate a collection to a place to display it on a map."

    @Binding var selected: SelectedLocation?

    @StateObject private var model = LocationSearchModel()
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                labelRow
                inputField
                if isFocused && !model.suggestions.isEmpty {
                    suggestionsList
                } else if let assistiveText, !assistiveText.isEmpty {
                    Text(assistiveText)
                        .font(.system(size: 11, weight: .regular))
                        .tracking(0.06)
                        .foregroundStyle(Color.Feedback.Neutral.text)
                        .lineSpacing(2)
                        .padding(.top, 2)
                }
            }
            MapPreview(location: selected)
        }
    }

    // MARK: Label

    private var labelRow: some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .tracking(-0.23)
                .foregroundStyle(Color.Text.primary)
            if isRequired {
                Text("*")
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(-0.23)
                    .foregroundStyle(Color("Colors/Red/400"))
            }
        }
    }

    // MARK: Input

    private var inputField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color.Text.tertiary)

            TextField(placeholder, text: $model.query)
                .focused($isFocused)
                .font(.system(size: 17, weight: .regular))
                .tracking(-0.43)
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
                        .font(.system(size: 16))
                        .foregroundStyle(Color.Text.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 50)
        .background(Color.black.opacity(0.03))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(0.07), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
                            .font(.system(size: 20))
                            .foregroundStyle(Color.Text.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.Text.primary)
                            if !s.subtitle.isEmpty {
                                Text(s.subtitle)
                                    .font(.system(size: 13, weight: .regular))
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
                                .fill(Color.black.opacity(0.03))
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
            model.query = resolved.title
            isFocused = false
        }
    }

    private func pickFirstSuggestion() async {
        guard let first = model.suggestions.first else { return }
        await pick(first)
    }
}

// MARK: - Map preview

struct MapPreview: View {
    let location: SelectedLocation?

    @State private var camera: MapCameraPosition =
        .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 48.2082, longitude: 16.3738), // Vienna default
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        ))

    var body: some View {
        Map(position: $camera, interactionModes: []) {
            if let location {
                Annotation(location.title, coordinate: location.coordinate) {
                    MapPin()
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .all))
        .frame(height: 171)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .onChange(of: location) { _, new in
            guard let new else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                camera = .region(MKCoordinateRegion(
                    center: new.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                ))
            }
        }
    }
}

// MARK: - Pin

private struct MapPin: View {
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(Color.Button.Primary.Background.default)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Circle().stroke(.white, lineWidth: 4)
                    )

                Image(systemName: "figure.walk")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Triangle()
                .fill(.white)
                .frame(width: 10, height: 6)
                .offset(y: -1)
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Preview

#Preview {
    struct Demo: View {
        @State var loc: SelectedLocation? = nil
        var body: some View {
            LumoriaLocationField(selected: $loc)
                .padding(24)
        }
    }
    return Demo()
}
