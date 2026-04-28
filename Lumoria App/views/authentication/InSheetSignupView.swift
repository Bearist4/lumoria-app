//
//  InSheetSignupView.swift
//  Lumoria App
//
//  Signup surface rendered inside the floating auth sheet after the
//  email-existence check returns `.doesNotExist`. Email locked. Strength
//  bar reuses the algorithm from SignUpView (kept private there); we
//  inline an equivalent rather than refactoring out — the existing view
//  is left untouched.
//

import SwiftUI

private enum InSheetPwStrength: Int {
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

    static func score(for password: String) -> InSheetPwStrength {
        guard !password.isEmpty else { return .empty }
        var score = 0
        if password.range(of: "[A-Z]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[a-z]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[0-9]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[!@#$%^&*]", options: .regularExpression) != nil { score += 1 }
        return InSheetPwStrength(rawValue: score) ?? .empty
    }
}

struct InSheetSignupView: View {
    let email: String
    @EnvironmentObject private var auth: AuthManager
    var onSuccess: () -> Void = {}

    @State private var name = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showConfirmation = false

    private var strength: InSheetPwStrength { .score(for: password) }
    private var passwordValid: Bool { password.count >= 8 && strength == .strong }
    private var passwordsMatch: Bool { !confirmPassword.isEmpty && password == confirmPassword }
    private var canSubmit: Bool {
        !name.isEmpty && passwordValid && passwordsMatch && !isLoading
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Let's create your account")
                        .font(.title2.bold())
                        .foregroundStyle(Color.Text.primary)
                    Text(email)
                        .font(.subheadline)
                        .foregroundStyle(Color.Text.secondary)
                }

                LumoriaInputField(
                    label: "Name",
                    placeholder: "Your name",
                    text: $name,
                    contentType: .name
                )

                VStack(alignment: .leading, spacing: 8) {
                    LumoriaInputField(
                        label: "Password",
                        placeholder: "Your password",
                        text: $password,
                        isSecure: true,
                        contentType: .newPassword
                    )

                    HStack(spacing: 2) {
                        ForEach(1...4, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(i <= strength.rawValue ? strength.color : Color("Colors/Opacity/Black/inverse/10"))
                                .frame(height: 4)
                        }
                    }
                    Text(strength.label)
                        .font(.caption)
                        .foregroundStyle(strength == .empty ? Color.Text.tertiary : strength.color)
                }

                LumoriaInputField(
                    label: "Confirm password",
                    placeholder: "Confirm your password",
                    text: $confirmPassword,
                    isSecure: true,
                    contentType: .newPassword
                )

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(Color.Feedback.Danger.text)
                }

                Button(action: submit) {
                    if isLoading {
                        ProgressView().tint(Color.Text.OnColor.white)
                    } else {
                        Text("Create account")
                    }
                }
                .lumoriaButtonStyle(.primary)
                .disabled(!canSubmit)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
        .frame(maxHeight: 560)
        .alert("Check your email", isPresented: $showConfirmation) {
            Button("OK", role: .cancel) { onSuccess() }
        } message: {
            Text("We sent a confirmation link to \(email). Tap it on this iPhone to activate your account, then log in.")
        }
    }

    private func submit() {
        errorMessage = nil
        isLoading = true
        let domain = AnalyticsIdentity.emailDomain(email) ?? "unknown"
        Analytics.track(.signupSubmitted(emailDomain: domain, hasName: !name.isEmpty))

        Task {
            defer { isLoading = false }
            do {
                try await auth.signUp(name: name, email: email, password: password)
                Analytics.track(.signupVerificationSent(emailDomain: domain))
                showConfirmation = true
            } catch {
                Analytics.track(.signupFailed(errorType: .unknown))
                errorMessage = error.localizedDescription
            }
        }
    }
}
