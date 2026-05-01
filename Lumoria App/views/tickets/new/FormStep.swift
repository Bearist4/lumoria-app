//
//  FormStep.swift
//  Lumoria App
//
//  Step 4 — user fills out flight info. Sections mirror the Figma screen
//  (Departure / Arrival / About your flight) plus a template-aware Details
//  section that only shows fields the chosen template actually uses.
//

import SwiftUI

// MARK: - Cabin class options

/// Fixed set of cabin classes shown in the dropdown. IATA-recognized
/// categories used by virtually every carrier; append here if a template
/// needs an exotic bucket like "Suite" or "Economy Basic".
struct CabinClassOption: Identifiable, Hashable {
    var id: String { name }
    let name: String

    static let all: [CabinClassOption] = [
        .init(name: "Economy"),
        .init(name: "Premium Economy"),
        .init(name: "Business"),
        .init(name: "First"),
    ]

    /// Three-tier train cabin classes. Kept deliberately simple —
    /// Shinkansen / TGV / Orient Express all map onto these buckets
    /// regardless of the carrier's local naming.
    static let allForTrain: [CabinClassOption] = [
        .init(name: "Business"),
        .init(name: "First"),
        .init(name: "Second"),
    ]

    /// Night-train berth categories. Mirrors standard sleeper-compartment
    /// naming across operators (Nightjet, Caledonian Sleeper, Trenitalia
    /// Night).
    static let allForBerth: [CabinClassOption] = [
        .init(name: "Lower"),
        .init(name: "Middle"),
        .init(name: "Upper"),
        .init(name: "Single"),
    ]
}

struct NewTicketFormStep: View {

    @ObservedObject var funnel: NewTicketFunnel

    var body: some View {
        switch funnel.template {
        case .express:     NewTrainFormStep(funnel: funnel)
        case .orient:      NewOrientFormStep(funnel: funnel)
        case .night:       NewNightFormStep(funnel: funnel)
        case .post, .glow: NewPostFormStep(funnel: funnel)
        case .concert:     NewConcertFormStep(funnel: funnel)
        case .eurovision:  NewEurovisionFormStep(funnel: funnel)
        case .underground, .sign, .infoscreen, .grid:
            NewUndergroundFormStep(funnel: funnel)
        default:           planeBody
        }
    }

    @State private var didFireSubmit = false

    @ViewBuilder
    private var planeBody: some View {
        VStack(alignment: .leading, spacing: 28) {
            departureSection
            arrivalSection
            aboutSection
            if shouldShowDetails {
                detailsSection
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

    private func countFilledFields() -> Int {
        let f = funnel.form
        var count = 0
        if !f.airline.trimmingCharacters(in: .whitespaces).isEmpty || f.selectedAirline != nil { count += 1 }
        if !f.composedFlightNumber.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !f.aircraft.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !f.cabinClass.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !f.cabinDetail.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !f.originCode.trimmingCharacters(in: .whitespaces).isEmpty || f.originAirport != nil { count += 1 }
        if !f.destinationCode.trimmingCharacters(in: .whitespaces).isEmpty || f.destinationAirport != nil { count += 1 }
        if !f.gate.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !f.seat.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !f.terminal.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !f.flightDuration.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        return count
    }

    private func hasOriginLocation() -> Bool {
        funnel.form.originAirport != nil
    }

    private func hasDestinationLocation() -> Bool {
        funnel.form.destinationAirport != nil
    }

    // MARK: - Departure

    private var departureSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Departure")

            LumoriaAirportField(
                label: "Airport",
                placeholder: "Search an airport",
                assistiveText: "We’ll auto-fill the code, name, and city from your pick.",
                selected: $funnel.form.originAirport
            )
            .onboardingAnchor("funnel.firstFormField")
            .onChange(of: funnel.form.originAirport) { _, new in
                applyAirport(new, toOriginFields: true)
            }

            HStack(spacing: 12) {
                dateField("Date", selection: $funnel.form.departureDate)
                timeField("Time", selection: $funnel.form.departureTime)
            }
        }
    }

    // MARK: - Arrival

    private var arrivalSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Arrival")

            LumoriaAirportField(
                label: "Airport",
                placeholder: "Search an airport",
                assistiveText: "We’ll auto-fill the code, name, and city from your pick.",
                selected: $funnel.form.destinationAirport
            )
            .onChange(of: funnel.form.destinationAirport) { _, new in
                applyAirport(new, toOriginFields: false)
            }
        }
    }

    // MARK: - Airport → text-field sync

    /// Pushes a picked `TicketLocation` into the legacy text fields so each
    /// template still renders its code/name/city like before. The
    /// `originName` slot means different things by template: Afterglow
    /// renders it as the city, every other template renders it as the
    /// airport name — so the auto-fill branches accordingly.
    private func applyAirport(_ location: TicketLocation?, toOriginFields: Bool) {
        guard let location else { return }
        let cityCountry = [location.city, location.country]
            .compactMap { $0 }
            .joined(separator: ", ")

        let name: String = {
            switch template {
            case .afterglow:
                // Afterglow passes `originName` through as `originCity` in
                // the payload — feed it the city, not the airport name.
                return location.city ?? location.name
            case .studio, .heritage, .terminal, .prism, .express, .orient, .night, .post, .glow, .concert, .eurovision, .underground, .sign, .infoscreen, .grid:
                // Train / concert / underground templates never reach
                // this codepath (their form doesn't call applyAirport),
                // but the switch must be exhaustive.
                return location.name
            }
        }()

        // Always overwrite — picking a new airport should never inherit
        // the previous airport's code. `location.subtitle` carries the
        // cascaded IATA resolution (DB match → regex → first-three-letter
        // fallback), so it is reliably non-nil for anything resolvable;
        // the `?? ""` only triggers on search failures.
        if toOriginFields {
            funnel.form.originCode = location.subtitle ?? ""
            funnel.form.originName = name
            funnel.form.originLocation = cityCountry
        } else {
            funnel.form.destinationCode = location.subtitle ?? ""
            funnel.form.destinationName = name
            funnel.form.destinationLocation = cityCountry
        }
    }

    // MARK: - About the flight

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("About your flight")

            LumoriaAirlineField(
                text: $funnel.form.airline,
                selected: $funnel.form.selectedAirline
            )

            HStack(spacing: 12) {
                flightNumberField

                if template == .heritage || template == .terminal {
                    LumoriaInputField(
                        label: "Aircraft",
                        placeholder: "Airbus A330-XLR",
                        text: $funnel.form.aircraft,
                        isRequired: false
                    )
                }
            }
        }
    }

    // MARK: - Flight number (prefix + digits)

    /// Flight-number input with a locked carrier-code prefix. Pre-airline
    /// pick it shows a neutral "––" placeholder and a plain text input so
    /// the user can still hand-type a full number. Once the airline is
    /// picked, the prefix shows the IATA code and the input switches to a
    /// number pad for just the digits.
    private var flightNumberField: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 0) {
                Text("Flight number")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.Text.primary)
                Text(verbatim: "*")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.Feedback.Danger.icon)
            }

            HStack(spacing: 8) {
                Text(funnel.form.selectedAirline?.iata ?? "––")
                    .font(.headline)
                    .foregroundStyle(
                        funnel.form.selectedAirline == nil
                            ? Color.Text.tertiary
                            : Color.Text.primary
                    )
                    .frame(width: 44, height: 36)
                    .background(Color.black.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                if funnel.form.selectedAirline != nil {
                    TextField(text: $funnel.form.flightNumberDigits, prompt: Text(verbatim: "7141")) {
                        Text("Flight number")
                    }
                    .keyboardType(.numberPad)
                    .font(.body)
                    .foregroundStyle(Color.Text.primary)
                } else {
                    TextField(text: $funnel.form.flightNumber, prompt: Text(verbatim: "AF 7141")) {
                        Text("Flight number")
                    }
                    .keyboardType(.default)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                    .font(.body)
                    .foregroundStyle(Color.Text.primary)
                }
            }
            .padding(.horizontal, 7)
            .frame(height: 50)
            .background(Color.Background.fieldFill)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.Border.hairline, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Template-specific details

    private var shouldShowDetails: Bool {
        needsCabinClass || needsCabinDetail || needsTerminal || needsDuration || true // always show gate/seat
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Boarding details")

            HStack(spacing: 12) {
                LumoriaInputField(
                    label: "Gate",
                    placeholder: "F32",
                    text: $funnel.form.gate,
                    isRequired: false
                )
                LumoriaInputField(
                    label: "Seat",
                    placeholder: "1A",
                    text: $funnel.form.seat,
                    isRequired: false
                )
            }

            if needsCabinClass {
                LumoriaDropdown(
                    label: "Cabin class",
                    placeholder: "Choose a class",
                    isRequired: false,
                    options: CabinClassOption.all,
                    selection: cabinClassBinding,
                    selectedLabel: { $0.name }
                ) { option in
                    Text(option.name)
                        .font(.body)
                        .foregroundStyle(Color.Text.primary)
                }
            }

            if needsCabinDetail {
                LumoriaInputField(
                    label: "Cabin detail",
                    placeholder: "Business · The Pier",
                    text: $funnel.form.cabinDetail,
                    isRequired: false
                )
            }

            if needsDuration {
                LumoriaInputField(
                    label: "Flight duration",
                    placeholder: "9h 40m · Non-stop",
                    text: $funnel.form.flightDuration,
                    isRequired: false
                )
            }

            if needsTerminal {
                LumoriaInputField(
                    label: "Terminal",
                    placeholder: "T3",
                    text: $funnel.form.terminal,
                    isRequired: false
                )
            }
        }
    }

    // MARK: - Helpers

    private var template: TicketTemplateKind { funnel.template ?? .afterglow }

    private var needsCabinClass: Bool {
        switch template {
        case .studio, .heritage, .terminal: return true
        default: return false
        }
    }
    private var needsCabinDetail: Bool { template == .heritage }
    private var needsDuration:    Bool { template == .heritage }
    private var needsTerminal:    Bool { template == .prism }

    // MARK: - Cabin class ↔ String bridge

    /// Maps the dropdown's `CabinClassOption?` selection into
    /// `funnel.form.cabinClass` so downstream payload builders keep
    /// consuming a plain string.
    private var cabinClassBinding: Binding<CabinClassOption?> {
        Binding(
            get: {
                CabinClassOption.all.first { $0.name == funnel.form.cabinClass }
            },
            set: { newValue in
                funnel.form.cabinClass = newValue?.name ?? ""
            }
        )
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.title2.bold())
            .foregroundStyle(Color.Text.primary)
    }

    // MARK: - Date / time fields

    private func dateField(_ label: String, selection: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 0) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.Text.primary)
                Text(verbatim: "*")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.Feedback.Danger.icon)
            }

            DatePicker("", selection: selection, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 50)
                .padding(.horizontal, 12)
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
            HStack(spacing: 0) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.Text.primary)
                Text(verbatim: "*")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.Feedback.Danger.icon)
            }

            DatePicker("", selection: selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.compact)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 50)
                .padding(.horizontal, 12)
                .background(Color.Background.fieldFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.Border.hairline, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}
