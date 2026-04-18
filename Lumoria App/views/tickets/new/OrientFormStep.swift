//
//  OrientFormStep.swift
//  Lumoria App
//
//  Step 4 — Orient (vintage Orient-Express) variant of the form.
//  Station pickers populate city + station text fields. Class is a
//  three-tier dropdown (Business / First / Second).
//

import SwiftUI

struct NewOrientFormStep: View {

    @ObservedObject var funnel: NewTicketFunnel

    @State private var didFireSubmit = false

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            companySection
            originSection
            destinationSection
            scheduleSection
            passengerSection
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

    // MARK: - Company

    private var companySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Carrier")

            LumoriaInputField(
                label: "Company",
                placeholder: "Venice Simplon Orient Express",
                text: $funnel.trainForm.company,
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

    // MARK: - Passenger

    private var passengerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Passenger & seat")

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

    /// Pushes a picked station into the `originCity` / `originStation`
    /// string fields so the Orient renderer picks them up at build
    /// time. Leaves the kanji slot alone (Orient doesn't use it).
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
