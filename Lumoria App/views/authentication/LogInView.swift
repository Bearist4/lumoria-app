//
//  LogInView.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=948-8015
//

import Supabase
import SwiftUI

struct LogInView: View {
    var onCreateAccount: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showForgotPassword = false
    @State private var unverifiedEmail: String?
    @State private var resendStatus: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.Background.default.ignoresSafeArea()

            VStack(spacing: 0) {
                // Toolbar — X dismiss button
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(Color.Text.primary)
                            .frame(width: 44, height: 44)
                            .background(Color.Background.fieldFill)
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 10)

                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        // Header
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Welcome back!")
                                .font(.largeTitle.bold())
                                .foregroundStyle(Color.Text.primary)

                            Text("Log in to Lumoria")
                                .font(.body)
                                .foregroundStyle(Color.Text.primary)
                        }

                        // Fields
                        VStack(spacing: 20) {
                            LumoriaInputField(
                                label: "Email address",
                                placeholder: "Your email address",
                                text: $email,
                                contentType: .emailAddress,
                                keyboardType: .emailAddress
                            )

                            LumoriaInputField(
                                label: "Password",
                                placeholder: "Your password",
                                text: $password,
                                isSecure: true,
                                contentType: .password
                            )
                        }

                        // Actions
                        VStack(spacing: 12) {
                            if let errorMessage {
                                Text(errorMessage)
                                    .font(.footnote)
                                    .foregroundStyle(Color.Feedback.Danger.text)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Button(action: submit) {
                                if isLoading {
                                    ProgressView().tint(Color.Text.OnColor.white)
                                } else {
                                    Text("Log in")
                                }
                            }
                            .lumoriaButtonStyle(.primary)
                            .disabled(isLoading || email.isEmpty || password.isEmpty)

                            Button("Forgot password?") {
                                showForgotPassword = true
                            }
                            .lumoriaButtonStyle(.tertiary)
                            .sheet(isPresented: $showForgotPassword) {
                                ForgotPasswordView()
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 120) // reserve space for pinned button
                    .contentShape(Rectangle())
                    .onTapGesture { dismissKeyboard() }
                }

                Spacer(minLength: 0)
            }

            // Pinned bottom CTA — stays anchored regardless of keyboard
            VStack {
                Spacer()
                Button("Create account") {
                    dismiss()
                    // Small delay so dismiss animation completes before showing sign up
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        onCreateAccount()
                    }
                }
                .lumoriaButtonStyle(.secondary)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(38)
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

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }

    private func submit() {
        errorMessage = nil
        isLoading = true
        let domain = AnalyticsIdentity.emailDomain(email) ?? "unknown"
        Analytics.track(.loginSubmitted(emailDomain: domain))

        Task {
            defer { isLoading = false }
            do {
                try await supabase.auth.signIn(email: email, password: password)
                if let user = supabase.auth.currentUser, user.emailConfirmedAt == nil {
                    let blockedEmail = email
                    try? await supabase.auth.signOut()
                    unverifiedEmail = blockedEmail
                    return
                }
                // Note: Login Succeeded is fired by AuthManager on the .signedIn state change.
            } catch {
                let lowered = error.localizedDescription.lowercased()
                if lowered.contains("email not confirmed") || lowered.contains("email_not_confirmed") {
                    unverifiedEmail = email
                    return
                }
                let errType: AuthErrorTypeProp = {
                    if lowered.contains("invalid") || lowered.contains("credentials") { return .invalid_credentials }
                    if lowered.contains("network") || lowered.contains("offline") { return .network }
                    if lowered.contains("cancel") { return .cancelled }
                    return .unknown
                }()
                Analytics.track(.loginFailed(errorType: errType))
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    LogInView()
}
