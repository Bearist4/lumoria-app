//
//  TrainFormStep.swift
//  Lumoria App
//
//  Step 4 — Express (train) variant of the form. Station pickers
//  populate city / kanji text fields; the kanji slot is suggested
//  via `CityNameTranslator` on city change and remains editable.
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

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            trainSection
            originSection
            destinationSection
            scheduleSection
            seatSection
        }
        // On-device EN → JA translation. Fires whenever
        // `translationConfig` is set or invalidated; we do that on
        // every station pick.
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

    // MARK: - Train

    private var trainSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("About your train")

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

    // MARK: - Origin

    private var originSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Departure")

            LumoriaStationField(
                label: "Station",
                isRequired: true,
                assistiveText: "Pick a station — we’ll translate the city name to Japanese automatically.",
                selected: $funnel.trainForm.originStationLocation
            )
            .onChange(of: funnel.trainForm.originStationLocation) { _, new in
                applyStation(new, isOrigin: true)
            }
        }
    }

    // MARK: - Destination

    private var destinationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Arrival")

            LumoriaStationField(
                label: "Station",
                isRequired: true,
                assistiveText: "Pick a station — we’ll translate the city name to Japanese automatically.",
                selected: $funnel.trainForm.destinationStationLocation
            )
            .onChange(of: funnel.trainForm.destinationStationLocation) { _, new in
                applyStation(new, isOrigin: false)
            }
        }
    }

    // MARK: - Schedule

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Schedule")

            dateField("Date", selection: $funnel.trainForm.date)

            HStack(spacing: 12) {
                timeField("Departs", selection: $funnel.trainForm.departureTime)
                timeField("Arrives", selection: $funnel.trainForm.arrivalTime)
            }
        }
    }

    // MARK: - Seat

    private var seatSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Seat & ticket")

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

    /// Configures / re-fires the translation task. Source is forced to
    /// English because our city names come from MapKit's `locality`
    /// field which is ASCII in most locales we care about; target is
    /// Japanese.
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

    /// Translates both cities in one session pass. Empty strings are
    /// skipped. Failures leave the existing (static-dict-seeded) kanji
    /// in place — so the user always has *something* on the ticket.
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

    // MARK: - Section title

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.title2.bold())
            .foregroundStyle(Color.Text.primary)
    }

    // MARK: - Date / time field shells

    private func dateField(_ label: String, selection: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.Text.primary)
            DatePicker("", selection: selection, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .frame(height: 50)
                .background(Color.Background.fieldFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.Border.hairline, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func timeField(_ label: String, selection: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.Text.primary)
            DatePicker("", selection: selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.compact)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .frame(height: 50)
                .background(Color.Background.fieldFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.Border.hairline, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}
