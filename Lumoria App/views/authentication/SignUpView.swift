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
        case .empty:  return String(localized: "Password strength")
        case .weak:   return String(localized: "Weak")
        case .fair:   return String(localized: "Fair")
        case .good:   return String(localized: "Good")
        case .strong: return String(localized: "Strong")
        }
    }

    var color: Color {
        switch self {
        case .empty:  return Color("Colors/Opacity/Black/inverse/10")
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
                        .fill(index <= strength.rawValue ? strength.color : Color("Colors/Opacity/Black/inverse/10"))
                        .frame(height: 4)
                        .animation(.easeInOut(duration: 0.2), value: strength.rawValue)
                }
            }
            Text(strength.label)
                .font(.caption)
                .foregroundStyle(strength == .empty ? Color.Text.tertiary : strength.color)
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
        ZStack {
            Color.Background.default
                .ignoresSafeArea()

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

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Let's get started")
                                .font(.largeTitle.bold())
                                .foregroundStyle(Color.Text.primary)

                            Text("Let's create your account")
                                .font(.body)
                                .foregroundStyle(Color.Text.primary)
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
                                        .foregroundStyle(Color.Text.tertiary)
                                    requirementRow("1 uppercase letter (A–Z)")
                                    requirementRow("1 lowercase letter (a–z)")
                                    requirementRow("1 number (0–9)")
                                    requirementRow("1 special character (!@#$%^&*)")
                                }
                                .font(.footnote)
                                .foregroundStyle(Color.Text.tertiary)
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
                                .foregroundStyle(Color.Feedback.Danger.text)
                        }

                        // Primary CTA
                        Button(action: submit) {
                            if isLoading {
                                ProgressView().tint(Color.Text.OnColor.white)
                            } else {
                                Text("Create account")
                            }
                        }
                        .lumoriaButtonStyle(.primary)
                        .disabled(!canSubmit)

                        SocialAuthButtons(mode: .signUp)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 120)
                    .contentShape(Rectangle())
                    .onTapGesture { dismissKeyboard() }
                }

                Spacer(minLength: 0)
            }

            // Pinned bottom CTA — stays anchored regardless of keyboard
            VStack {
                Spacer()
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
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .onAppear { Analytics.track(.signupStarted) }
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(38)
        .alert("Check your email", isPresented: $showConfirmation) {
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            Text("We sent a confirmation link to \(email). Tap it on this iPhone to activate your account, then log in. You can't log in until your email is verified.")
        }
    }

    // MARK: Helpers

    private func requirementRow(_ text: LocalizedStringKey) -> some View {
        Label(text, systemImage: "circle.fill")
            .labelStyle(BulletLabelStyle())
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
        Analytics.track(.signupSubmitted(emailDomain: domain, hasName: !name.isEmpty))

        Task {
            defer { isLoading = false }
            do {
                try await supabase.auth.signUp(
                    email: email,
                    password: password,
                    data: ["display_name": .string(name)],
                    redirectTo: AuthRedirect.emailConfirmed
                )
                Analytics.track(.signupVerificationSent(emailDomain: domain))
                showConfirmation = true
            } catch {
                let errType: AuthErrorTypeProp = {
                    let msg = error.localizedDescription.lowercased()
                    if msg.contains("registered") || msg.contains("exists") { return .email_in_use }
                    if msg.contains("password") { return .weak_password }
                    if msg.contains("network") || msg.contains("offline") { return .network }
                    return .unknown
                }()
                Analytics.track(.signupFailed(errorType: errType))
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
