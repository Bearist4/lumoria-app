//
//  AppleSignInService.swift
//  Lumoria App
//
//  Generates a sha256-hashed nonce for the Sign in with Apple request,
//  then exchanges the resulting Apple identity token for a Supabase
//  session. Driven by SocialAuthButtons via SignInWithAppleButton's
//  native onRequest / onCompletion handlers — the canonical Apple
//  pattern (no manual ASAuthorizationController retention or
//  delegate-to-async bridging).
//

import AuthenticationServices
import CryptoKit
import Foundation
import Supabase

@MainActor
enum AppleSignInService {

    enum AppleSignInError: Error {
        case canceled
        case missingIdentityToken
        case unexpectedCredential
        case providerFailed(String)
    }

    /// Returns (rawNonce, hashedNonce). The raw nonce is what we hand to
    /// Supabase later; the hashed one is what Apple requires on the
    /// request.
    static func makeNonce() -> (raw: String, hashed: String) {
        let raw = makeRawNonce()
        return (raw, sha256(raw))
    }

    /// Configures an Apple sign-in request with our scopes + hashed
    /// nonce. The caller is expected to retain the raw nonce.
    static func configure(_ request: ASAuthorizationAppleIDRequest, hashedNonce: String) {
        request.requestedScopes = [.fullName, .email]
        request.nonce = hashedNonce
    }

    /// Exchanges the credential delivered by SignInWithAppleButton's
    /// onCompletion for a Supabase session.
    static func exchange(_ result: Result<ASAuthorization, Error>, rawNonce: String) async throws -> Session {
        switch result {
        case .failure(let error):
            if let asError = error as? ASAuthorizationError, asError.code == .canceled {
                throw AppleSignInError.canceled
            }
            throw AppleSignInError.providerFailed(error.localizedDescription)

        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                throw AppleSignInError.unexpectedCredential
            }
            guard let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                throw AppleSignInError.missingIdentityToken
            }
            return try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: idToken,
                    nonce: rawNonce
                )
            )
        }
    }

    // MARK: - Internals

    private static func makeRawNonce(length: Int = 32) -> String {
        let chars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        return String(bytes.map { chars[Int($0) % chars.count] })
    }

    private static func sha256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
