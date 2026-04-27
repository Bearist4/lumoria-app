//
//  SocialAuthButtons.swift
//  Lumoria App
//
//  Native Sign in with Apple + Google button row, used inside both
//  LogInView and SignUpView. Both providers route through AuthManager
//  which exchanges the resulting id_token for a Supabase session.
//

import AuthenticationServices
import SwiftUI

struct SocialAuthButtons: View {
    enum Mode { case signIn, signUp }
    var mode: Mode = .signIn

    @EnvironmentObject private var auth: AuthManager
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Rectangle().fill(Color.Border.hairline).frame(height: 1)
                Text("or")
                    .font(.footnote)
                    .foregroundStyle(Color.Text.secondary)
                Rectangle().fill(Color.Border.hairline).frame(height: 1)
            }

            // Sign in with Apple — native button.
            // We don't use the SDK request/completion handlers here
            // because AppleSignInService runs the whole flow itself
            // (raw nonce + sha256 + Supabase exchange). The hidden
            // Button overlay below is what actually fires when tapped.
            ZStack {
                SignInWithAppleButton(
                    mode == .signIn ? .signIn : .signUp,
                    onRequest: { _ in },
                    onCompletion: { _ in }
                )
                .signInWithAppleButtonStyle(.black)
                .frame(height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .allowsHitTesting(false)

                Button(action: signInWithApple) {
                    Color.clear
                }
                .buttonStyle(.plain)
                .frame(height: 56)
                .accessibilityLabel(mode == .signIn ? "Sign in with Apple" : "Sign up with Apple")
                .disabled(isLoading)
            }

            // Continue with Google
            Button(action: signInWithGoogle) {
                HStack(spacing: 10) {
                    Image(systemName: "g.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.96))
                    Text(mode == .signIn ? "Continue with Google" : "Sign up with Google")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.Text.primary)
                }
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.Background.fieldFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.Border.hairline, lineWidth: 1)
                )
            }
            .disabled(isLoading)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Color.Feedback.Danger.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func signInWithApple() {
        errorMessage = nil
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                try await auth.signInWithApple()
            } catch AppleSignInService.AppleSignInError.canceled {
                // silent
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func signInWithGoogle() {
        errorMessage = nil
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                try await auth.signInWithGoogle()
            } catch GoogleSignInService.GoogleSignInError.canceled {
                // silent
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
