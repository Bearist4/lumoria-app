import Foundation
import Testing
@testable import Lumoria_App

@Suite("AppSettings decoding")
struct AppSettingsServiceTests {

    @Test("decodes the singleton row from PostgREST JSON")
    func decode() throws {
        let json = """
        {
          "id": "singleton",
          "monetisation_enabled": false,
          "updated_at": "2026-04-25T13:00:00+00:00"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let row = try decoder.decode(AppSettings.self, from: json)
        #expect(row.id == "singleton")
        #expect(row.monetisationEnabled == false)
    }

    @Test("decodes when monetisation is enabled")
    func decodeOn() throws {
        let json = """
        {
          "id": "singleton",
          "monetisation_enabled": true,
          "updated_at": null
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let row = try decoder.decode(AppSettings.self, from: json)
        #expect(row.monetisationEnabled == true)
    }
}
