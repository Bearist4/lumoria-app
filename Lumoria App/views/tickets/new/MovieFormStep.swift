//
//  MovieFormStep.swift
//  Lumoria App
//
//  Step 4 — Lumiere variant of the form. Captures the movie title, the
//  cinema venue, a date and screening time, plus room / row / seat. The
//  movie title triggers an OMDb lookup on commit so the rendered ticket
//  can show the film's poster + director without any extra typing.
//  Sections are grouped into collapsibles mirroring the Lumiere
//  template's `requirements` categories.
//

import Combine
import SwiftUI

struct NewMovieFormStep: View {

    @ObservedObject var funnel: NewTicketFunnel

    @State private var didFireSubmit = false
    @State private var expandedItems: Set<String> = []
    @StateObject private var movieSearch = MovieSearchModel()

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
            movieSearch.query = funnel.movieForm.movieTitle
        }
        .onChange(of: funnel.canAdvance) { _, ready in
            guard ready, !didFireSubmit, let template = funnel.template else { return }
            didFireSubmit = true
            Analytics.track(.ticketFormSubmitted(
                template: template.analyticsTemplate,
                fieldFillCount: countFilledFields(),
                hasOriginLocation: funnel.movieForm.cinemaVenueLocation != nil,
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
            case "Movie title":
                return Category(id: "movie", label: req.label, isComplete: hasMovie, content: AnyView(movieContent))
            case "Cinema location":
                return Category(id: "cinema", label: req.label, isComplete: hasCinema, content: AnyView(cinemaContent))
            case "Date & screening time":
                return Category(id: "schedule", label: req.label, isComplete: hasSchedule, content: AnyView(scheduleContent))
            case "Room, row & seat":
                return Category(id: "seat", label: req.label, isComplete: hasSeat, content: AnyView(seatContent))
            default:
                return nil
            }
        }
    }

    // MARK: - Completion predicates

    private var hasMovie: Bool {
        !funnel.movieForm.movieTitle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var hasCinema: Bool {
        !funnel.movieForm.cinemaLocation.trimmingCharacters(in: .whitespaces).isEmpty
            || funnel.movieForm.cinemaVenueLocation != nil
    }

    private var hasSchedule: Bool {
        funnel.movieForm.dateIsSet && funnel.movieForm.timeIsSet
    }

    private var hasSeat: Bool {
        let m = funnel.movieForm
        let trim: (String) -> String = { $0.trimmingCharacters(in: .whitespaces) }
        return !trim(m.roomNumber).isEmpty
            && !trim(m.row).isEmpty
            && !trim(m.seat).isEmpty
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
        let m = funnel.movieForm
        let trim: (String) -> String = { $0.trimmingCharacters(in: .whitespaces) }
        var count = 0
        if !trim(m.movieTitle).isEmpty { count += 1 }
        if !trim(m.director).isEmpty { count += 1 }
        if !trim(m.cinemaLocation).isEmpty { count += 1 }
        if !trim(m.roomNumber).isEmpty { count += 1 }
        if !trim(m.row).isEmpty { count += 1 }
        if !trim(m.seat).isEmpty { count += 1 }
        if !trim(m.posterUrl).isEmpty { count += 1 }
        return count
    }

    // MARK: - Movie content

    /// Title field + searchable dropdown. Typing fires an OMDb `s=`
    /// search; the user picks a specific film from the result list,
    /// and only then do we resolve the poster + director. Picking is
    /// the only path that writes a `posterUrl` to the form — typing
    /// alone leaves the previous selection in place until the user
    /// either picks again or clears the field.
    private var movieContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            MovieSearchField(
                model: movieSearch,
                onPick: { hit in pickMovie(hit) },
                onClear: { clearMovie() }
            )

            // Reflects the current selection / progress without
            // overlapping the dropdown — sits below the field.
            if !funnel.movieForm.director.isEmpty {
                Text("Directed by **\(funnel.movieForm.director)**")
                    .font(.footnote)
                    .foregroundStyle(Color.Text.secondary)
            } else if movieSearch.isSearching {
                Text("Looking up the poster…")
                    .font(.footnote)
                    .foregroundStyle(Color.Text.tertiary)
            } else {
                Text("Search in English — OMDb's catalog is English-only.")
                    .font(.caption2)
                    .foregroundStyle(Color.Feedback.Neutral.text)
            }
        }
    }

    /// Apply a picked search hit to the form. Resolves the full
    /// OMDb record (for the director field), warms the synchronous
    /// poster cache so the export pipeline can render without waiting,
    /// and writes the canonical title back to the input.
    private func pickMovie(_ hit: MovieSearchHit) {
        funnel.movieForm.movieTitle = hit.title
        funnel.movieForm.posterUrl = hit.posterUrl
        funnel.movieForm.director = ""
        movieSearch.query = hit.title
        movieSearch.dismissResults()

        if let url = URL(string: hit.posterUrl), !hit.posterUrl.isEmpty {
            Task { await MoviePosterImageCache.shared.load(from: url) }
        }

        Task { @MainActor in
            guard let lookup = await MoviePosterService.shared.details(imdbID: hit.imdbID) else { return }
            funnel.movieForm.director = lookup.director
            // Prefer the details endpoint's poster if the search
            // listing came back with `N/A`.
            if funnel.movieForm.posterUrl.isEmpty, !lookup.posterUrl.isEmpty {
                funnel.movieForm.posterUrl = lookup.posterUrl
                if let url = URL(string: lookup.posterUrl) {
                    Task { await MoviePosterImageCache.shared.load(from: url) }
                }
            }
        }
    }

    /// Wipe everything tied to a movie selection — title, poster,
    /// director, and the search dropdown's results. Used when the
    /// user taps the field's clear button.
    private func clearMovie() {
        funnel.movieForm.movieTitle = ""
        funnel.movieForm.posterUrl = ""
        funnel.movieForm.director = ""
        movieSearch.reset()
    }

    // MARK: - Cinema content

    private var cinemaContent: some View {
        LumoriaCinemaField(
            label: "Cinema",
            isRequired: true,
            assistiveText: "We’ll auto-fill the city and drop a pin on the map.",
            initialQuery: funnel.movieForm.cinemaLocation,
            selected: $funnel.movieForm.cinemaVenueLocation
        )
        .onChange(of: funnel.movieForm.cinemaVenueLocation) { _, new in
            if let new { funnel.movieForm.cinemaLocation = new.name }
        }
    }

    // MARK: - Schedule content

    private var scheduleContent: some View {
        HStack(spacing: 12) {
            LumoriaDateField(
                label: "Date",
                placeholder: "Pick a date",
                date: optionalDateBinding(
                    date: $funnel.movieForm.date,
                    isSet: $funnel.movieForm.dateIsSet
                ),
                isRequired: true
            )
            LumoriaDateField(
                label: "Screening",
                placeholder: "Pick a time",
                date: optionalDateBinding(
                    date: $funnel.movieForm.time,
                    isSet: $funnel.movieForm.timeIsSet
                ),
                isRequired: true,
                displayedComponents: .hourAndMinute
            )
        }
    }

    // MARK: - Seat content

    private var seatContent: some View {
        HStack(spacing: 12) {
            LumoriaInputField(
                label: "Room",
                placeholder: "12",
                text: $funnel.movieForm.roomNumber,
                isRequired: false
            )
            LumoriaInputField(
                label: "Row",
                placeholder: "K",
                text: $funnel.movieForm.row,
                isRequired: false
            )
            LumoriaInputField(
                label: "Seat",
                placeholder: "14",
                text: $funnel.movieForm.seat,
                isRequired: false
            )
        }
    }
}

// MARK: - Movie search

/// Drives the movie search dropdown. Debounces the user's typing into a
/// single OMDb `s=` request so a fast typist doesn't burn ten round-trips
/// before they see results.
@MainActor
final class MovieSearchModel: ObservableObject {
    @Published var query: String = ""
    @Published var results: [MovieSearchHit] = []
    @Published var isSearching: Bool = false

    /// True when the user has explicitly picked a hit. Suppresses the
    /// dropdown so the picked title doesn't immediately re-trigger the
    /// search and re-show the same list.
    @Published var didPick: Bool = false

    private var task: Task<Void, Never>? = nil

    /// Schedules a debounced search. Cancels any in-flight request.
    func runSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        task?.cancel()
        guard !trimmed.isEmpty else {
            results = []
            isSearching = false
            return
        }
        if didPick { return }
        isSearching = true
        task = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
            let hits = await MoviePosterService.shared.search(title: trimmed)
            if Task.isCancelled { return }
            self.results = hits
            self.isSearching = false
        }
    }

    /// Hides the dropdown without dropping the typed text — used after
    /// the user picks a row.
    func dismissResults() {
        task?.cancel()
        results = []
        isSearching = false
        didPick = true
    }

    /// Full reset — query, results, picked-state. Used when the user
    /// taps the field's clear button.
    func reset() {
        task?.cancel()
        query = ""
        results = []
        isSearching = false
        didPick = false
    }
}

/// Movie title input + searchable dropdown. Mirrors `LumoriaCinemaField`
/// but pulls from OMDb instead of MapKit.
struct MovieSearchField: View {
    @ObservedObject var model: MovieSearchModel
    var onPick: (MovieSearchHit) -> Void
    var onClear: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            labelRow
            inputField
            if isFocused, !model.results.isEmpty {
                resultsList
            }
        }
        .onChange(of: model.query) { _, newValue in
            // Typing after a pick reopens the search.
            if model.didPick, !newValue.isEmpty {
                model.didPick = false
            }
            model.runSearch()
        }
    }

    private var labelRow: some View {
        HStack(spacing: 0) {
            Text("Movie title")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.Text.primary)
            Text(verbatim: "*")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.Feedback.Danger.border)
        }
    }

    private var inputField: some View {
        HStack(spacing: 8) {
            Image(systemName: "film.fill")
                .font(.subheadline)
                .foregroundStyle(Color.Text.tertiary)

            TextField("Dune Part Two", text: $model.query)
                .focused($isFocused)
                .font(.body)
                .foregroundStyle(Color.Text.primary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .submitLabel(.search)

            if !model.query.isEmpty {
                Button {
                    onClear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(Color.Text.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 50)
        .background(Color.Background.fieldFill)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.Border.hairline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var resultsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(model.results.prefix(6).enumerated()), id: \.element.imdbID) { idx, hit in
                Button {
                    onPick(hit)
                    isFocused = false
                } label: {
                    HStack(alignment: .center, spacing: 12) {
                        thumbnail(url: hit.posterUrl)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(hit.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.Text.primary)
                                .lineLimit(1)
                            if !hit.year.isEmpty {
                                Text(hit.year)
                                    .font(.footnote)
                                    .foregroundStyle(Color.Text.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .bottom) {
                        if idx != min(model.results.count, 6) - 1 {
                            Rectangle()
                                .fill(Color.Background.fieldFill)
                                .frame(height: 1)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.Background.elevated)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.Border.default, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.top, 4)
    }

    @ViewBuilder
    private func thumbnail(url: String) -> some View {
        if let u = URL(string: url), !url.isEmpty {
            AsyncImage(url: u) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    thumbnailPlaceholder
                }
            }
            .frame(width: 32, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        } else {
            thumbnailPlaceholder
                .frame(width: 32, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
    }

    private var thumbnailPlaceholder: some View {
        ZStack {
            Color.Background.fieldFill
            Image(systemName: "film")
                .font(.footnote)
                .foregroundStyle(Color.Text.tertiary)
        }
    }
}
