//
//  ForgotPasswordView.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=948-8014
//

import Supabase
import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showConfirmation = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.Background.default.ignoresSafeArea()

            VStack(spacing: 0) {
                // Toolbar — X dismiss
                HStack {
                    Button { dismiss() } label: {
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

                VStack(alignment: .leading, spacing: 32) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Update your password")
                            .font(.largeTitle.bold())
                            .foregroundStyle(Color.Text.primary)

                        Text("We'll email you a reset link.")
                            .font(.body)
                            .foregroundStyle(Color.Text.primary)
                    }

                    // Field + CTA
                    VStack(spacing: 0) {
                        LumoriaInputField(
                            label: "Email address",
                            placeholder: "Your email address",
                            text: $email,
                            contentType: .emailAddress,
                            keyboardType: .emailAddress
                        )

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(Color.Feedback.Danger.text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 8)
                        }

                        Button(action: submit) {
                            if isLoading {
                                ProgressView().tint(Color.Text.OnColor.white)
                            } else {
                                Text("Send reset link")
                            }
                        }
                        .lumoriaButtonStyle(.primary)
                        .disabled(isLoading || email.isEmpty)
                        .padding(.top, 32)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                Spacer()
            }
        }
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(38)
        .alert("Check your email", isPresented: $showConfirmation) {
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            Text("If \(email) has an account, we've sent a reset link.")
        }
    }

    private func submit() {
        errorMessage = nil
        isLoading = true
        let domain = AnalyticsIdentity.emailDomain(email) ?? "unknown"
        Analytics.track(.passwordResetRequested(emailDomain: domain))

        Task {
            defer { isLoading = false }
            do {
                try await supabase.auth.resetPasswordForEmail(email)
                showConfirmation = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    ForgotPasswordView()
}
