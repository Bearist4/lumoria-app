//
//  ConcertFormStep.swift
//  Lumoria App
//
//  Step 4 — Concert variant of the form. Captures the artist, tour
//  title, venue, a date and two time fields (doors / show), plus a
//  ticket number. Single-venue template, so only the origin location
//  slot is populated (the venue). Sections are grouped into
//  collapsibles mirroring the Concert template's `requirements`
//  categories.
//

import SwiftUI

struct NewConcertFormStep: View {

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
                hasOriginLocation: funnel.eventForm.venueLocation != nil,
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
            case "Artist & tour name":
                return Category(id: "artist", label: req.label, isComplete: hasArtist, content: AnyView(artistContent))
            case "Venue":
                return Category(id: "venue", label: req.label, isComplete: hasVenue, content: AnyView(venueContent))
            case "Date, doors & showtime":
                return Category(id: "schedule", label: req.label, isComplete: hasSchedule, content: AnyView(scheduleContent))
            case "Ticket number":
                return Category(id: "ticket", label: req.label, isComplete: hasTicket, content: AnyView(ticketContent))
            default:
                return nil
            }
        }
    }

    // MARK: - Completion predicates

    private var hasArtist: Bool {
        !funnel.eventForm.artist.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var hasVenue: Bool {
        !funnel.eventForm.venue.trimmingCharacters(in: .whitespaces).isEmpty
            || funnel.eventForm.venueLocation != nil
    }

    private var hasSchedule: Bool {
        let e = funnel.eventForm
        return e.dateIsSet && e.doorsTimeIsSet && e.showTimeIsSet
    }

    private var hasTicket: Bool {
        !funnel.eventForm.ticketNumber.trimmingCharacters(in: .whitespaces).isEmpty
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
        let e = funnel.eventForm
        var count = 0
        if !e.artist.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !e.tourName.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !e.venue.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        if !e.ticketNumber.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        return count
    }

    // MARK: - Artist content

    private var artistContent: some View {
        VStack(alignment: .leading, spacing: 16) {
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

    // MARK: - Venue content

    private var venueContent: some View {
        LumoriaVenueField(
            label: "Name",
            isRequired: true,
            assistiveText: "We’ll auto-fill the city and drop a pin on the map.",
            initialQuery: funnel.eventForm.venue,
            selected: $funnel.eventForm.venueLocation
        )
        .onChange(of: funnel.eventForm.venueLocation) { _, new in
            applyVenue(new)
        }
    }

    /// Pushes the picked venue's name into the legacy text slot that
    /// `buildPayload` still reads, so the ticket payload carries the
    /// same string the search field shows.
    private func applyVenue(_ location: TicketLocation?) {
        guard let location else { return }
        funnel.eventForm.venue = location.name
    }

    // MARK: - Schedule content

    private var scheduleContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            LumoriaDateField(
                label: "Date",
                placeholder: "Pick a date",
                date: optionalDateBinding(
                    date: $funnel.eventForm.date,
                    isSet: $funnel.eventForm.dateIsSet
                ),
                isRequired: true
            )

            HStack(spacing: 12) {
                LumoriaDateField(
                    label: "Doors",
                    placeholder: "Pick a time",
                    date: optionalDateBinding(
                        date: $funnel.eventForm.doorsTime,
                        isSet: $funnel.eventForm.doorsTimeIsSet
                    ),
                    isRequired: true,
                    displayedComponents: .hourAndMinute
                )
                LumoriaDateField(
                    label: "Show",
                    placeholder: "Pick a time",
                    date: optionalDateBinding(
                        date: $funnel.eventForm.showTime,
                        isSet: $funnel.eventForm.showTimeIsSet
                    ),
                    isRequired: true,
                    displayedComponents: .hourAndMinute
                )
            }
        }
    }

    // MARK: - Ticket content

    private var ticketContent: some View {
        LumoriaInputField(
            label: "Reference",
            placeholder: "CON-2026-000142",
            text: $funnel.eventForm.ticketNumber,
            isRequired: false
        )
    }
}
