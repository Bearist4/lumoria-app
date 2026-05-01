//
//  EurovisionFormStep.swift
//  Lumoria App
//
//  Step 4 — Eurovision variant of the form. Date and venue are pinned
//  to the real-world event (16 May 2026, Wiener Stadthalle Halle D), so
//  the form only collects the supported country plus the user's seat /
//  row / section. The country picker drives the per-country background
//  and logo artwork on the rendered ticket.
//

import SwiftUI

struct NewEurovisionFormStep: View {

    @ObservedObject var funnel: NewTicketFunnel

    @State private var didFireSubmit = false

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            fixedFactsBanner
            countrySection
            seatSection
            ticketSection
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
                hasOriginLocation: true,
                hasDestinationLocation: false
            ))
        }
    }

    private func countFilledFields() -> Int {
        let e = funnel.eurovisionForm
        var count = 1 // venue is always set (pinned)
        if e.country != nil { count += 1 }
        switch e.attendance {
        case .inPerson:
            if !e.section.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
            if !e.row.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
            if !e.seat.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        case .atHome:
            if !e.watchLocation.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        }
        if !e.ticketNumber.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        return count
    }

    // MARK: - Fixed-facts banner

    /// Replaces the read-only date+venue fields. Eurovision 2026 has a
    /// single official date + venue, so we tell the user once and skip
    /// the inputs entirely.
    private var fixedFactsBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.subheadline)
                .foregroundStyle(Color.Text.secondary)
            Text("Eurovision 2026 takes place on **16 May 2026** at the **Wiener Stadthalle Halle D**. We've filled the date and venue for you.")
                .font(.footnote)
                .foregroundStyle(Color.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.Background.fieldFill)
        )
    }

    // MARK: - Country picker

    private var countrySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Who are you supporting?")

            LumoriaDropdown(
                label: "Country",
                placeholder: "Pick a country",
                isRequired: true,
                assistiveText: "We'll use this to style your ticket with the country's artwork.",
                options: EurovisionCountry.allCases,
                selection: $funnel.eurovisionForm.country,
                selectedLabel: { "\($0.flagEmoji)  \($0.displayName)" }
            ) { country in
                HStack(spacing: 12) {
                    Text(country.flagEmoji)
                        .font(.title3)
                    Text(country.displayName)
                        .font(.body)
                        .foregroundStyle(Color.Text.primary)
                }
            }
        }
    }

    // MARK: - Seat — segmented (in-person vs. at-home) + conditional fields

    private var seatSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Your seat")

            attendancePicker

            switch funnel.eurovisionForm.attendance {
            case .inPerson:
                HStack(spacing: 12) {
                    LumoriaInputField(
                        label: "Area",
                        placeholder: "Floor",
                        text: $funnel.eurovisionForm.section,
                        isRequired: false
                    )
                    LumoriaInputField(
                        label: "Row",
                        placeholder: "GA",
                        text: $funnel.eurovisionForm.row,
                        isRequired: false
                    )
                    LumoriaInputField(
                        label: "Seat",
                        placeholder: "OPEN",
                        text: $funnel.eurovisionForm.seat,
                        isRequired: false
                    )
                }
            case .atHome:
                LumoriaInputField(
                    label: "Location",
                    placeholder: "At home",
                    text: $funnel.eurovisionForm.watchLocation,
                    isRequired: false
                )
            }
        }
    }

    /// Native segmented control so the two-option pick stays cheap to
    /// scan. Bound directly to the form's `attendance` field; the
    /// seat-section body re-renders on change to swap field sets.
    private var attendancePicker: some View {
        Picker("Attending", selection: $funnel.eurovisionForm.attendance) {
            ForEach(EurovisionAttendance.allCases) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Ticket number

    private var ticketSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Ticket number")

            LumoriaInputField(
                label: "Reference",
                placeholder: "ESC-2026-000142",
                text: $funnel.eurovisionForm.ticketNumber,
                isRequired: false
            )
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.title2.bold())
            .foregroundStyle(Color.Text.primary)
    }
}
