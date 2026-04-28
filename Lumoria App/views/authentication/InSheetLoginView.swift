//
//  InSheetLoginView.swift
//  Lumoria App
//
//  Login surface rendered inside the floating auth sheet after the
//  email-existence check returns `.exists`. Email is locked + prefilled.
//  Calls AuthManager so the supabase client only lives in one place.
//

import SwiftUI

struct InSheetLoginView: View {
    let email: String
    @EnvironmentObject private var auth: AuthManager
    var onSuccess: () -> Void = {}

    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showForgotPassword = false
    @State private var unverifiedEmail: String?
    @State private var resendStatus: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome back")
                    .font(.title2.bold())
                    .foregroundStyle(Color.Text.primary)
                Text(email)
                    .font(.subheadline)
                    .foregroundStyle(Color.Text.secondary)
            }

            LumoriaInputField(
                label: "Password",
                placeholder: "Your password",
                text: $password,
                isSecure: true,
                contentType: .password
            )

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Color.Feedback.Danger.text)
            }

            HStack {
                Spacer()
                Button("Forgot password?") { showForgotPassword = true }
                    .font(.footnote)
                    .foregroundStyle(Color.Text.primary)
            }

            Button(action: submit) {
                if isLoading {
                    ProgressView().tint(Color.Text.OnColor.white)
                } else {
                    Text("Log in")
                }
            }
            .lumoriaButtonStyle(.primary)
            .disabled(password.isEmpty || isLoading)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 32)
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
        .alert(
            "Verify your email",
            isPresented: Binding(
                get: { unverifiedEmail != nil },
                set: { if !$0 { unverifiedEmail = nil; resendStatus = nil } }
            )
        ) {
            Button("Resend email") {
                if let e = unverifiedEmail { Task { await resend(for: e) } }
            }
            Button("OK", role: .cancel) {}
        } message: {
            if let resendStatus { Text(resendStatus) }
            else if let e = unverifiedEmail {
                Text("Tap the link we sent to \(e) to activate your account, then log in.")
            }
        }
    }

    private func submit() {
        errorMessage = nil
        isLoading = true
        let domain = AnalyticsIdentity.emailDomain(email) ?? "unknown"
        Analytics.track(.loginSubmitted(emailDomain: domain))

        Task {
            defer { isLoading = false }
            do {
                try await auth.signIn(email: email, password: password)
                onSuccess()
            } catch AuthFlowError.emailNotConfirmed(let e) {
                unverifiedEmail = e
            } catch AuthFlowError.invalidCredentials {
                Analytics.track(.loginFailed(errorType: .invalid_credentials))
                errorMessage = String(localized: "Email or password is incorrect")
            } catch {
                Analytics.track(.loginFailed(errorType: .unknown))
                errorMessage = error.localizedDescription
            }
        }
    }

    private func resend(for e: String) async {
        do {
            try await auth.resendVerification(email: e)
            resendStatus = "We resent the link to \(e)."
        } catch {
            resendStatus = "Couldn't resend: \(error.localizedDescription)"
        }
    }
}
