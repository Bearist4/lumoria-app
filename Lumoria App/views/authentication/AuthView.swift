//
//  AuthView.swift
//  Lumoria App
//

import Supabase
import SwiftUI

struct AuthView: View {
    enum Mode { case signIn, signUp }

    var initialMode: Mode = .signIn
    @State private var mode: Mode
    init(initialMode: Mode = .signIn) {
        self.initialMode = initialMode
        _mode = State(initialValue: initialMode)
    }

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var signUpConfirmationShown = false
    @State private var unverifiedEmail: String?
    @State private var resendStatus: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo / wordmark
            Text(verbatim: "Lumoria")
                .font(.title.weight(.semibold))
                .padding(.bottom, 48)

            // Fields
            VStack(spacing: 12) {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                SecureField("Password", text: $password)
                    .textContentType(mode == .signUp ? .newPassword : .password)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
            .padding(.bottom, 24)

            // Error
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.bottom, 12)
            }

            // Primary action
            Button(action: submit) {
                if isLoading {
                    ProgressView().tint(Color.Text.OnColor.white)
                } else {
                    Text(mode == .signIn ? "Log in" : "Create account")
                }
            }
            .lumoriaButtonStyle(.primary, size: .large)
            .disabled(isLoading || email.isEmpty || password.isEmpty)
            .padding(.bottom, 16)

            // Toggle mode
            Button(action: toggleMode) {
                Text(mode == .signIn ? "No account? Sign up" : "Have an account? Log in")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .alert("Check your email", isPresented: $signUpConfirmationShown) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("We sent a confirmation link to \(email). Tap it on this iPhone to activate your account, then log in. You can't log in until your email is verified.")
        }
        .alert(
            "Verify your email",
            isPresented: Binding(
                get: { unverifiedEmail != nil },
                set: { if !$0 { unverifiedEmail = nil; resendStatus = nil } }
            )
        ) {
            Button("Resend email") {
                if let email = unverifiedEmail {
                    Task { await resendVerification(for: email) }
                }
            }
            Button("OK", role: .cancel) {}
        } message: {
            if let resendStatus {
                Text(resendStatus)
            } else if let email = unverifiedEmail {
                Text("Tap the link we sent to \(email) to activate your account, then log in. Check your spam folder if you don't see it.")
            }
        }
    }

    private func resendVerification(for email: String) async {
        do {
            try await supabase.auth.resend(
                email: email,
                type: .signup,
                emailRedirectTo: AuthRedirect.emailConfirmed
            )
            resendStatus = "We resent the link to \(email)."
        } catch {
            resendStatus = "Couldn't resend: \(error.localizedDescription)"
        }
    }

    private func submit() {
        errorMessage = nil
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                if mode == .signUp {
                    try await supabase.auth.signUp(
                        email: email,
                        password: password,
                        redirectTo: AuthRedirect.emailConfirmed
                    )
                    signUpConfirmationShown = true
                    mode = .signIn
                } else {
                    try await supabase.auth.signIn(email: email, password: password)
                    if let user = supabase.auth.currentUser, user.emailConfirmedAt == nil {
                        let blockedEmail = email
                        try? await supabase.auth.signOut()
                        unverifiedEmail = blockedEmail
                        return
                    }
                }
            } catch {
                let lowered = error.localizedDescription.lowercased()
                if lowered.contains("email not confirmed") || lowered.contains("email_not_confirmed") {
                    unverifiedEmail = email
                    return
                }
                errorMessage = error.localizedDescription
            }
        }
    }

    private func toggleMode() {
        errorMessage = nil
        mode = mode == .signIn ? .signUp : .signIn
    }
}

#Preview {
    AuthView(initialMode: .signIn)
}

#Preview("Sign Up") {
    AuthView(initialMode: .signUp)
}
