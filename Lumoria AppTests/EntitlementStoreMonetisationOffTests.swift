import Foundation
import Testing
@testable import Lumoria_App

@Suite("EntitlementStore monetisation override")
struct EntitlementStoreMonetisationOffTests {

    private func freeProfile() -> Profile {
        Profile(
            userId: UUID(),
            showOnboarding: false,
            onboardingStep: .done,
            grandfatheredAt: nil,
            isPremium: false,
            premiumExpiresAt: nil,
            premiumProductId: nil,
            premiumTransactionId: nil,
            inviteRewardKind: nil,
            inviteRewardClaimedAt: nil
        )
    }

    @Test("hasPremium is true for a free user when monetisation is off")
    func freeUserOff() {
        let resolved = EntitlementStore.resolved(
            profile: freeProfile(),
            monetisationEnabled: false,
            now: Date()
        )
        #expect(resolved.hasPremium == true)
        #expect(resolved.tier == .free)
    }

    @Test("hasPremium follows tier when monetisation is on")
    func freeUserOn() {
        let resolved = EntitlementStore.resolved(
            profile: freeProfile(),
            monetisationEnabled: true,
            now: Date()
        )
        #expect(resolved.hasPremium == false)
        #expect(resolved.tier == .free)
    }

    @Test("grandfathered hasPremium stays true regardless of flag")
    func grandfatheredAlwaysPremium() {
        var p = freeProfile()
        p.grandfatheredAt = Date()
        let off = EntitlementStore.resolved(
            profile: p, monetisationEnabled: false, now: Date()
        )
        let on = EntitlementStore.resolved(
            profile: p, monetisationEnabled: true, now: Date()
        )
        #expect(off.hasPremium == true)
        #expect(on.hasPremium == true)
    }
}
