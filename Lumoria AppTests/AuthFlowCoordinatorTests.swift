//
//  AuthFlowCoordinatorTests.swift
//  Lumoria AppTests
//

import Foundation
import Testing
@testable import Lumoria_App

@MainActor
@Test func coordinator_invalidEmail_doesNotCallBackend_setsError() async throws {
    let backend = MockAuthBackend()
    let coord = AuthFlowCoordinator(auth: AuthManager(backend: backend))
    coord.continueWithEmail()
    coord.email = "not-an-email"
    await coord.submitEmail()
    #expect(coord.step == .email)
    #expect(coord.errorMessage != nil)
    let captured = await backend.lastCheckEmail
    #expect(captured == nil)
}

@MainActor
@Test func coordinator_existsTrue_transitionsToLogin() async throws {
    let backend = MockAuthBackend()
    await backend.setCheckResult(.success(.exists))
    let coord = AuthFlowCoordinator(auth: AuthManager(backend: backend))
    coord.continueWithEmail()
    coord.email = "user@example.com"
    await coord.submitEmail()
    #expect(coord.step == .login(email: "user@example.com"))
    #expect(coord.errorMessage == nil)
}

@MainActor
@Test func coordinator_existsFalse_transitionsToSignup() async throws {
    let backend = MockAuthBackend()
    await backend.setCheckResult(.success(.doesNotExist))
    let coord = AuthFlowCoordinator(auth: AuthManager(backend: backend))
    coord.continueWithEmail()
    coord.email = "new@example.com"
    await coord.submitEmail()
    #expect(coord.step == .signup(email: "new@example.com"))
}

@MainActor
@Test func coordinator_rateLimited_staysOnEmail_setsError() async throws {
    let backend = MockAuthBackend()
    await backend.setCheckResult(.success(.rateLimited))
    let coord = AuthFlowCoordinator(auth: AuthManager(backend: backend))
    coord.continueWithEmail()
    coord.email = "user@example.com"
    await coord.submitEmail()
    #expect(coord.step == .email)
    #expect(coord.errorMessage?.contains("Too many") == true)
}

@MainActor
@Test func coordinator_back_fromLogin_returnsToEmail_preservesValue() async throws {
    let backend = MockAuthBackend()
    await backend.setCheckResult(.success(.exists))
    let coord = AuthFlowCoordinator(auth: AuthManager(backend: backend))
    coord.continueWithEmail()
    coord.email = "user@example.com"
    await coord.submitEmail()
    coord.back()
    #expect(coord.step == .email)
    #expect(coord.email == "user@example.com")
}

@MainActor
@Test func coordinator_dismiss_resetsToChooser() async throws {
    let backend = MockAuthBackend()
    let coord = AuthFlowCoordinator(auth: AuthManager(backend: backend))
    coord.start()
    coord.continueWithEmail()
    coord.dismiss()
    #expect(coord.isPresented == false)
    #expect(coord.step == .chooser)
    #expect(coord.email == "")
}
