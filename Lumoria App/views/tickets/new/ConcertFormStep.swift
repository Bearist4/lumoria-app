//
//  ConcertFormStep.swift
//  Lumoria App
//
//  Step 4 — Concert variant of the form. Captures the artist, tour
//  title, venue, a date and two time fields (doors / show), plus a
//  ticket number. Single-venue template, so only the origin location
//  slot is populated (the venue).
//

import SwiftUI

struct NewConcertFormStep: View {

    @ObservedObject var funnel: NewTicketFunnel

    @State private var didFireSubmit = false

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            artistSection
            venueSection
            scheduleSection
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
                hasOriginLocation: funnel.eventForm.venueLocation != nil,
                hasDestinationLocation: false
            ))
        }
    }

    private func countFilledFields() -> Int {
        let e = funnel.eventForm
        var count = 0
        if !e.artist.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !e.tourName.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !e.venue.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !e.ticketNumber.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        return count
    }

    // MARK: - Artist / tour

    private var artistSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("About the show")

            LumoriaInputField(
                label: "Artist",
                placeholder: "Madison Beer",
                text: $funnel.eventForm.artist,
                isRequired: true
            )

            LumoriaInputField(
                label: "Tour name",
                placeholder: "The Locket Tour",
                text: $funnel.eventForm.tourName,
                isRequired: false
            )
        }
    }

    // MARK: - Venue

    private var venueSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Venue")

            LumoriaVenueField(
                label: "Name",
                isRequired: true,
                assistiveText: "We’ll auto-fill the city and drop a pin on the map.",
                selected: $funnel.eventForm.venueLocation
            )
            .onChange(of: funnel.eventForm.venueLocation) { _, new in
                applyVenue(new)
            }
        }
    }

    /// Pushes the picked venue's name into the legacy text slot that
    /// `buildPayload` still reads, so the ticket payload carries the
    /// same string the search field shows.
    private func applyVenue(_ location: TicketLocation?) {
        guard let location else { return }
        funnel.eventForm.venue = location.name
    }

    // MARK: - Schedule

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Schedule")

            dateField("Date", selection: $funnel.eventForm.date)

            HStack(spacing: 12) {
                timeField("Doors", selection: $funnel.eventForm.doorsTime)
                timeField("Show",  selection: $funnel.eventForm.showTime)
            }
        }
    }

    // MARK: - Ticket number

    private var ticketSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Ticket number")

            LumoriaInputField(
                label: "Reference",
                placeholder: "CON-2026-000142",
                text: $funnel.eventForm.ticketNumber,
                isRequired: false
            )
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
