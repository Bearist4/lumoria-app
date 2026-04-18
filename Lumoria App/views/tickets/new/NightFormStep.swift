//
//  NightFormStep.swift
//  Lumoria App
//
//  Step 4 — Night (sleeper) train variant of the form. Station pickers
//  populate city + station; the berth slot is a dropdown
//  (Lower / Middle / Upper / Single). Reuses `TrainFormInput` fields.
//

import SwiftUI

struct NewNightFormStep: View {

    @ObservedObject var funnel: NewTicketFunnel

    @State private var didFireSubmit = false

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            trainSection
            originSection
            destinationSection
            scheduleSection
            seatSection
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

    // MARK: - Train

    private var trainSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("About your train")

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

    // MARK: - Origin

    private var originSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Departure")

            LumoriaStationField(
                label: "Station",
                isRequired: true,
                assistiveText: "We’ll auto-fill the city for you.",
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
                assistiveText: "We’ll auto-fill the city for you.",
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
            timeField("Departs", selection: $funnel.trainForm.departureTime)
        }
    }

    // MARK: - Passenger + berth

    private var seatSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Passenger & berth")

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
