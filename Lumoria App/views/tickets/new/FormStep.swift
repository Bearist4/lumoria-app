//
//  FormStep.swift
//  Lumoria App
//
//  Step 4 — user fills out flight info. Sections are grouped into
//  collapsible items mirroring the categories surfaced on
//  `TemplateDetailsSheet` (`TicketTemplateKind.requirements`). All items
//  start collapsed; the status icon flips to a green checkmark once a
//  group's required fields are filled. Date / time fields render empty
//  until the user picks a value (no autofill from `Date()`).
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
        case .lumiere:     NewMovieFormStep(funnel: funnel)
        default:           planeBody
        }
    }

    @State private var didFireSubmit = false
    @State private var expandedItems: Set<String> = []

    @ViewBuilder
    private var planeBody: some View {
        VStack(spacing: 16) {
            FormPreviewTile(funnel: funnel)

            VStack(spacing: 8) {
                ForEach(planeCategories, id: \.id) { category in
                    FormStepCollapsibleItem(
                        title: category.label,
                        isComplete: category.isComplete,
                        isExpanded: binding(for: category.id)
                    ) {
                        category.content
                    }
                    .ifThen(category.id == "airports") {
                        $0.onboardingAnchor("funnel.firstFormField")
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

    /// Categories rendered as collapsibles. Iterates the same
    /// `template.requirements` list shown on the template-detail sheet
    /// and skips any whose label has no matching field cluster yet.
    private var planeCategories: [PlaneCategory] {
        template.requirements.compactMap { req in
            switch req.label {
            case TemplateRequirement.airportCodesLabel:
                return PlaneCategory(
                    id: "airports",
                    label: req.label,
                    isComplete: hasAirports,
                    content: AnyView(airportsContent)
                )
            case TemplateRequirement.dateAndTimeOfTravelLabel:
                return PlaneCategory(
                    id: "schedule",
                    label: req.label,
                    isComplete: hasSchedule,
                    content: AnyView(scheduleContent)
                )
            case TemplateRequirement.flightDetailsLabel:
                return PlaneCategory(
                    id: "flight",
                    label: req.label,
                    isComplete: hasFlightDetails,
                    content: AnyView(flightContent)
                )
            case TemplateRequirement.aircraftDetailsLabel:
                return PlaneCategory(
                    id: "aircraft",
                    label: req.label,
                    isComplete: hasAircraft,
                    content: AnyView(aircraftContent)
                )
            case TemplateRequirement.passengerDetailsLabel:
                // No passenger fields exist on FlightFormInput today;
                // skip so we don't surface an empty collapsible.
                return nil
            default:
                return nil
            }
        }
    }

    private struct PlaneCategory {
        let id: String
        let label: String
        let isComplete: Bool
        let content: AnyView
    }

    // MARK: - Completion predicates

    private var hasAirports: Bool {
        let f = funnel.form
        let hasOrigin = !f.originCode.trimmingCharacters(in: .whitespaces).isEmpty
                        || f.originAirport != nil
        let hasDestination = !f.destinationCode.trimmingCharacters(in: .whitespaces).isEmpty
                             || f.destinationAirport != nil
        return hasOrigin && hasDestination
    }

    private var hasSchedule: Bool {
        funnel.form.departureDateIsSet && funnel.form.departureTimeIsSet
    }

    private var hasFlightDetails: Bool {
        let f = funnel.form
        let hasAirline = !f.airline.trimmingCharacters(in: .whitespaces).isEmpty
                         || f.selectedAirline != nil
        let hasFlightNumber = !f.composedFlightNumber
            .trimmingCharacters(in: .whitespaces)
            .isEmpty
        return hasAirline && hasFlightNumber
    }

    private var hasAircraft: Bool {
        !funnel.form.aircraft.trimmingCharacters(in: .whitespaces).isEmpty
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

    // MARK: - Airports content

    private var airportsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            LumoriaAirportField(
                label: "Departure airport",
                placeholder: "Search an airport",
                assistiveText: "We’ll auto-fill the code, name, and city from your pick.",
                selected: $funnel.form.originAirport
            )
            .onChange(of: funnel.form.originAirport) { _, new in
                applyAirport(new, toOriginFields: true)
            }

            LumoriaAirportField(
                label: "Arrival airport",
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
            case .studio, .heritage, .terminal, .prism, .express, .orient, .night, .post, .glow, .concert, .eurovision, .underground, .sign, .infoscreen, .grid, .lumiere:
                return location.name
            }
        }()

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

    // MARK: - Schedule content

    private var scheduleContent: some View {
        HStack(spacing: 12) {
            LumoriaDateField(
                label: "Date",
                placeholder: "Pick a date",
                date: optionalDateBinding(
                    date: $funnel.form.departureDate,
                    isSet: $funnel.form.departureDateIsSet
                ),
                isRequired: true
            )

            LumoriaDateField(
                label: "Time",
                placeholder: "Pick a time",
                date: optionalDateBinding(
                    date: $funnel.form.departureTime,
                    isSet: $funnel.form.departureTimeIsSet
                ),
                isRequired: true,
                displayedComponents: .hourAndMinute
            )
        }
    }

    // MARK: - Flight details content

    private var flightContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            LumoriaAirlineField(
                text: $funnel.form.airline,
                selected: $funnel.form.selectedAirline
            )

            flightNumberField

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

    // MARK: - Aircraft content

    /// Heritage / Terminal templates surface aircraft model on the
    /// rendered ticket; everything else hides this collapsible.
    private var aircraftContent: some View {
        LumoriaInputField(
            label: "Aircraft",
            placeholder: "Airbus A330-XLR",
            text: $funnel.form.aircraft,
            isRequired: false
        )
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
}

// MARK: - Preview tile

/// Static ticket preview shown above the collapsible items on every form
/// step. Card is locked at 225pt tall regardless of orientation, with
/// the ticket inside sized 252pt wide for horizontal and 189pt tall for
/// vertical per Figma 982-28859 — the previous `OrientationTile` reuse
/// produced an oversized landscape preview that overflowed the form.
struct FormPreviewTile: View {
    @ObservedObject var funnel: NewTicketFunnel

    var body: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.Background.fieldFill)
            .frame(height: 225)
            .overlay {
                let ticket = Ticket(
                    orientation: funnel.orientation,
                    payload: payload
                )
                switch funnel.orientation {
                case .horizontal:
                    TicketPreview(ticket: ticket).frame(width: 252)
                case .vertical:
                    TicketPreview(ticket: ticket).frame(height: 189)
                }
            }
    }

    private var payload: TicketPayload {
        funnel.buildPayload()
            ?? NewTicketFunnel.previewPayload(for: funnel.template ?? .afterglow)
    }
}

// MARK: - Optional date binding helper

/// Bridges a `(Date, Bool)` storage pair into the `Binding<Date?>` shape
/// expected by `LumoriaDateField`. Reading returns nil when the IsSet
/// flag is false (placeholder shown); writing flips IsSet on/off and
/// stores the picked date. Lets us keep `Date` defaults in the model
/// (so `buildPayload` and `prefill` stay simple) while the form UI
/// behaves as if the field were nullable.
func optionalDateBinding(date: Binding<Date>, isSet: Binding<Bool>) -> Binding<Date?> {
    Binding(
        get: { isSet.wrappedValue ? date.wrappedValue : nil },
        set: { newValue in
            if let new = newValue {
                date.wrappedValue = new
                isSet.wrappedValue = true
            } else {
                isSet.wrappedValue = false
            }
        }
    )
}

// MARK: - Conditional modifier helper

extension View {
    /// Apply `transform` to the view only when `condition` is true.
    /// Lets us conditionally attach `.onboardingAnchor` (or any view
    /// modifier) without breaking the opaque-return-type contract.
    @ViewBuilder
    func ifThen<Transformed: View>(
        _ condition: Bool,
        transform: (Self) -> Transformed
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Template requirement labels

extension TemplateRequirement {
    /// Canonical label strings for the plane-template requirements. Kept
    /// here so the form step can switch on them without re-typing the
    /// strings (which would diverge under translation).
    static let airportCodesLabel        = "Airport codes"
    static let dateAndTimeOfTravelLabel = "Date & time of travel"
    static let flightDetailsLabel       = "Flight details"
    static let aircraftDetailsLabel     = "Aircraft details"
    static let passengerDetailsLabel    = "Passenger details"
}
