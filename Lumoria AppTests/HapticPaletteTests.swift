import Testing
import Foundation
@testable import Lumoria_App

@Suite("HapticPalette")
struct HapticPaletteTests {

    @Test("debouncer blocks second trigger within 50ms")
    func debounceBlocksFast() {
        let debouncer = HapticDebouncer(minInterval: 0.050)
        let now = Date()
        #expect(debouncer.shouldFire(.select, at: now) == true)
        #expect(debouncer.shouldFire(.select, at: now.addingTimeInterval(0.020)) == false)
    }

    @Test("debouncer allows trigger after interval elapses")
    func debounceAllowsAfterInterval() {
        let debouncer = HapticDebouncer(minInterval: 0.050)
        let now = Date()
        _ = debouncer.shouldFire(.select, at: now)
        #expect(debouncer.shouldFire(.select, at: now.addingTimeInterval(0.060)) == true)
    }

    @Test("debouncer tracks tokens independently")
    func debounceIndependentPerToken() {
        let debouncer = HapticDebouncer(minInterval: 0.050)
        let now = Date()
        _ = debouncer.shouldFire(.select, at: now)
        // Different token, no elapsed time — still allowed.
        #expect(debouncer.shouldFire(.confirm, at: now) == true)
    }

    @Test("all seven haptic tokens exist")
    func sevenTokens() {
        let expected: [HapticToken] = [
            .select, .confirm, .toggle, .warn, .save, .stamp, .shimmer
        ]
        #expect(expected.count == 7)
    }
}
