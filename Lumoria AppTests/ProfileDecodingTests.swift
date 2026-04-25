import Foundation
import Testing
@testable import Lumoria_App

@Suite("Profile decoding")
struct ProfileDecodingTests {

    @Test("decodes a fully populated profile row from PostgREST JSON")
    func fullyPopulatedRow() throws {
        let json = """
        {
          "user_id": "11111111-1111-1111-1111-111111111111",
          "show_onboarding": false,
          "onboarding_step": "done",
          "grandfathered_at": "2026-04-25T13:21:22.989366+00:00",
          "is_premium": true,
          "premium_expires_at": "2027-04-25T00:00:00+00:00",
          "premium_product_id": "app.lumoria.premium.annual",
          "premium_transaction_id": "2000000000000001",
          "invite_reward_kind": "memory",
          "invite_reward_claimed_at": "2026-04-26T10:00:00+00:00"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let p = try decoder.decode(Profile.self, from: json)

        #expect(p.grandfatheredAt != nil)
        #expect(p.isPremium == true)
        #expect(p.premiumExpiresAt != nil)
        #expect(p.premiumProductId == "app.lumoria.premium.annual")
        #expect(p.premiumTransactionId == "2000000000000001")
        #expect(p.inviteRewardKind == .memory)
        #expect(p.inviteRewardClaimedAt != nil)
    }

    @Test("decodes a profile row with all paywall fields null/false")
    func unpaidProfile() throws {
        let json = """
        {
          "user_id": "22222222-2222-2222-2222-222222222222",
          "show_onboarding": true,
          "onboarding_step": "welcome",
          "grandfathered_at": null,
          "is_premium": false,
          "premium_expires_at": null,
          "premium_product_id": null,
          "premium_transaction_id": null,
          "invite_reward_kind": null,
          "invite_reward_claimed_at": null
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let p = try decoder.decode(Profile.self, from: json)

        #expect(p.grandfatheredAt == nil)
        #expect(p.isPremium == false)
        #expect(p.inviteRewardKind == nil)
    }
}
