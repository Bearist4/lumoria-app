//
//  BetaCodeRedemptionView.swift
//  Lumoria App
//

import SwiftUI

struct BetaCodeRedemptionView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var email: String = ""
    @State private var code: String = ""
    @State private var isVerifying = false
    @State private var isResending = false
    @State private var resendCooldownUntil: Date? = nil
    @State private var statusMessage: String? = nil
    @State private var statusIsError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Enter your beta code")
                    .font(.title2.weight(.semibold))
                Text("Use the email you signed up with on lumoria.com and the 6-digit code we sent.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Email").font(.caption).foregroundStyle(.secondary)
                TextField("you@example.com", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Code").font(.caption).foregroundStyle(.secondary)
                LumoriaCodeInput(code: $code) { _ in
                    Task { await verify() }
                }
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(statusIsError ? .red : .green)
            }

            Button(action: { Task { await verify() } }) {
                if isVerifying {
                    ProgressView().tint(Color.Text.OnColor.white)
                } else {
                    Text("Verify code")
                }
            }
            .lumoriaButtonStyle(.primary, size: .large)
            .disabled(isVerifying || !LumoriaCodeInput.isComplete(code) || !isValidEmail)

            Button(action: { Task { await resend() } }) {
                Text(resendButtonLabel)
                    .font(.subheadline)
                    .foregroundStyle(canResend ? Color.accentColor : .secondary)
            }
            .disabled(!canResend || !isValidEmail)

            Spacer()
        }
        .padding(24)
    }

    private var isValidEmail: Bool {
        let pattern = #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    private var canResend: Bool {
        guard !isResending else { return false }
        guard let until = resendCooldownUntil else { return true }
        return Date() >= until
    }

    private var resendButtonLabel: String {
        if isResending { return "Sending…" }
        if let until = resendCooldownUntil, Date() < until {
            let secs = Int(until.timeIntervalSinceNow)
            return "Resend in \(secs)s"
        }
        return "Send a new code"
    }

    private func verify() async {
        statusMessage = nil
        isVerifying = true
        defer { isVerifying = false }

        do {
            let outcome = try await auth.redeemBetaCode(
                email: email.trimmingCharacters(in: .whitespaces),
                code: code
            )
            switch outcome {
            case .ok:
                statusIsError = false
                statusMessage = "Beta access unlocked."
                try? await Task.sleep(for: .seconds(0.6))
                dismiss()
            case .wrongCode:
                statusIsError = true
                statusMessage = "That code doesn't match. Double-check and try again."
                code = ""
            case .expired:
                statusIsError = true
                statusMessage = "That code expired. Tap 'Send a new code'."
            case .rateLimited:
                statusIsError = true
                statusMessage = "Too many tries today. Try again tomorrow."
            case .notFound:
                statusIsError = true
                statusMessage = "We don't see that email on the waitlist."
            case .alreadyClaimed:
                statusIsError = true
                statusMessage = "That email is already linked to another account."
            }
        } catch {
            statusIsError = true
            statusMessage = "Network error. Please try again."
        }
    }

    private func resend() async {
        isResending = true
        defer { isResending = false }
        await auth.resendBetaCode(email: email.trimmingCharacters(in: .whitespaces))
        // Server-side cooldown is 1 hour; mirror the lockout in the UI.
        resendCooldownUntil = Date().addingTimeInterval(60 * 60)
        statusIsError = false
        statusMessage = "If that email is on the waitlist, a new code is on the way."
    }
}

#Preview {
    BetaCodeRedemptionView()
        .environmentObject(AuthManager())
}
