//
//  OrientFormStep.swift
//  Lumoria App
//
//  Step 4 — Orient (vintage Orient-Express) variant of the form.
//  Station pickers populate city + station text fields. Class is a
//  three-tier dropdown (Business / First / Second). Sections are
//  grouped into collapsibles mirroring the Orient template's
//  `requirements` categories.
//

import SwiftUI

struct NewOrientFormStep: View {

    @ObservedObject var funnel: NewTicketFunnel

    @State private var didFireSubmit = false
    @State private var expandedItems: Set<String> = []

    var body: some View {
        VStack(spacing: 16) {
            FormPreviewTile(funnel: funnel)

            VStack(spacing: 8) {
                ForEach(categories, id: \.id) { category in
                    FormStepCollapsibleItem(
                        title: category.label,
                        isComplete: category.isComplete,
                        isExpanded: binding(for: category.id)
                    ) {
                        category.content
                    }
                }
            }
        }
        .onAppear {
            guard let template = funnel.template else { return }
            Analytics.track(.ticketFormStarted(template: template.analyticsTemplate))
        }
        .onChange(of: funnel.canAdvance) { _, ready in
            guard ready, !didFireSubmit, let template = funnel.template else { return }
            didFireSubmit = true
            Analytics.track(.ticketFormSubmitted(
                template: template.analyticsTemplate,
                fieldFillCount: countFilledFields(),
                hasOriginLocation: hasOriginLocation(),
                hasDestinationLocation: hasDestinationLocation()
            ))
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
            case "Departing & arrival cities":
                return Category(id: "cities", label: req.label, isComplete: hasCities, content: AnyView(citiesContent))
            case "Station names":
                return Category(id: "stations", label: req.label, isComplete: hasStations, content: AnyView(stationsContent))
            case "Date & departure time":
                return Category(id: "schedule", label: req.label, isComplete: hasSchedule, content: AnyView(scheduleContent))
            case "Passenger, carriage & seat":
                return Category(id: "passenger", label: req.label, isComplete: hasPassenger, content: AnyView(passengerContent))
            default:
                return nil
            }
        }
    }

    // MARK: - Completion predicates

    private var hasCities: Bool {
        let t = funnel.trainForm
        return !t.originCity.trimmingCharacters(in: .whitespaces).isEmpty
            && !t.destinationCity.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var hasStations: Bool {
        let t = funnel.trainForm
        return !t.originStation.trimmingCharacters(in: .whitespaces).isEmpty
            && !t.destinationStation.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var hasSchedule: Bool {
        let t = funnel.trainForm
        return t.dateIsSet && t.departureTimeIsSet
    }

    private var hasPassenger: Bool {
        let t = funnel.trainForm
        return !t.passenger.trimmingCharacters(in: .whitespaces).isEmpty
            && !t.car.trimmingCharacters(in: .whitespaces).isEmpty
            && !t.seat.trimmingCharacters(in: .whitespaces).isEmpty
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

    private func countFilledFields() -> Int {
        let t = funnel.trainForm
        var count = 0
        if !t.company.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !t.passenger.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !t.originStation.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !t.destinationStation.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !t.ticketNumber.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !t.originCity.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !t.destinationCity.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !t.car.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !t.seat.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !t.cabinClass.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        return count
    }

    private func hasOriginLocation() -> Bool { funnel.trainForm.originStationLocation != nil }
    private func hasDestinationLocation() -> Bool { funnel.trainForm.destinationStationLocation != nil }

    // MARK: - Cities content (carrier + station pickers)

    private var citiesContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            LumoriaInputField(
                label: "Company",
                placeholder: "Venice Simplon Orient Express",
                text: $funnel.trainForm.company,
                isRequired: true
            )

            LumoriaStationField(
                label: "Departing station",
                isRequired: true,
                assistiveText: "We’ll auto-fill the city for you.",
                selected: $funnel.trainForm.originStationLocation
            )
            .onChange(of: funnel.trainForm.originStationLocation) { _, new in
                applyStation(new, isOrigin: true)
            }

            LumoriaStationField(
                label: "Arrival station",
                isRequired: true,
                assistiveText: "We’ll auto-fill the city for you.",
                selected: $funnel.trainForm.destinationStationLocation
            )
            .onChange(of: funnel.trainForm.destinationStationLocation) { _, new in
                applyStation(new, isOrigin: false)
            }
        }
    }

    // MARK: - Stations content (display names + class)

    private var stationsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            LumoriaInputField(
                label: "Departing station name",
                placeholder: "Venezia Santa Lucia",
                text: $funnel.trainForm.originStation,
                isRequired: false
            )

            LumoriaInputField(
                label: "Arrival station name",
                placeholder: "London Victoria",
                text: $funnel.trainForm.destinationStation,
                isRequired: false
            )

            LumoriaDropdown(
                label: "Class",
                placeholder: "Choose a class",
                isRequired: false,
                options: CabinClassOption.allForTrain,
                selection: cabinClassBinding,
                selectedLabel: { $0.name }
            ) { option in
                Text(option.name)
                    .font(.body)
                    .foregroundStyle(Color.Text.primary)
            }
        }
    }

    // MARK: - Schedule content

    private var scheduleContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            LumoriaDateField(
                label: "Date",
                placeholder: "Pick a date",
                date: optionalDateBinding(
                    date: $funnel.trainForm.date,
                    isSet: $funnel.trainForm.dateIsSet
                ),
                isRequired: true
            )

            LumoriaDateField(
                label: "Departs",
                placeholder: "Pick a time",
                date: optionalDateBinding(
                    date: $funnel.trainForm.departureTime,
                    isSet: $funnel.trainForm.departureTimeIsSet
                ),
                isRequired: true,
                displayedComponents: .hourAndMinute
            )
        }
    }

    // MARK: - Passenger content

    private var passengerContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            LumoriaInputField(
                label: "Passenger name",
                placeholder: "Mlle. Dubois",
                text: $funnel.trainForm.passenger,
                isRequired: false
            )

            HStack(spacing: 12) {
                LumoriaInputField(
                    label: "Carriage",
                    placeholder: "7",
                    text: $funnel.trainForm.car,
                    isRequired: false
                )
                LumoriaInputField(
                    label: "Seat",
                    placeholder: "A",
                    text: $funnel.trainForm.seat,
                    isRequired: false
                )
            }

            LumoriaInputField(
                label: "Ticket number",
                placeholder: "0000000000",
                text: $funnel.trainForm.ticketNumber,
                isRequired: false
            )
        }
    }

    // MARK: - Station → fields sync

    private func applyStation(_ location: TicketLocation?, isOrigin: Bool) {
        guard let location else { return }
        let city = location.city ?? location.name

        if isOrigin {
            funnel.trainForm.originCity = city
            funnel.trainForm.originStation = location.name
        } else {
            funnel.trainForm.destinationCity = city
            funnel.trainForm.destinationStation = location.name
        }
    }

    // MARK: - Class dropdown binding

    private var cabinClassBinding: Binding<CabinClassOption?> {
        Binding(
            get: {
                CabinClassOption.allForTrain.first { $0.name == funnel.trainForm.cabinClass }
            },
            set: { funnel.trainForm.cabinClass = $0?.name ?? "" }
        )
    }
}
