//
//  TrainFormStep.swift
//  Lumoria App
//
//  Step 4 — Express (train) variant of the form. Station pickers
//  populate city / kanji text fields; the kanji slot is suggested
//  via `CityNameTranslator` on city change and remains editable.
//  Fields are grouped into collapsible items mirroring the Express
//  template's `requirements` categories.
//

import SwiftUI
import Translation

struct NewTrainFormStep: View {

    @ObservedObject var funnel: NewTicketFunnel

    /// Re-configures the attached `TranslationSession` whenever a new
    /// translation needs to run. Setting it to a non-nil value (or
    /// calling `.invalidate()`) re-fires the `.translationTask` body.
    @State private var translationConfig: TranslationSession.Configuration?
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
        .translationTask(translationConfig) { session in
            await translateCities(using: session)
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
            case "Date & travel times":
                return Category(id: "schedule", label: req.label, isComplete: hasSchedule, content: AnyView(scheduleContent))
            case "Train details":
                return Category(id: "train", label: req.label, isComplete: hasTrainDetails, content: AnyView(trainContent))
            case "Car & seat":
                return Category(id: "seat", label: req.label, isComplete: hasSeat, content: AnyView(seatContent))
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

    private var hasSchedule: Bool {
        let t = funnel.trainForm
        return t.dateIsSet && t.departureTimeIsSet && t.arrivalTimeIsSet
    }

    private var hasTrainDetails: Bool {
        let t = funnel.trainForm
        return !t.trainType.trimmingCharacters(in: .whitespaces).isEmpty
            && !t.trainNumber.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var hasSeat: Bool {
        let t = funnel.trainForm
        return !t.car.trimmingCharacters(in: .whitespaces).isEmpty
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
        if !t.trainType.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !t.trainNumber.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !t.cabinClass.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !t.originCity.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !t.destinationCity.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !t.originCityKanji.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !t.destinationCityKanji.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !t.car.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !t.seat.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !t.ticketNumber.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
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
                assistiveText: "Pick a station — we’ll translate the city name to Japanese automatically.",
                selected: $funnel.trainForm.originStationLocation
            )
            .onChange(of: funnel.trainForm.originStationLocation) { _, new in
                applyStation(new, isOrigin: true)
            }

            LumoriaStationField(
                label: "Arrival station",
                isRequired: true,
                assistiveText: "Pick a station — we’ll translate the city name to Japanese automatically.",
                selected: $funnel.trainForm.destinationStationLocation
            )
            .onChange(of: funnel.trainForm.destinationStationLocation) { _, new in
                applyStation(new, isOrigin: false)
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

            HStack(spacing: 12) {
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
                LumoriaDateField(
                    label: "Arrives",
                    placeholder: "Pick a time",
                    date: optionalDateBinding(
                        date: $funnel.trainForm.arrivalTime,
                        isSet: $funnel.trainForm.arrivalTimeIsSet
                    ),
                    isRequired: true,
                    displayedComponents: .hourAndMinute
                )
            }
        }
    }

    // MARK: - Train content

    private var trainContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            LumoriaInputField(
                label: "Train type",
                placeholder: "Shinkansen N700",
                text: $funnel.trainForm.trainType,
                isRequired: true
            )

            LumoriaInputField(
                label: "Train number",
                placeholder: "Hikari 503",
                text: $funnel.trainForm.trainNumber,
                isRequired: true
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

    // MARK: - Seat content

    private var seatContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                LumoriaInputField(
                    label: "Car",
                    placeholder: "7",
                    text: $funnel.trainForm.car,
                    isRequired: false
                )
                LumoriaInputField(
                    label: "Seat",
                    placeholder: "14A",
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

    /// Fills city + station strings from a picked station, seeds the
    /// kanji slot from the static `CityNameTranslator` dictionary for
    /// instant feedback, then kicks off an on-device Apple Translation
    /// pass that refines / replaces the seed.
    private func applyStation(_ location: TicketLocation?, isOrigin: Bool) {
        guard let location else { return }
        let city = location.city ?? location.name

        if isOrigin {
            funnel.trainForm.originCity = city
            funnel.trainForm.originStation = location.name
            funnel.trainForm.originCityKanji = CityNameTranslator.kanji(for: city) ?? city
        } else {
            funnel.trainForm.destinationCity = city
            funnel.trainForm.destinationStation = location.name
            funnel.trainForm.destinationCityKanji = CityNameTranslator.kanji(for: city) ?? city
        }

        triggerTranslation()
    }

    // MARK: - On-device translation

    private func triggerTranslation() {
        let config = TranslationSession.Configuration(
            source: Locale.Language(identifier: "en"),
            target: Locale.Language(identifier: "ja")
        )
        if translationConfig == nil {
            translationConfig = config
        } else {
            translationConfig?.invalidate()
        }
    }

    private func translateCities(using session: TranslationSession) async {
        let origin = funnel.trainForm.originCity
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let destination = funnel.trainForm.destinationCity
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !origin.isEmpty {
            if let kanji = try? await session.translate(origin).targetText, !kanji.isEmpty {
                funnel.trainForm.originCityKanji = kanji
            }
        }
        if !destination.isEmpty {
            if let kanji = try? await session.translate(destination).targetText, !kanji.isEmpty {
                funnel.trainForm.destinationCityKanji = kanji
            }
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
