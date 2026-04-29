//
//  AuthBackend.swift
//  Lumoria App
//
//  Narrow seam over Supabase Auth used by AuthManager's email-first
//  flow methods. Production code uses LiveAuthBackend; tests inject a
//  mock so coordinator + manager logic can be exercised without a
//  network round-trip.
//

import Foundation
@preconcurrency import Supabase
import Functions

protocol AuthBackend: Sendable {
    func checkEmailExists(_ email: String) async throws -> CheckEmailResult
    func signIn(email: String, password: String) async throws
    func signUp(name: String, email: String, password: String, redirectTo: URL?) async throws
    func resendVerification(email: String, redirectTo: URL?) async throws
    /// True if the *currently authenticated* user has not confirmed their
    /// email yet. Used after signIn to mirror LogInView's existing
    /// behaviour of bouncing unverified accounts back to the email step.
    func currentUserEmailUnconfirmed() -> Bool
    func signOut() async throws
}

struct LiveAuthBackend: AuthBackend {
    func checkEmailExists(_ email: String) async throws -> CheckEmailResult {
        struct Resp: Decodable { let exists: Bool }
        do {
            let resp: Resp = try await supabase.functions.invoke(
                "check-email-exists",
                options: FunctionInvokeOptions(body: ["email": email])
            )
            return resp.exists ? .exists : .doesNotExist
        } catch let FunctionsError.httpError(code, _) where code == 429 {
            return .rateLimited
        } catch {
            throw AuthFlowError.transport(error.localizedDescription)
        }
    }

    func signIn(email: String, password: String) async throws {
        do {
            try await supabase.auth.signIn(email: email, password: password)
        } catch {
            let msg = error.localizedDescription.lowercased()
            if msg.contains("email not confirmed") || msg.contains("email_not_confirmed") {
                throw AuthFlowError.emailNotConfirmed(email: email)
            }
            if msg.contains("invalid") || msg.contains("credentials") {
                throw AuthFlowError.invalidCredentials
            }
            throw AuthFlowError.transport(error.localizedDescription)
        }
    }

    func signUp(name: String, email: String, password: String, redirectTo: URL?) async throws {
        do {
            try await supabase.auth.signUp(
                email: email,
                password: password,
                data: ["display_name": .string(name)],
                redirectTo: redirectTo
            )
        } catch {
            throw AuthFlowError.transport(error.localizedDescription)
        }
    }

    func resendVerification(email: String, redirectTo: URL?) async throws {
        do {
            try await supabase.auth.resend(
                email: email,
                type: .signup,
                emailRedirectTo: redirectTo
            )
        } catch {
            throw AuthFlowError.transport(error.localizedDescription)
        }
    }

    func currentUserEmailUnconfirmed() -> Bool {
        guard let user = supabase.auth.currentUser else { return false }
        return user.emailConfirmedAt == nil
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
    }
}
