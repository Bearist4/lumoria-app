//
//  Lumoria_AppUITests.swift
//  Lumoria AppUITests
//
//  Smoke tests for the signed-out launch path. Anything that requires a
//  signed-in Supabase session lives outside this file — those flows need
//  a seeded test user on the dev project.
//

import XCTest

final class Lumoria_AppUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsLandingCTAs() throws {
        let app = XCUIApplication()
        app.launch()

        // Landing view shows both primary CTAs when no session is restored.
        let logIn = app.buttons["Log in"]
        let signUp = app.buttons["Sign up"]
        XCTAssertTrue(logIn.waitForExistence(timeout: 5))
        XCTAssertTrue(signUp.waitForExistence(timeout: 5))
    }

    @MainActor
    func testLogInSheetOpens() throws {
        let app = XCUIApplication()
        app.launch()

        let logIn = app.buttons["Log in"]
        XCTAssertTrue(logIn.waitForExistence(timeout: 5))
        logIn.tap()

        // The log-in sheet presents an email field. Anchor on any text
        // the user would see in the flow.
        let anyEmail = app.textFields.firstMatch
        XCTAssertTrue(anyEmail.waitForExistence(timeout: 3))
    }

    @MainActor
    func testSignUpSheetOpens() throws {
        let app = XCUIApplication()
        app.launch()

        let signUp = app.buttons["Sign up"]
        XCTAssertTrue(signUp.waitForExistence(timeout: 5))
        signUp.tap()

        let anyField = app.textFields.firstMatch
        XCTAssertTrue(anyField.waitForExistence(timeout: 3))
    }
}
