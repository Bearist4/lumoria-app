//
//  NightFormStep.swift
//  Lumoria App
//
//  Step 4 — Night (sleeper) train variant of the form. Station pickers
//  populate city + station; the berth slot is a dropdown
//  (Lower / Middle / Upper / Single). Reuses `TrainFormInput` fields.
//  Sections are grouped into collapsibles mirroring the Night
//  template's `requirements` categories.
//

import SwiftUI

struct NewNightFormStep: View {

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
            case "Train type & code":
                return Category(id: "train", label: req.label, isComplete: hasTrain, content: AnyView(trainContent))
            case "Departure date & time":
                return Category(id: "schedule", label: req.label, isComplete: hasSchedule, content: AnyView(scheduleContent))
            case "Car, berth & passenger":
                return Category(id: "berth", label: req.label, isComplete: hasBerth, content: AnyView(berthContent))
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

    private var hasTrain: Bool {
        let t = funnel.trainForm
        return !t.company.trimmingCharacters(in: .whitespaces).isEmpty
            && !t.trainType.trimmingCharacters(in: .whitespaces).isEmpty
            && !t.trainNumber.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var hasSchedule: Bool {
        let t = funnel.trainForm
        return t.dateIsSet && t.departureTimeIsSet
    }

    private var hasBerth: Bool {
        let t = funnel.trainForm
        return !t.car.trimmingCharacters(in: .whitespaces).isEmpty
            && !t.berth.trimmingCharacters(in: .whitespaces).isEmpty
            && !t.passenger.trimmingCharacters(in: .whitespaces).isEmpty
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
        if !t.trainType.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !t.trainNumber.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !t.passenger.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !t.berth.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !t.car.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !t.ticketNumber.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !t.originCity.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !t.destinationCity.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
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

    // MARK: - Train content

    private var trainContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            LumoriaInputField(
                label: "Company",
                placeholder: "OBB Nightjet",
                text: $funnel.trainForm.company,
                isRequired: true
            )

            LumoriaInputField(
                label: "Train type",
                placeholder: "Nightjet 295",
                text: $funnel.trainForm.trainType,
                isRequired: true
            )

            LumoriaInputField(
                label: "Train code",
                placeholder: "NJ 295",
                text: $funnel.trainForm.trainNumber,
                isRequired: true
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

    // MARK: - Berth content

    private var berthContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            LumoriaInputField(
                label: "Passenger name",
                placeholder: "Jane Doe",
                text: $funnel.trainForm.passenger,
                isRequired: false
            )

            HStack(spacing: 12) {
                LumoriaInputField(
                    label: "Car",
                    placeholder: "37",
                    text: $funnel.trainForm.car,
                    isRequired: false
                )

                LumoriaDropdown(
                    label: "Berth",
                    placeholder: "Choose a berth",
                    isRequired: false,
                    options: CabinClassOption.allForBerth,
                    selection: berthBinding,
                    selectedLabel: { $0.name }
                ) { option in
                    Text(option.name)
                        .font(.body)
                        .foregroundStyle(Color.Text.primary)
                }
            }

            LumoriaInputField(
                label: "Ticket number",
                placeholder: "000000000000",
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

    // MARK: - Berth dropdown binding

    private var berthBinding: Binding<CabinClassOption?> {
        Binding(
            get: {
                CabinClassOption.allForBerth.first { $0.name == funnel.trainForm.berth }
            },
            set: { funnel.trainForm.berth = $0?.name ?? "" }
        )
    }
}
