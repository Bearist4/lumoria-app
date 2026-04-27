//
//  MapPreferencesView.swift
//  Lumoria App
//
//  App-wide preferences that control how the memory map looks and
//  behaves: which base map style to render, whether to show Apple
//  Maps' points-of-interest labels, the distance unit used in the map
//  stats card, and whether camera transitions between timeline stops
//  should be damped to respect reduced-motion needs.
//
//  Persisted via `@AppStorage` keys prefixed `map.` so they can be
//  read from anywhere in the app (see `MapPreferences` helper).
//

import SwiftUI
import MapKit
import WidgetKit

// MARK: - Preference values

enum MapDistanceUnit: String, CaseIterable, Identifiable {
    case km
    case mi

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .km: return String(localized: "Kilometers")
        case .mi: return String(localized: "Miles")
        }
    }

    /// Short unit label used in the stats card.
    var shortLabel: String {
        switch self {
        case .km: return String(localized: "km")
        case .mi: return String(localized: "mi")
        }
    }

    /// Converts a kilometer distance to this unit.
    func format(km value: Double) -> Double {
        switch self {
        case .km: return value
        case .mi: return value * 0.621_371
        }
    }
}

enum MapStylePref: String, CaseIterable, Identifiable {
    case standard
    case hybrid

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard: return String(localized: "Standard")
        case .hybrid:   return String(localized: "Satellite")
        }
    }
}

// MARK: - Lightweight accessor

/// Read-only facade over the `map.*` `@AppStorage` keys. Views that
/// want to react to preference changes should use the `@AppStorage`
/// property wrappers directly; this helper is for one-shot reads.
enum MapPreferences {
    static var distanceUnit: MapDistanceUnit {
        // Same App Group store the @AppStorage binding writes to —
        // keeps in-app one-shot reads (e.g. journey stats) in lockstep
        // with the widget.
        let raw = WidgetSharedContainer.sharedDefaults.string(forKey: "map.distanceUnit")
            ?? MapDistanceUnit.km.rawValue
        return MapDistanceUnit(rawValue: raw) ?? .km
    }

    static var style: MapStylePref {
        let raw = UserDefaults.standard.string(forKey: "map.style")
            ?? MapStylePref.standard.rawValue
        return MapStylePref(rawValue: raw) ?? .standard
    }

    static var showPOIs: Bool {
        if UserDefaults.standard.object(forKey: "map.showPOIs") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "map.showPOIs")
    }

    static var reduceMotion: Bool {
        UserDefaults.standard.bool(forKey: "map.reduceMotion")
    }
}

// MARK: - View

struct MapPreferencesView: View {

    @Environment(\.dismiss) private var dismiss

    // Distance unit lives in the App Group suite so the Memory widget
    // can read it and format its `km` stat in miles when the user picks
    // imperial. The other map prefs stay in standard defaults — they
    // only affect in-app surfaces.
    @AppStorage("map.distanceUnit", store: WidgetSharedContainer.sharedDefaults)
    private var distanceUnitRaw: String = MapDistanceUnit.km.rawValue
    @AppStorage("map.style")        private var mapStyleRaw:    String = MapStylePref.standard.rawValue
    @AppStorage("map.showPOIs")     private var showPOIs:       Bool   = true
    @AppStorage("map.reduceMotion") private var reduceMotion:   Bool   = false

    private var distanceUnit: MapDistanceUnit {
        MapDistanceUnit(rawValue: distanceUnitRaw) ?? .km
    }

    private var mapStyle: MapStylePref {
        MapStylePref(rawValue: mapStyleRaw) ?? .standard
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                topBar
                    .padding(.top, 6)

                Text("Map")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color.Text.primary)

                distanceUnitSection
                mapStyleSection
                mapLabelsSection
                motionSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 120)
        }
        .background(Color.Background.default.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: distanceUnitRaw) { _, _ in
            // Widgets don't observe `UserDefaults` — kick a timeline
            // refresh so the Memory widget's km/mi label flips on the
            // home screen as soon as the toggle changes.
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            LumoriaIconButton(
                systemImage: "chevron.left",
                position: .onBackground
            ) { dismiss() }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Distance unit

    private var distanceUnitSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Distance")
            descriptionCard(
                title: "Use miles",
                subtitle: "Show distances in miles instead of kilometers.",
                control: {
                    Toggle(
                        "",
                        isOn: Binding(
                            get: { distanceUnit == .mi },
                            set: { distanceUnitRaw = ($0 ? MapDistanceUnit.mi : .km).rawValue }
                        )
                    )
                    .labelsHidden()
                    .tint(Color("Colors/Green/500"))
                }
            )
        }
    }

    // MARK: - Map style

    private var mapStyleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Map style")

            HStack(spacing: 8) {
                ForEach(MapStylePref.allCases) { style in
                    MapStyleTile(
                        style: style,
                        isSelected: style == mapStyle
                    ) {
                        mapStyleRaw = style.rawValue
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Labels

    private var mapLabelsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Labels")
            descriptionCard(
                title: "Points of interest",
                subtitle: "Show shops, landmarks, and transit labels on the map.",
                control: {
                    Toggle("", isOn: $showPOIs)
                        .labelsHidden()
                        .tint(Color("Colors/Green/500"))
                }
            )
        }
    }

    // MARK: - Motion

    private var motionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Motion")
            descriptionCard(
                title: "Reduce motion",
                subtitle: "Shorten camera transitions and pin pop animations on the map.",
                control: {
                    Toggle("", isOn: $reduceMotion)
                        .labelsHidden()
                        .tint(Color("Colors/Green/500"))
                }
            )
        }
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.title3.bold())
            .foregroundStyle(Color.Text.primary)
    }

    private func descriptionCard<Control: View>(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(Color.Text.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            control()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.Background.elevated)
        )
    }
}

// MARK: - Map style tile

private struct MapStyleTile: View {
    let style: MapStylePref
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                preview
                    .frame(height: 100)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.Text.primary : Color.Border.hairline,
                                lineWidth: isSelected ? 2 : 1
                            )
                    )

                Text(style.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.Text.primary)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.Background.elevated)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var preview: some View {
        // Tiny live MapKit preview — gives a real sense of how each
        // style looks on the actual map surfaces (Memory Map, ticket
        // detail) instead of a flat decorative gradient.
        Map(initialPosition: .region(MapStyleTile.previewRegion)) { }
            .mapStyle(style == .standard ? .standard : .hybrid)
            .allowsHitTesting(false)
    }

    /// Centred over Paris so both styles have something recognisable
    /// — streets and the river for standard, terrain and tile mosaic
    /// for satellite.
    private static let previewRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 48.858, longitude: 2.347),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MapPreferencesView()
    }
}
