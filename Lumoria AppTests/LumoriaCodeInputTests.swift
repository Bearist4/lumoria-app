//
//  LumoriaCodeInputTests.swift
//  Lumoria AppTests
//
//  Sanitization + completion-check tests for the OTP-style 6-digit input.
//

import Foundation
import Testing
@testable import Lumoria_App

@Suite("LumoriaCodeInput sanitization")
struct LumoriaCodeInputSanitizationTests {

    @Test("strips non-digits")
    func stripsNonDigits() {
        #expect(LumoriaCodeInput.sanitize("12a3-4 5b6") == "123456")
    }

    @Test("clamps to 6 digits")
    func clampsToSix() {
        #expect(LumoriaCodeInput.sanitize("12345678") == "123456")
    }

    @Test("empty input stays empty")
    func empty() {
        #expect(LumoriaCodeInput.sanitize("") == "")
    }

    @Test("isComplete only when 6 digits")
    func isCompleteOnly6() {
        #expect(LumoriaCodeInput.isComplete("12345") == false)
        #expect(LumoriaCodeInput.isComplete("123456") == true)
        #expect(LumoriaCodeInput.isComplete("1234567") == false)
    }
}
