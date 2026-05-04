//
//  PostFormStep.swift
//  Lumoria App
//
//  Step 4 — Post / Glow (general-purpose train) variant of the form.
//  Both templates render the same shape: train type/number, two
//  stations, a date + departure time, plus car / seat. Sections are
//  grouped into collapsibles mirroring the Post/Glow template's
//  `requirements` categories.
//

import SwiftUI

struct NewPostFormStep: View {

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
            case "Train details, car & seat":
                return Category(id: "train", label: req.label, isComplete: hasTrain, content: AnyView(trainContent))
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

    private var hasTrain: Bool {
        let t = funnel.trainForm
        return !t.trainType.trimmingCharacters(in: .whitespaces).isEmpty
            && !t.trainNumber.trimmingCharacters(in: .whitespaces).isEmpty
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
        if !t.trainType.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !t.trainNumber.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !t.originCity.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !t.destinationCity.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !t.originStation.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !t.destinationStation.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !t.car.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !t.seat.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        return count
    }

    private func hasOriginLocation() -> Bool { funnel.trainForm.originStationLocation != nil }
    private func hasDestinationLocation() -> Bool { funnel.trainForm.destinationStationLocation != nil }

    // MARK: - Cities content

    private var citiesContent: some View {
        VStack(alignment: .leading, spacing: 16) {
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

    // MARK: - Stations content

    private var stationsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            LumoriaInputField(
                label: "Departing station name",
                placeholder: "Paris Gare de Lyon",
                text: $funnel.trainForm.originStation,
                isRequired: false
            )

            LumoriaInputField(
                label: "Arrival station name",
                placeholder: "Marseille Saint-Charles",
                text: $funnel.trainForm.destinationStation,
                isRequired: false
            )
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

    // MARK: - Train content

    private var trainContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            LumoriaInputField(
                label: "Train type",
                placeholder: "TGV Inoui",
                text: $funnel.trainForm.trainType,
                isRequired: true
            )

            LumoriaInputField(
                label: "Train number",
                placeholder: "Train 12345",
                text: $funnel.trainForm.trainNumber,
                isRequired: true
            )

            HStack(spacing: 12) {
                LumoriaInputField(
                    label: "Car",
                    placeholder: "12",
                    text: $funnel.trainForm.car,
                    isRequired: false
                )
                LumoriaInputField(
                    label: "Seat",
                    placeholder: "E7",
                    text: $funnel.trainForm.seat,
                    isRequired: false
                )
            }
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
}
