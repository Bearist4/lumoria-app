import Testing
import SwiftUI
@testable import Lumoria_App

@Suite("MotionTokens")
struct MotionTokensTests {

    @Test("editorial is an ease-out curve at 320ms")
    func editorialDuration() {
        // Animation is not introspectable; we guard intent via the
        // documented duration constant.
        #expect(MotionTokens.editorialDuration == 0.32)
    }

    @Test("expose duration is 620ms")
    func exposeDuration() {
        #expect(MotionTokens.exposeDuration == 0.62)
    }

    @Test("settle spring response is 0.45")
    func settleResponse() {
        #expect(MotionTokens.settleResponse == 0.45)
        #expect(MotionTokens.settleDamping == 0.82)
    }

    @Test("impulse spring response is 0.22")
    func impulseResponse() {
        #expect(MotionTokens.impulseResponse == 0.22)
        #expect(MotionTokens.impulseDamping == 0.65)
    }
}
