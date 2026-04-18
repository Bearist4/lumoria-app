//
//  AnalyticsService.swift
//  Lumoria App
//
//  Protocol + singleton entry point for analytics. Views call
//  `Analytics.track(.someEvent(...))`. The concrete backend (Amplitude,
//  Noop for previews) is injected once at app launch.
//

import Foundation

protocol AnalyticsService: AnyObject {
    /// Track a single event. Implementations must be non-blocking.
    func track(_ event: AnalyticsEvent)

    /// Associate subsequent events with a user. `userId` is the raw
    /// Supabase UUID (no PII).
    func identify(userId: String, userProperties: [String: Any])

    /// Update user properties without firing an event.
    func updateUserProperties(_ properties: [String: Any])

    /// Clear user id + rotate device id. Called on logout.
    func reset()

    /// Toggle analytics opt-out at runtime (future consent screen).
    func setOptOut(_ optedOut: Bool)
}

/// Thread-safe singleton. `configure(_:)` must be called once at app
/// launch before any `track(_:)` call. Safe to call tracking before
/// configure — events fall through to a no-op until configured.
enum Analytics {

    private static var backend: AnalyticsService = NoopAnalyticsService()

    /// Install the production analytics backend. Call once at app launch.
    static func configure(_ service: AnalyticsService) {
        backend = service
    }

    static func track(_ event: AnalyticsEvent) {
        backend.track(event)
    }

    static func identify(userId: String, userProperties: [String: Any] = [:]) {
        backend.identify(userId: userId, userProperties: userProperties)
    }

    static func updateUserProperties(_ properties: [String: Any]) {
        backend.updateUserProperties(properties)
    }

    static func reset() {
        backend.reset()
    }

    static func setOptOut(_ optedOut: Bool) {
        backend.setOptOut(optedOut)
    }
}
