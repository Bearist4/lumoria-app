//
//  AmplitudeAnalyticsService.swift
//  Lumoria App
//
//  Production analytics backend. Reads the API key from Info.plist
//  (populated from `Amplitude.xcconfig`) and wires every event through
//  the SDK with a universal property envelope (environment, app version,
//  brand slug, etc.). Session-only autocapture; everything else manual.
//

import AmplitudeSwift
import Foundation
import UIKit

final class AmplitudeAnalyticsService: AnalyticsService {

    private let amplitude: Amplitude
    private var universalProperties: [String: Any] = [:]

    /// Init fails soft: if the API key is missing the caller should fall
    /// back to `NoopAnalyticsService`. We return nil instead of crashing
    /// because a dev without the xcconfig shouldn't be blocked.
    init?() {
        guard
            let key = Bundle.main.object(forInfoDictionaryKey: "AMPLITUDE_API_KEY") as? String,
            !key.isEmpty,
            key != "YOUR_AMPLITUDE_API_KEY_HERE"
        else {
            print("[Analytics] AMPLITUDE_API_KEY missing — analytics disabled.")
            return nil
        }

        let config = Configuration(
            apiKey: key,
            serverZone: .US,
            trackingOptions: TrackingOptions().disableTrackIpAddress(),
            autocapture: .sessions
        )
        self.amplitude = Amplitude(configuration: config)

        self.universalProperties = Self.buildUniversalProperties()
    }

    // MARK: - AnalyticsService

    func track(_ event: AnalyticsEvent) {
        var merged = universalProperties
        for (k, v) in event.properties { merged[k] = v }
        amplitude.track(eventType: event.name, eventProperties: merged)
    }

    func identify(userId: String, userProperties: [String: Any]) {
        amplitude.setUserId(userId: userId)
        if !userProperties.isEmpty {
            updateUserProperties(userProperties)
        }
    }

    func updateUserProperties(_ properties: [String: Any]) {
        let identify = Identify()
        for (key, value) in properties {
            identify.set(property: key, value: value)
        }
        amplitude.identify(identify: identify)
    }

    func reset() {
        amplitude.reset()
    }

    func setOptOut(_ optedOut: Bool) {
        amplitude.optOut = optedOut
    }

    // MARK: - Universal properties

    private static func buildUniversalProperties() -> [String: Any] {
        let bundle = Bundle.main
        let appVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let buildNumber = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"

        #if DEBUG
        let environment = AnalyticsEnvironment.dev.rawValue
        #else
        let environment = AnalyticsEnvironment.prod.rawValue
        #endif

        return [
            "environment": environment,
            "app_version": appVersion,
            "build_number": buildNumber,
        ]
    }
}
