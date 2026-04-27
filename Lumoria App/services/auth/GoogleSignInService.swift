//
//  GoogleSignInService.swift
//  Lumoria App
//
//  Wraps GoogleSignIn-iOS as an async function and exchanges the
//  resulting id_token for a Supabase session via signInWithIdToken.
//
//  Setup checklist (one-time, see plan doc):
//   1. Add SPM package https://github.com/google/GoogleSignIn-iOS to the
//      Lumoria App target.
//   2. Reversed client ID added as a URL scheme in Info.plist (already
//      done — CFBundleURLTypes entry).
//   3. Supabase Dashboard → Auth → Providers → Google: enable, paste
//      the iOS client ID into both "Client ID" and "Authorized Client IDs".
//

import Foundation
import GoogleSignIn
import Supabase
import UIKit

@MainActor
enum GoogleSignInService {

    /// Public iOS OAuth client ID from Google Cloud Console. Inlined
    /// because it is not a secret (it ships in every app build's
    /// Info.plist URL scheme already).
    private static let clientID = "597649446800-p2dc0r521piast46mfrskpitf0qli0dn.apps.googleusercontent.com"

    enum GoogleSignInError: Error {
        case noPresentingViewController
        case canceled
        case missingIdToken
        case providerFailed(String)
    }

    /// Runs the Google Sign-In flow and exchanges the id_token for a
    /// Supabase session.
    static func signIn() async throws -> Session {
        guard let presenter = topViewController() else {
            throw GoogleSignInError.noPresentingViewController
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        let result: GIDSignInResult
        do {
            result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        } catch {
            if let nsError = error as NSError?, nsError.code == GIDSignInError.canceled.rawValue {
                throw GoogleSignInError.canceled
            }
            throw GoogleSignInError.providerFailed(error.localizedDescription)
        }

        guard let idToken = result.user.idToken?.tokenString else {
            throw GoogleSignInError.missingIdToken
        }
        let accessToken = result.user.accessToken.tokenString

        return try await supabase.auth.signInWithIdToken(
            credentials: .init(
                provider: .google,
                idToken: idToken,
                accessToken: accessToken
            )
        )
    }

    /// Resolves the foremost view controller of the active key window so
    /// the GoogleSignIn SDK has somewhere to anchor its modal.
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        guard let root = scene?.windows.first(where: \.isKeyWindow)?.rootViewController else {
            return nil
        }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}
