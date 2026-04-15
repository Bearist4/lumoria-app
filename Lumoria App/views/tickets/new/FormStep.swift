//
//  FormStep.swift
//  Lumoria App
//
//  Step 4 — user fills out flight info. Sections mirror the Figma screen
//  (Departure / Arrival / About your flight) plus a template-aware Details
//  section that only shows fields the chosen template actually uses.
//

import SwiftUI

struct NewTicketFormStep: View {

    @ObservedObject var funnel: NewTicketFunnel

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            departureSection
            arrivalSection
            aboutSection
            if shouldShowDetails {
                detailsSection
            }
        }
    }

    // MARK: - Departure

    private var departureSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Departure")

            LumoriaInputField(
                label: "Airport",
                placeholder: "CDG",
                text: $funnel.form.originCode,
                assistiveText: nil
            )

            if template != .afterglow {
                LumoriaInputField(
                    label: "Airport name",
                    placeholder: "Charles de Gaulle",
                    text: $funnel.form.originName,
                    isRequired: false
                )
                LumoriaInputField(
                    label: "City / country",
                    placeholder: "Paris, France",
                    text: $funnel.form.originLocation,
                    isRequired: false
                )
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

            LumoriaInputField(
                label: "Airport",
                placeholder: "LAX",
                text: $funnel.form.destinationCode
            )

            if template != .afterglow {
                LumoriaInputField(
                    label: "Airport name",
                    placeholder: "Los Angeles International",
                    text: $funnel.form.destinationName,
                    isRequired: false
                )
                LumoriaInputField(
                    label: "City / country",
                    placeholder: "Los Angeles, USA",
                    text: $funnel.form.destinationLocation,
                    isRequired: false
                )
            }

            HStack(spacing: 12) {
                dateField("Date", selection: $funnel.form.arrivalDate)
                timeField("Time", selection: $funnel.form.arrivalTime)
            }
        }
    }

    // MARK: - About the flight

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("About your flight")

            LumoriaInputField(
                label: "Airline",
                placeholder: "Air France",
                text: $funnel.form.airline
            )

            HStack(spacing: 12) {
                LumoriaInputField(
                    label: "Flight number",
                    placeholder: "AF 7141",
                    text: $funnel.form.flightNumber
                )

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
                LumoriaInputField(
                    label: "Cabin class",
                    placeholder: "Business",
                    text: $funnel.form.cabinClass,
                    isRequired: false
                )
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

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 22, weight: .bold))
            .tracking(-0.26)
            .foregroundStyle(Color.Text.primary)
    }

    // MARK: - Date / time fields

    private func dateField(_ label: String, selection: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 0) {
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(-0.23)
                    .foregroundStyle(.black)
                Text("*")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: "FF867E"))
            }

            DatePicker("", selection: selection, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 50)
                .padding(.horizontal, 12)
                .background(Color.black.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.black.opacity(0.07), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func timeField(_ label: String, selection: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 0) {
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(-0.23)
                    .foregroundStyle(.black)
                Text("*")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: "FF867E"))
            }

            DatePicker("", selection: selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.compact)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 50)
                .padding(.horizontal, 12)
                .background(Color.black.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.black.opacity(0.07), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}
