//
//  NoopAnalyticsService.swift
//  Lumoria App
//
//  Default backend used before `Analytics.configure(_:)` runs and in
//  SwiftUI previews / unit tests. Drops every call silently.
//

import Foundation

final class NoopAnalyticsService: AnalyticsService {
    func track(_ event: AnalyticsEvent) { }
    func identify(userId: String, userProperties: [String: Any]) { }
    func updateUserProperties(_ properties: [String: Any]) { }
    func reset() { }
    func setOptOut(_ optedOut: Bool) { }
}
