import Foundation
import Testing
@testable import Lumoria_App

@Suite("Free-tier cap math")
struct CapLogicTests {

    @Test("memory cap is 3 by default")
    func memoryDefault() {
        #expect(FreeCaps.memoryCap(rewardKind: nil) == 3)
    }

    @Test("memory cap is 4 when invite reward is memory")
    func memoryWithReward() {
        #expect(FreeCaps.memoryCap(rewardKind: .memory) == 4)
    }

    @Test("memory cap is 3 when invite reward is tickets")
    func memoryWithTicketReward() {
        #expect(FreeCaps.memoryCap(rewardKind: .tickets) == 3)
    }

    @Test("ticket cap is 5 by default")
    func ticketDefault() {
        #expect(FreeCaps.ticketCap(rewardKind: nil) == 5)
    }

    @Test("ticket cap is 7 when invite reward is tickets")
    func ticketWithReward() {
        #expect(FreeCaps.ticketCap(rewardKind: .tickets) == 7)
    }

    @Test("ticket cap is 5 when invite reward is memory")
    func ticketWithMemoryReward() {
        #expect(FreeCaps.ticketCap(rewardKind: .memory) == 5)
    }
}
