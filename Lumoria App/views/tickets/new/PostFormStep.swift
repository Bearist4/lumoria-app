//
//  PostFormStep.swift
//  Lumoria App
//
//  Step 4 — Post / Glow (general-purpose train) variant of the form.
//  Both templates render the same shape: train type/number, two
//  stations, a date + departure time, plus car / seat. Station pickers
//  populate the matching text fields.
//

import SwiftUI

struct NewPostFormStep: View {

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

    // MARK: - Train

    private var trainSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("About your train")

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

    // MARK: - Seat

    private var seatSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Car & seat")

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

    // MARK: - Section title

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.title2.bold())
            .foregroundStyle(Color.Text.primary)
    }

    // MARK: - Date / time fields

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
