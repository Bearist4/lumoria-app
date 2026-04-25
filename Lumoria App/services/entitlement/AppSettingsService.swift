//
//  AppSettingsService.swift
//  Lumoria App
//
//  Reads the singleton public.app_settings row that backs the
//  monetisation kill-switch. The row is updatable only by the service
//  role; clients can SELECT but never INSERT/UPDATE/DELETE.
//

import Foundation
import Supabase

struct AppSettings: Codable, Equatable, Sendable {
    let id: String
    var monetisationEnabled: Bool
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case monetisationEnabled = "monetisation_enabled"
        case updatedAt           = "updated_at"
    }
}

protocol AppSettingsServicing: AnyObject, Sendable {
    func fetch() async throws -> AppSettings
}

final class AppSettingsService: AppSettingsServicing, @unchecked Sendable {

    func fetch() async throws -> AppSettings {
        let row: AppSettings = try await supabase
            .from("app_settings")
            .select()
            .eq("id", value: "singleton")
            .single()
            .execute()
            .value
        return row
    }
}
