//
//  EurovisionFormStep.swift
//  Lumoria App
//
//  Step 4 — Eurovision variant of the form. Date and venue are pinned
//  to the real-world event (16 May 2026, Wiener Stadthalle Halle D), so
//  the form only collects the supported country plus the user's seat /
//  row / section. The country picker drives the per-country background
//  and logo artwork on the rendered ticket. Sections are grouped into
//  collapsibles mirroring the Eurovision template's `requirements`
//  categories — pinned date / venue items render read-only copy.
//

import SwiftUI

struct NewEurovisionFormStep: View {

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
                hasOriginLocation: true,
                hasDestinationLocation: false
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
            case "Country you’re supporting":
                return Category(id: "country", label: req.label, isComplete: funnel.eurovisionForm.country != nil, content: AnyView(countryContent))
            case "Date is fixed (16 May 2026)":
                return Category(id: "date", label: req.label, isComplete: true, content: AnyView(dateInfoContent))
            case "Venue is fixed (Wiener Stadthalle Halle D)":
                return Category(id: "venue", label: req.label, isComplete: true, content: AnyView(venueInfoContent))
            case "Section, row & seat":
                return Category(id: "seat", label: req.label, isComplete: hasSeating, content: AnyView(seatContent))
            default:
                return nil
            }
        }
    }

    // MARK: - Completion predicates

    private var hasSeating: Bool {
        let e = funnel.eurovisionForm
        switch e.attendance {
        case .inPerson:
            let trim: (String) -> String = { $0.trimmingCharacters(in: .whitespaces) }
            return !trim(e.section).isEmpty
                && !trim(e.row).isEmpty
                && !trim(e.seat).isEmpty
        case .atHome:
            return !e.watchLocation.trimmingCharacters(in: .whitespaces).isEmpty
        }
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

    // MARK: - Country content

    private var countryContent: some View {
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

    // MARK: - Pinned info copy

    private var dateInfoContent: some View {
        pinnedInfo("Eurovision 2026 takes place on **16 May 2026**. We’ve filled the date for you.")
    }

    private var venueInfoContent: some View {
        pinnedInfo("The grand finale takes place at the **Wiener Stadthalle Halle D** in Vienna. We’ve filled the venue for you.")
    }

    private func pinnedInfo(_ markdown: String) -> some View {
        Text(.init(markdown))
            .font(.footnote)
            .foregroundStyle(Color.Text.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Seat content (in-person vs. at-home + ticket number)

    private var seatContent: some View {
        VStack(alignment: .leading, spacing: 16) {
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

            LumoriaInputField(
                label: "Ticket number",
                placeholder: "ESC-2026-000142",
                text: $funnel.eurovisionForm.ticketNumber,
                isRequired: false
            )
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
}
