//
//  AnalyticsIdentityTests.swift
//  Lumoria AppTests
//

import Foundation
import Testing
@testable import Lumoria_App

@Suite("AnalyticsIdentity")
struct AnalyticsIdentityTests {

    @Test("hashUUID returns 16 lowercase hex chars")
    func hashUUIDFormat() {
        let uuid = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let hash = AnalyticsIdentity.hashUUID(uuid)
        #expect(hash.count == 16)
        #expect(hash.allSatisfy { $0.isHexDigit && !$0.isUppercase })
    }

    @Test("hashUUID is deterministic")
    func hashUUIDDeterministic() {
        let uuid = UUID()
        #expect(AnalyticsIdentity.hashUUID(uuid) == AnalyticsIdentity.hashUUID(uuid))
    }

    @Test("hashUUID differs per UUID")
    func hashUUIDDistinct() {
        let a = UUID()
        let b = UUID()
        #expect(AnalyticsIdentity.hashUUID(a) != AnalyticsIdentity.hashUUID(b))
    }

    @Test("emailDomain extracts lowercased domain")
    func emailDomainExtracts() {
        #expect(AnalyticsIdentity.emailDomain("Alice@Gmail.COM") == "gmail.com")
        #expect(AnalyticsIdentity.emailDomain("bob@example.co.uk") == "example.co.uk")
    }

    @Test("emailDomain returns nil for malformed input")
    func emailDomainNilForMalformed() {
        #expect(AnalyticsIdentity.emailDomain("no-at-sign") == nil)
        #expect(AnalyticsIdentity.emailDomain("") == nil)
        #expect(AnalyticsIdentity.emailDomain("a@") == nil)
    }

    @Test("hashString is stable across invocations")
    func hashStringStable() {
        #expect(AnalyticsIdentity.hashString("abc") == AnalyticsIdentity.hashString("abc"))
        #expect(AnalyticsIdentity.hashString("abc").count == 16)
    }
}
