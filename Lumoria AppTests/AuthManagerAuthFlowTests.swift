//
//  AuthManagerAuthFlowTests.swift
//  Lumoria AppTests
//

import Foundation
import Testing
@testable import Lumoria_App

actor MockAuthBackend: AuthBackend {
    var checkResult: Result<CheckEmailResult, Error> = .success(.doesNotExist)
    var signInError: Error?
    var signUpError: Error?
    var resendError: Error?
    var unconfirmed: Bool = false

    var lastCheckEmail: String?
    var lastSignInEmail: String?
    var lastSignUpName: String?
    var didSignOut = false

    func checkEmailExists(_ email: String) async throws -> CheckEmailResult {
        lastCheckEmail = email
        return try checkResult.get()
    }
    func signIn(email: String, password: String) async throws {
        lastSignInEmail = email
        if let signInError { throw signInError }
    }
    func signUp(name: String, email: String, password: String, redirectTo: URL?) async throws {
        lastSignUpName = name
        if let signUpError { throw signUpError }
    }
    func resendVerification(email: String, redirectTo: URL?) async throws {
        if let resendError { throw resendError }
    }
    nonisolated func currentUserEmailUnconfirmed() -> Bool { false }
    func signOut() async throws { didSignOut = true }

    func setCheckResult(_ r: Result<CheckEmailResult, Error>) { checkResult = r }
    func setSignInError(_ e: Error) { signInError = e }
}

@MainActor
@Test func authManager_checkEmailExists_passesEmailThrough() async throws {
    let backend = MockAuthBackend()
    let mgr = AuthManager(backend: backend)
    _ = try await mgr.checkEmailExists("Foo@Bar.com")
    let captured = await backend.lastCheckEmail
    #expect(captured == "Foo@Bar.com")
}

@MainActor
@Test func authManager_signIn_propagatesInvalidCredentials() async throws {
    let backend = MockAuthBackend()
    await backend.setSignInError(AuthFlowError.invalidCredentials)
    let mgr = AuthManager(backend: backend)
    do {
        try await mgr.signIn(email: "a@b.com", password: "x")
        Issue.record("expected throw")
    } catch let e as AuthFlowError {
        #expect(e == .invalidCredentials)
    }
}
