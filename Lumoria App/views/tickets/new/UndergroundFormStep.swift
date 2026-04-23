//
//  UndergroundFormStep.swift
//  Lumoria App
//
//  Form step for the "Underground" public-transport template. Two
//  station pickers (region-scoped to MapKit's publicTransport POI
//  filter) feed `TransitRouter` in real time; whenever either
//  station changes the router re-runs over the bundled GTFS catalog
//  and the preview updates. Multi-leg journeys (A → C requiring an
//  A → B then B → C transfer) produce one `UndergroundTicket`
//  payload per leg, each with the correct operator-brand line
//  colour and stop count.
//

import SwiftUI

struct NewUndergroundFormStep: View {

    @ObservedObject var funnel: NewTicketFunnel

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            journeySection
            if funnel.undergroundForm.plannedRoutes.count > 1 {
                routePickerSection
            }
            detailsSection
            if !funnel.undergroundForm.plannedLegs.isEmpty {
                previewSection
            } else if funnel.undergroundForm.originStation != nil
                      && funnel.undergroundForm.destinationStation != nil {
                unresolvedBanner
            }
        }
        .onAppear {
            Analytics.track(.ticketFormStarted(template: .underground))
        }
    }

    // MARK: - Route picker

    private var routePickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Choose a route")

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                ],
                spacing: 8
            ) {
                ForEach(Array(funnel.undergroundForm.plannedRoutes.enumerated()), id: \.offset) { idx, route in
                    RouteTile(
                        route: route,
                        isSelected: funnel.undergroundForm.selectedRouteIndex == idx,
                        index: idx + 1
                    ) {
                        funnel.undergroundForm.selectedRouteIndex = idx
                    }
                }
            }
        }
    }

    // MARK: - Journey

    private var journeySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Journey")

            cityField

            LumoriaSubwayStationField(
                label: "From",
                assistiveText: funnel.undergroundForm.selectedCity == nil
                    ? "Pick a city first."
                    : "Pick the station you're boarding at.",
                selected: Binding(
                    get: { funnel.undergroundForm.originStation },
                    set: { new in
                        funnel.undergroundForm.originStation = new
                        funnel.undergroundForm.replan()
                    }
                ),
                catalog: cityCatalog
            )
            .disabled(cityCatalog == nil)
            .opacity(cityCatalog == nil ? 0.5 : 1)

            LumoriaSubwayStationField(
                label: "To",
                assistiveText: funnel.undergroundForm.selectedCity == nil
                    ? "Pick a city first."
                    : "Pick where you're getting off.",
                selected: Binding(
                    get: { funnel.undergroundForm.destinationStation },
                    set: { new in
                        funnel.undergroundForm.destinationStation = new
                        funnel.undergroundForm.replan()
                    }
                ),
                catalog: cityCatalog
            )
            .disabled(cityCatalog == nil)
            .opacity(cityCatalog == nil ? 0.5 : 1)
        }
    }

    private var cityField: some View {
        LumoriaDropdown(
            label: "City",
            placeholder: "Choose a city",
            isRequired: true,
            options: TransitCatalogLoader.City.allCases,
            selection: Binding(
                get: { funnel.undergroundForm.selectedCity },
                set: { new in
                    // Switching cities invalidates any already-picked
                    // stations — they'd belong to a different network.
                    if new != funnel.undergroundForm.selectedCity {
                        funnel.undergroundForm.originStation = nil
                        funnel.undergroundForm.destinationStation = nil
                    }
                    funnel.undergroundForm.selectedCity = new
                    funnel.undergroundForm.replan()
                }
            ),
            selectedLabel: { cityLabel(for: $0) }
        ) { city in
            HStack(spacing: 10) {
                Text(cityFlag(for: city))
                    .font(.title3)
                Text(cityLabel(for: city))
                    .font(.body)
                    .foregroundStyle(Color.Text.primary)
            }
        }
    }

    private func cityLabel(for city: TransitCatalogLoader.City) -> String {
        switch city {
        case .vienna:  return "Vienna"
        case .newYork: return "New York"
        case .paris:   return "Paris"
        }
    }

    private func cityFlag(for city: TransitCatalogLoader.City) -> String {
        switch city {
        case .vienna:  return "🇦🇹"
        case .newYork: return "🇺🇸"
        case .paris:   return "🇫🇷"
        }
    }

    /// Scopes both station pickers to whichever city the user picked
    /// up top. Nil until a city is selected — the station fields
    /// render disabled in that state.
    @MainActor
    private var cityCatalog: TransitCatalog? {
        guard let city = funnel.undergroundForm.selectedCity else { return nil }
        return TransitCatalogLoader.catalog(for: city)
    }

    // MARK: - Details

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Ticket details")

            HStack(spacing: 12) {
                dateField("Date", selection: $funnel.undergroundForm.date)
                LumoriaInputField(
                    label: "Ticket number",
                    placeholder: "Optional",
                    text: $funnel.undergroundForm.ticketNumber,
                    isRequired: false
                )
            }

            HStack(spacing: 12) {
                LumoriaInputField(
                    label: "Zones",
                    placeholder: "All zones",
                    text: $funnel.undergroundForm.zones,
                    isRequired: false
                )
                LumoriaInputField(
                    label: "Fare",
                    placeholder: "2.50 €",
                    text: $funnel.undergroundForm.fare,
                    isRequired: false
                )
            }
        }
    }

    // MARK: - Preview

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("Your journey")
                Spacer()
                Text(legCountLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.Text.secondary)
            }

            VStack(spacing: 12) {
                ForEach(Array(funnel.undergroundForm.legPayloads.enumerated()), id: \.offset) { _, payload in
                    UndergroundTicketView(ticket: payload)
                        .frame(maxWidth: 360)
                }
            }
        }
    }

    private var legCountLabel: String {
        let n = funnel.undergroundForm.plannedLegs.count
        return n == 1
            ? String(localized: "1 ticket")
            : String(localized: "\(n) tickets")
    }

    // MARK: - Unresolved banner

    private var unresolvedBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("We couldn't find a route between these stations.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.Text.primary)
            Text("Both stations need to be in a city with a bundled transit catalog (Vienna for now). Try picking stations served by the same metro network.")
                .font(.footnote)
                .foregroundStyle(Color.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.Feedback.Warning.subtle)
        )
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.title2.bold())
            .foregroundStyle(Color.Text.primary)
    }

    private func dateField(_ label: String, selection: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 0) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.Text.primary)
                Text(verbatim: "*")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.Feedback.Danger.icon)
            }
            DatePicker("", selection: selection, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 50)
                .padding(.horizontal, 12)
                .background(Color.Background.fieldFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.Border.hairline, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Route tile

/// Selectable tile summarising one alternative route: its line
/// chain, mode icons, total stops, and transfer count. Drawn as a
/// grid entry in the picker above the preview.
private struct RouteTile: View {
    let route: [TransitLeg]
    let isSelected: Bool
    let index: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                header
                lineChain
                Spacer(minLength: 0)
                footer
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 112)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isSelected
                        ? Color.Background.elevated
                        : Color.Background.fieldFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        isSelected ? Color.Text.primary : Color.Border.hairline,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Parts

    private var header: some View {
        HStack {
            Text("Option \(index)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.Text.secondary)
            Spacer(minLength: 0)
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.Text.primary)
            }
        }
    }

    private var lineChain: some View {
        HStack(spacing: 6) {
            ForEach(Array(route.enumerated()), id: \.offset) { idx, leg in
                lineChip(leg)
                if idx < route.count - 1 {
                    Image(systemName: "arrow.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.Text.tertiary)
                }
            }
        }
    }

    private func lineChip(_ leg: TransitLeg) -> some View {
        let color = Color(hex: leg.line.color)
        return HStack(spacing: 4) {
            Image(systemName: leg.line.resolvedMode.symbol)
                .font(.caption2.weight(.semibold))
            Text(leg.line.shortName)
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(color)
        )
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Label(stopsLabel, systemImage: "mappin.and.ellipse")
            Label(transferLabel, systemImage: "arrow.triangle.branch")
        }
        .font(.caption)
        .foregroundStyle(Color.Text.secondary)
        .labelStyle(.titleAndIcon)
    }

    private var totalStops: Int {
        route.reduce(0) { $0 + $1.stopsCount }
    }

    private var stopsLabel: String {
        totalStops == 1 ? "1 stop" : "\(totalStops) stops"
    }

    private var transferLabel: String {
        switch route.count {
        case 0, 1: return "Direct"
        case 2:    return "1 transfer"
        default:   return "\(route.count - 1) transfers"
        }
    }
}
