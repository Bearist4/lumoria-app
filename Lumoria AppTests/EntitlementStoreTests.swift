import Foundation
import Testing
@testable import Lumoria_App

@Suite("EntitlementStore tier resolution")
struct EntitlementStoreTests {

    private func profile(
        grandfathered: Bool = false,
        isPremium: Bool = false,
        expires: Date? = nil,
        productId: String? = nil
    ) -> Profile {
        Profile(
            userId: UUID(),
            showOnboarding: false,
            onboardingStep: .done,
            grandfatheredAt: grandfathered ? Date() : nil,
            isPremium: isPremium,
            premiumExpiresAt: expires,
            premiumProductId: productId,
            premiumTransactionId: nil,
            inviteRewardKind: nil,
            inviteRewardClaimedAt: nil
        )
    }

    @Test("grandfathered profile resolves to .grandfathered")
    func grandfathered() {
        let t = EntitlementStore.tier(
            for: profile(grandfathered: true),
            now: Date()
        )
        #expect(t == .grandfathered)
    }

    @Test("lifetime product resolves to .lifetime")
    func lifetime() {
        let t = EntitlementStore.tier(
            for: profile(isPremium: true, expires: nil,
                         productId: "app.lumoria.premium.lifetime"),
            now: Date()
        )
        #expect(t == .lifetime)
    }

    @Test("annual sub with future expiry resolves to .subscriber")
    func subscriber() {
        let exp = Date().addingTimeInterval(60 * 60 * 24 * 30)
        let t = EntitlementStore.tier(
            for: profile(isPremium: true, expires: exp,
                         productId: "app.lumoria.premium.annual"),
            now: Date()
        )
        if case let .subscriber(productId, renewsAt) = t {
            #expect(productId == "app.lumoria.premium.annual")
            #expect(renewsAt == exp)
        } else {
            Issue.record("expected .subscriber, got \(t)")
        }
    }

    @Test("expired sub falls back to .free")
    func expired() {
        let t = EntitlementStore.tier(
            for: profile(isPremium: true,
                         expires: Date().addingTimeInterval(-10),
                         productId: "app.lumoria.premium.monthly"),
            now: Date()
        )
        #expect(t == .free)
    }

    @Test("no premium, no grandfather resolves to .free")
    func free() {
        let t = EntitlementStore.tier(for: profile(), now: Date())
        #expect(t == .free)
    }
}
