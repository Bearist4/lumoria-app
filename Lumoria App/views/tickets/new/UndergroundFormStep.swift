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
            // Journey sits above Ticket Details in z-order so the
            // city / route dropdowns float over the next section
            // when opened. Without this, the expanded lists render
            // behind the Ticket Details header (SwiftUI draws VStack
            // children back-to-front by default).
            journeySection.zIndex(2)

            detailsSection.zIndex(1)

            if funnel.undergroundForm.originStation != nil
                && funnel.undergroundForm.destinationStation != nil
                && funnel.undergroundForm.plannedRoutes.isEmpty {
                unresolvedBanner.zIndex(0)
            }
        }
        .onAppear {
            Analytics.track(.ticketFormStarted(template: .underground))
        }
    }

    // MARK: - Journey

    private var journeySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Journey")

            cityField

            LumoriaSubwayStationField(
                label: "From",
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

            LumoriaSubwayStationField(
                label: "To",
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

            // Route picker — only shown once the router has something
            // to pick from. Hidden before the two stations feed it,
            // and hidden in the unresolved-route case (banner takes
            // over instead).
            if !funnel.undergroundForm.plannedRoutes.isEmpty {
                routeField
            }
        }
    }

    private var routeField: some View {
        LumoriaRouteDropdown(
            label: "Route",
            placeholder: "Select a route…",
            isRequired: true,
            routes: funnel.undergroundForm.plannedRoutes,
            selectedIndex: Binding(
                get: { funnel.undergroundForm.selectedRouteIndex },
                set: { funnel.undergroundForm.selectedRouteIndex = $0 }
            )
        )
    }

    private var cityField: some View {
        LumoriaDropdown(
            label: "City",
            placeholder: "Pick an available city",
            isRequired: true,
            assistiveText: "We only support a handful of cities. More will be added in the future.",
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
        case .vienna:    return "Vienna"
        case .newYork:   return "New York"
        case .paris:     return "Paris"
        case .nantes:    return "Nantes"
        case .lyon:      return "Lyon"
        case .bordeaux:  return "Bordeaux"
        case .marseille: return "Marseille"
        case .zurich:    return "Zürich"
        case .berlin:    return "Berlin"
        case .london:    return "London"
        case .stockholm: return "Stockholm"
        case .tokyo:     return "Tokyo"
        case .melbourne: return "Melbourne"
        }
    }

    private func cityFlag(for city: TransitCatalogLoader.City) -> String {
        switch city {
        case .vienna:    return "🇦🇹"
        case .newYork:   return "🇺🇸"
        case .zurich:    return "🇨🇭"
        case .berlin:    return "🇩🇪"
        case .london:    return "🇬🇧"
        case .stockholm: return "🇸🇪"
        case .tokyo:     return "🇯🇵"
        case .melbourne: return "🇦🇺"
        case .paris,
             .nantes,
             .lyon,
             .bordeaux,
             .marseille: return "🇫🇷"
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

    // MARK: - Unresolved banner

    private var unresolvedBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("We couldn't find a route between these stations.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.Text.primary)
            Text("Both stations need to be served by the same transit network. Try picking stations that share a metro, tram or bus line.")
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

