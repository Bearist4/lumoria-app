//
//  SignUpView.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=948-8013
//

import Supabase
import SwiftUI

// MARK: - Password strength

private enum PasswordStrength: Int {
    case empty = 0, weak = 1, fair = 2, good = 3, strong = 4

    var label: String {
        switch self {
        case .empty:  return "Password strength"
        case .weak:   return "Weak"
        case .fair:   return "Fair"
        case .good:   return "Good"
        case .strong: return "Strong"
        }
    }

    var color: Color {
        switch self {
        case .empty:  return Color.black.opacity(0.1)
        case .weak:   return Color(hex: "D94544")
        case .fair:   return Color(hex: "F2986A")
        case .good:   return Color(hex: "F5D46A")
        case .strong: return Color(hex: "34C759")
        }
    }

    static func score(for password: String) -> PasswordStrength {
        guard !password.isEmpty else { return .empty }
        var score = 0
        if password.range(of: "[A-Z]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[a-z]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[0-9]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[!@#$%^&*]", options: .regularExpression) != nil { score += 1 }
        return PasswordStrength(rawValue: score) ?? .empty
    }
}

// MARK: - Strength indicator view

private struct PasswordStrengthIndicator: View {
    let strength: PasswordStrength

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 2) {
                ForEach(1...4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(index <= strength.rawValue ? strength.color : Color.black.opacity(0.1))
                        .frame(height: 4)
                        .animation(.easeInOut(duration: 0.2), value: strength.rawValue)
                }
            }
            Text(strength.label)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(strength == .empty ? Color(hex: "737373") : strength.color)
                .animation(.easeInOut(duration: 0.2), value: strength.rawValue)
        }
    }
}

// MARK: - Sign Up view

struct SignUpView: View {
    var onLogIn: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showConfirmation = false

    private var strength: PasswordStrength { .score(for: password) }
    private var passwordValid: Bool { password.count >= 8 && strength == .strong }
    private var passwordsMatch: Bool { !confirmPassword.isEmpty && password == confirmPassword }
    private var canSubmit: Bool {
        !name.isEmpty && !email.isEmpty && passwordValid && passwordsMatch && !isLoading
    }

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

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Let's get started")
                                .font(.system(size: 34, weight: .bold))
                                .tracking(0.4)
                                .foregroundStyle(.black)

                            Text("Let's create your new account")
                                .font(.system(size: 17, weight: .regular))
                                .tracking(-0.43)
                                .foregroundStyle(.black)
                        }

                        // Fields
                        VStack(spacing: 20) {
                            LumoriaInputField(
                                label: "Name",
                                placeholder: "Your name",
                                text: $name,
                                contentType: .name
                            )

                            LumoriaInputField(
                                label: "Email address",
                                placeholder: "Your email address",
                                text: $email,
                                contentType: .emailAddress,
                                keyboardType: .emailAddress
                            )

                            // Password + strength indicator + requirements
                            VStack(alignment: .leading, spacing: 8) {
                                LumoriaInputField(
                                    label: "Password",
                                    placeholder: "Your password",
                                    text: $password,
                                    isSecure: true,
                                    contentType: .newPassword
                                )

                                PasswordStrengthIndicator(strength: strength)

                                // Requirements
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("Password must be at least 8 characters and include:")
                                        .foregroundStyle(Color(hex: "737373"))
                                    requirementRow("1 uppercase letter (A–Z)")
                                    requirementRow("1 lowercase letter (a–z)")
                                    requirementRow("1 number (0–9)")
                                    requirementRow("1 special character (!@#$%^&*)")
                                }
                                .font(.system(size: 13, weight: .regular))
                                .tracking(-0.08)
                                .foregroundStyle(Color(hex: "737373"))
                            }

                            LumoriaInputField(
                                label: "Confirm password",
                                placeholder: "Confirm your password",
                                text: $confirmPassword,
                                isSecure: true,
                                contentType: .newPassword
                            )
                        }

                        // Error
                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(Color(hex: "D94544"))
                        }

                        // Primary CTA
                        Button(action: submit) {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Create an account")
                            }
                        }
                        .lumoriaButtonStyle(.primary)
                        .disabled(!canSubmit)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 120)
                }

                Spacer(minLength: 0)
            }

            // Pinned bottom CTA
            Button("Log in") {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    onLogIn()
                }
            }
            .lumoriaButtonStyle(.secondary)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(38)
        .alert("Check your email", isPresented: $showConfirmation) {
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            Text("We sent a confirmation link to \(email). Open it to activate your account, then sign in.")
        }
    }

    // MARK: Helpers

    private func requirementRow(_ text: String) -> some View {
        Label(text, systemImage: "circle.fill")
            .labelStyle(BulletLabelStyle())
    }

    private func submit() {
        errorMessage = nil
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                try await supabase.auth.signUp(
                    email: email,
                    password: password,
                    data: ["display_name": .string(name)]
                )
                showConfirmation = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Bullet list label style

private struct BulletLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "circle.fill")
                .font(.system(size: 4))
                .padding(.top, 5)
            configuration.title
        }
    }
}

#Preview {
    SignUpView()
}
