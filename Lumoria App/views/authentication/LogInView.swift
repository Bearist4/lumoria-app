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

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                // Toolbar — X dismiss button
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.05))
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
                                .font(.system(size: 34, weight: .bold))
                                .tracking(0.4)
                                .foregroundStyle(.black)

                            Text("Log in to your Lumoria account")
                                .font(.system(size: 17, weight: .regular))
                                .tracking(-0.43)
                                .foregroundStyle(.black)
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
                                    .foregroundStyle(Color(hex: "D94544"))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Button(action: submit) {
                                if isLoading {
                                    ProgressView().tint(.white)
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
                }

                Spacer(minLength: 0)
            }

            // Pinned bottom CTA
            Button("Create an account") {
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
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(38)
    }

    private func submit() {
        errorMessage = nil
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                try await supabase.auth.signIn(email: email, password: password)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    LogInView()
}
