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
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                // Toolbar — X dismiss
                HStack {
                    Button { dismiss() } label: {
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

                VStack(alignment: .leading, spacing: 32) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Update your password")
                            .font(.system(size: 34, weight: .bold))
                            .tracking(0.4)
                            .foregroundStyle(.black)

                        Text("No worries, we will send you an email for you to reset it.")
                            .font(.system(size: 17, weight: .regular))
                            .tracking(-0.43)
                            .foregroundStyle(.black)
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
                                .foregroundStyle(Color(hex: "D94544"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 8)
                        }

                        Button(action: submit) {
                            if isLoading {
                                ProgressView().tint(.white)
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
            Text("If \(email) is registered, you'll receive a password reset link shortly.")
        }
    }

    private func submit() {
        errorMessage = nil
        isLoading = true
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
