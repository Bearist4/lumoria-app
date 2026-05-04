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
//  colour and stop count. Sections are grouped into collapsibles
//  mirroring the Underground template's `requirements` categories.
//

import SwiftUI

struct NewUndergroundFormStep: View {

    @ObservedObject var funnel: NewTicketFunnel

    @State private var expandedItems: Set<String> = []

    var body: some View {
        VStack(spacing: 16) {
            FormPreviewTile(funnel: funnel)

            VStack(spacing: 8) {
                ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                    FormStepCollapsibleItem(
                        title: category.label,
                        isComplete: category.isComplete,
                        isExpanded: binding(for: category.id)
                    ) {
                        category.content
                    }
                    // Earlier categories sit higher in z-order so the
                    // city / route dropdowns float over the next
                    // collapsible when opened.
                    .zIndex(Double(categories.count - index))
                }

                if funnel.undergroundForm.originStation != nil
                    && funnel.undergroundForm.destinationStation != nil
                    && funnel.undergroundForm.plannedRoutes.isEmpty {
                    unresolvedBanner.zIndex(0)
                }
            }
        }
        .onAppear {
            Analytics.track(.ticketFormStarted(template: .underground))
        }
    }

    // MARK: - Categories

    private struct Category {
        let id: String
        let label: String
        let isComplete: Bool
        let content: AnyView
    }

    private var categories: [Category] {
        (funnel.template?.requirements ?? []).compactMap { req in
            switch req.label {
            case "Origin & destination stations":
                return Category(id: "stations", label: req.label, isComplete: hasStations, content: AnyView(stationsContent))
            case "Line (auto-detected)":
                return Category(id: "line", label: req.label, isComplete: hasRoute, content: AnyView(lineContent))
            case "Date of travel":
                return Category(id: "date", label: req.label, isComplete: funnel.undergroundForm.dateIsSet, content: AnyView(dateContent))
            case "Ticket number, zones, fare":
                return Category(id: "ticket", label: req.label, isComplete: hasTicket, content: AnyView(ticketContent))
            default:
                return nil
            }
        }
    }

    // MARK: - Completion predicates

    private var hasStations: Bool {
        funnel.undergroundForm.selectedCity != nil
            && funnel.undergroundForm.originStation != nil
            && funnel.undergroundForm.destinationStation != nil
    }

    private var hasRoute: Bool {
        funnel.undergroundForm.selectedRouteIndex != nil
            && !funnel.undergroundForm.plannedRoutes.isEmpty
    }

    private var hasTicket: Bool {
        let f = funnel.undergroundForm
        return !f.ticketNumber.trimmingCharacters(in: .whitespaces).isEmpty
            || !f.zones.trimmingCharacters(in: .whitespaces).isEmpty
            || !f.fare.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func binding(for id: String) -> Binding<Bool> {
        Binding(
            get: { expandedItems.contains(id) },
            set: { isOn in
                if isOn { expandedItems.insert(id) }
                else    { expandedItems.remove(id) }
            }
        )
    }

    // MARK: - Stations content (city + from + to)

    private var stationsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
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
        }
    }

    // MARK: - Line / route content

    @ViewBuilder
    private var lineContent: some View {
        if funnel.undergroundForm.plannedRoutes.isEmpty {
            Text("Pick both stations first — we’ll auto-detect the line.")
                .font(.footnote)
                .foregroundStyle(Color.Text.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
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

    // MARK: - Date content

    private var dateContent: some View {
        LumoriaDateField(
            label: "Date",
            placeholder: "Pick a date",
            date: optionalDateBinding(
                date: $funnel.undergroundForm.date,
                isSet: $funnel.undergroundForm.dateIsSet
            ),
            isRequired: true
        )
    }

    // MARK: - Ticket content

    private var ticketContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            LumoriaInputField(
                label: "Ticket number",
                placeholder: "Optional",
                text: $funnel.undergroundForm.ticketNumber,
                isRequired: false
            )

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
}
