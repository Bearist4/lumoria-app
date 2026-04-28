//
//  AuthFlowCoordinator.swift
//  Lumoria App
//
//  ObservableObject driving the floating bottom sheet for the email-first
//  landing flow. Owns step + typed values + in-flight task. UI binds to
//  `step` and renders the matching subview.
//
//  Spec: docs/superpowers/specs/2026-04-28-auth-email-morph-flow-design.md
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class AuthFlowCoordinator: ObservableObject {
    @Published var isPresented: Bool = false
    @Published var step: AuthFlowStep = .chooser
    @Published var email: String = ""
    @Published var isCheckingEmail: Bool = false
    @Published var errorMessage: String?

    private let auth: AuthManager
    private var checkTask: Task<Void, Never>?

    private static let emailRegex = try! NSRegularExpression(
        pattern: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#
    )

    init(auth: AuthManager) {
        self.auth = auth
    }

    func start() {
        step = .chooser
        email = ""
        errorMessage = nil
        isPresented = true
    }

    func continueWithEmail() {
        errorMessage = nil
        step = .email
    }

    func submitEmail() async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard Self.emailRegex.firstMatch(in: trimmed, range: range) != nil else {
            errorMessage = String(localized: "Enter a valid email address")
            return
        }

        checkTask?.cancel()
        errorMessage = nil
        isCheckingEmail = true
        defer { isCheckingEmail = false }

        do {
            let result = try await auth.checkEmailExists(trimmed)
            switch result {
            case .exists:
                step = .login(email: trimmed)
            case .doesNotExist:
                step = .signup(email: trimmed)
            case .rateLimited:
                errorMessage = String(localized: "Too many tries — try again in a moment")
            }
        } catch {
            errorMessage = String(localized: "Couldn't check that email — try again")
        }
    }

    func back() {
        switch step {
        case .chooser:
            return
        case .email:
            step = .chooser
        case .login, .signup:
            step = .email
        }
        errorMessage = nil
    }

    func dismiss() {
        checkTask?.cancel()
        isPresented = false
        // Reset on dismiss so the next presentation starts clean.
        step = .chooser
        email = ""
        errorMessage = nil
        isCheckingEmail = false
    }
}
