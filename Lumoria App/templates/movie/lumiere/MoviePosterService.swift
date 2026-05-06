//
//  MoviePosterService.swift
//  Lumoria App
//
//  OMDb (omdbapi.com) lookup for the Lumiere movie ticket. Resolves a
//  free-text movie title into a poster URL + director name. Results are
//  cached in-memory by trimmed, case-folded title so a typing user
//  doesn't refire the same request between keystrokes.
//
//  Also exposes `MoviePosterImageCache` — a synchronous `UIImage`
//  cache for the resolved poster artwork. Synchronous reads are
//  required because `AsyncImage` doesn't load inside `ImageRenderer`
//  snapshots (export pipeline) or reliably in fast-scrolling lists,
//  so we pre-fetch the bytes once and render the cached `UIImage`
//  directly via `Image(uiImage:)`.
//

import Foundation
import UIKit

struct MovieLookup: Hashable {
    /// Title returned by OMDb (canonical capitalisation). Falls back to
    /// the requested string when the API doesn't return one.
    var title: String
    var director: String
    /// Absolute URL string. Empty when OMDb returned `"Poster": "N/A"`
    /// or no match was found.
    var posterUrl: String
}

/// One row in the search dropdown — slim payload (no director) so the
/// `s=` listing populates fast. Director comes in via `details(imdbID:)`
/// when the user taps a row.
struct MovieSearchHit: Hashable, Identifiable {
    /// IMDb identifier (e.g. `tt15239678`). Stable across OMDb requests
    /// — used as `id` and as the key for the follow-up details lookup.
    let imdbID: String
    let title: String
    /// Release year as returned by OMDb (e.g. `"2024"`). Empty when
    /// missing — kept as a string because OMDb sometimes returns ranges
    /// like `"2017–"` for series.
    let year: String
    /// Absolute poster URL. Empty when OMDb returned `"Poster": "N/A"`.
    let posterUrl: String

    var id: String { imdbID }
}

actor MoviePosterService {

    static let shared = MoviePosterService()

    /// Public OMDb key. Free tier — fine to ship in-app.
    private let apiKey = "204984fe"

    private var cache: [String: MovieLookup] = [:]
    /// In-flight requests keyed by the same lookup key as `cache`. Lets
    /// concurrent calls for the same title share a single network round-
    /// trip instead of each kicking off their own.
    private var pending: [String: Task<MovieLookup?, Never>] = [:]

    /// Resolve `title` against OMDb. Returns nil when the title is
    /// blank, the network fails, or OMDb reports `"Response": "False"`.
    /// Cached results for the same key return synchronously after the
    /// first successful call.
    func lookup(title: String) async -> MovieLookup? {
        let key = Self.cacheKey(for: title)
        guard !key.isEmpty else { return nil }

        if let hit = cache[key] { return hit }
        if let inflight = pending[key] { return await inflight.value }

        let task = Task<MovieLookup?, Never> { [apiKey] in
            await Self.fetch(title: title, apiKey: apiKey)
        }
        pending[key] = task
        let result = await task.value
        pending[key] = nil
        if let result { cache[key] = result }
        return result
    }

    /// Synchronous cache hit, for renderers that want to surface the
    /// last-known poster without awaiting. Returns nil when the title
    /// hasn't been looked up yet.
    func cached(title: String) -> MovieLookup? {
        cache[Self.cacheKey(for: title)]
    }

    /// OMDb search (`s=`) — returns up to ~10 hits. Filters to type=movie
    /// so the dropdown doesn't surface series, episodes, or games. The
    /// list does NOT include the director (OMDb omits it from the search
    /// response); call `details(imdbID:)` once the user picks a row.
    func search(title: String) async -> [MovieSearchHit] {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return await Self.fetchSearch(title: trimmed, apiKey: apiKey)
    }

    /// Resolve a single picked hit into a full `MovieLookup` (canonical
    /// title, director, poster). Cached by imdbID so a re-pick is free.
    func details(imdbID: String) async -> MovieLookup? {
        let key = "id:" + imdbID
        if let hit = cache[key] { return hit }
        if let inflight = pending[key] { return await inflight.value }

        let task = Task<MovieLookup?, Never> { [apiKey] in
            await Self.fetchByID(imdbID: imdbID, apiKey: apiKey)
        }
        pending[key] = task
        let result = await task.value
        pending[key] = nil
        if let result { cache[key] = result }
        return result
    }

    private static func cacheKey(for title: String) -> String {
        title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func fetch(title: String, apiKey: String) async -> MovieLookup? {
        var components = URLComponents(string: "https://www.omdbapi.com/")
        components?.queryItems = [
            URLQueryItem(name: "apikey", value: apiKey),
            URLQueryItem(name: "t", value: title),
        ]
        guard let url = components?.url else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            let payload = try JSONDecoder().decode(OMDbResponse.self, from: data)
            guard payload.Response.lowercased() == "true" else { return nil }
            let posterUrl: String = {
                let raw = payload.Poster ?? ""
                return raw.lowercased() == "n/a" ? "" : raw
            }()
            let director: String = {
                let raw = payload.Director ?? ""
                return raw.lowercased() == "n/a" ? "" : raw
            }()
            return MovieLookup(
                title: payload.Title ?? title,
                director: director,
                posterUrl: posterUrl
            )
        } catch {
            return nil
        }
    }

    /// Subset of OMDb's response we care about. Keys preserve OMDb's
    /// PascalCase wire format so the decoder doesn't need a custom
    /// strategy.
    private struct OMDbResponse: Decodable {
        let Title: String?
        let Director: String?
        let Poster: String?
        let Response: String
    }

    private static func fetchSearch(title: String, apiKey: String) async -> [MovieSearchHit] {
        var components = URLComponents(string: "https://www.omdbapi.com/")
        components?.queryItems = [
            URLQueryItem(name: "apikey", value: apiKey),
            URLQueryItem(name: "s", value: title),
            URLQueryItem(name: "type", value: "movie"),
        ]
        guard let url = components?.url else { return [] }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return []
            }
            let payload = try JSONDecoder().decode(OMDbSearchResponse.self, from: data)
            guard payload.Response.lowercased() == "true" else { return [] }
            return (payload.Search ?? []).map { item in
                let raw = item.Poster ?? ""
                let poster = raw.lowercased() == "n/a" ? "" : raw
                return MovieSearchHit(
                    imdbID: item.imdbID,
                    title: item.Title,
                    year: item.Year ?? "",
                    posterUrl: poster
                )
            }
        } catch {
            return []
        }
    }

    private static func fetchByID(imdbID: String, apiKey: String) async -> MovieLookup? {
        var components = URLComponents(string: "https://www.omdbapi.com/")
        components?.queryItems = [
            URLQueryItem(name: "apikey", value: apiKey),
            URLQueryItem(name: "i", value: imdbID),
        ]
        guard let url = components?.url else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            let payload = try JSONDecoder().decode(OMDbResponse.self, from: data)
            guard payload.Response.lowercased() == "true" else { return nil }
            let posterUrl: String = {
                let raw = payload.Poster ?? ""
                return raw.lowercased() == "n/a" ? "" : raw
            }()
            let director: String = {
                let raw = payload.Director ?? ""
                return raw.lowercased() == "n/a" ? "" : raw
            }()
            return MovieLookup(
                title: payload.Title ?? "",
                director: director,
                posterUrl: posterUrl
            )
        } catch {
            return nil
        }
    }

    private struct OMDbSearchResponse: Decodable {
        let Search: [OMDbSearchItem]?
        let Response: String
    }

    private struct OMDbSearchItem: Decodable {
        let Title: String
        let Year: String?
        let imdbID: String
        let Poster: String?
    }
}

// MARK: - Image cache

/// Synchronous in-memory cache for resolved poster artwork. Backed by
/// `NSCache` so iOS evicts entries under memory pressure. Pair the
/// async `load(from:)` (downloads + caches) with the sync `image(for:)`
/// reader at render time so `Image(uiImage:)` can paint inside
/// `ImageRenderer` snapshots without waiting on a network round-trip.
@MainActor
final class MoviePosterImageCache {

    static let shared = MoviePosterImageCache()

    private let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        // Soft cap — covers an All-tickets gallery of a few dozen
        // posters without unbounded growth. NSCache evicts on memory
        // pressure regardless.
        c.countLimit = 64
        return c
    }()

    /// In-flight loads per URL, deduplicated so concurrent reads share
    /// one network request.
    private var pending: [URL: Task<UIImage?, Never>] = [:]

    /// Returns a previously-cached `UIImage` synchronously. Nil means
    /// the URL hasn't been downloaded yet (or was evicted).
    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url.absoluteString as NSString)
    }

    /// Downloads the image bytes if not already cached, decodes, and
    /// stores. Returns the decoded `UIImage` (or nil on failure).
    /// Concurrent calls for the same URL share one in-flight task.
    @discardableResult
    func load(from url: URL) async -> UIImage? {
        if let hit = image(for: url) { return hit }
        if let inflight = pending[url] { return await inflight.value }

        let task = Task<UIImage?, Never> {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                return UIImage(data: data)
            } catch {
                return nil
            }
        }
        pending[url] = task
        let image = await task.value
        pending[url] = nil
        if let image {
            cache.setObject(image, forKey: url.absoluteString as NSString)
        }
        return image
    }
}
