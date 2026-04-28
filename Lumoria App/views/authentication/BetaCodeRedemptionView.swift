//
//  BetaCodeRedemptionView.swift
//  Lumoria App
//
//  Sheet presented after sign-in when the user is authenticated but
//  not yet linked to a waitlist row. Per Figma node 1983:129010
//  ("Beta code"). Code-only — the server resolves the waitlist email
//  from the JWT.
//

import SwiftUI

struct BetaCodeRedemptionView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var code: String = ""
    @State private var isVerifying = false
    @State private var isResending = false
    @State private var resendCooldownUntil: Date? = nil
    @State private var statusMessage: String? = nil
    @State private var statusIsError = false

    var body: some View {
        VStack(spacing: 0) {
            // Top bar with close X. Sheet's grabber is supplied by iOS.
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.primary)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle().fill(Color.black.opacity(0.05))
                        )
                }
                .accessibilityLabel("Close")
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Enter your code")
                        .font(.system(size: 34, weight: .bold))
                        .tracking(0.4)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("We've sent you a code to confirm your beta-tester account. Please enter the 6-digit code below.")
                        .font(.system(size: 17))
                        .tracking(-0.43)
                        .foregroundStyle(Color.primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 0) {
                        Text("Code")
                            .font(.system(size: 15, weight: .semibold))
                            .tracking(-0.23)
                            .foregroundStyle(Color.primary)
                        Text("*")
                            .font(.system(size: 15, weight: .semibold))
                            .tracking(-0.23)
                            .foregroundStyle(Color(red: 1.0, green: 0.526, blue: 0.494))
                    }

                    LumoriaCodeInput(code: $code) { _ in
                        Task { await verify() }
                    }
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(statusIsError ? .red : .green)
                }

                VStack(spacing: 12) {
                    Button(action: { Task { await verify() } }) {
                        ZStack {
                            if isVerifying {
                                ProgressView().tint(.white)
                            } else {
                                Text("Link my account")
                                    .font(.system(size: 17, weight: .semibold))
                                    .tracking(-0.43)
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.black)
                        )
                    }
                    .disabled(isVerifying || !LumoriaCodeInput.isComplete(code))
                    .opacity(LumoriaCodeInput.isComplete(code) ? 1 : 0.5)

                    Button(action: { Task { await resend() } }) {
                        Text(resendButtonLabel)
                            .font(.system(size: 17, weight: .semibold))
                            .tracking(-0.43)
                            .foregroundStyle(canResend ? Color.primary : .secondary)
                            .frame(maxWidth: .infinity, minHeight: 60)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.black.opacity(0.05))
                            )
                    }
                    .disabled(!canResend)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
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
        return "Resend a code"
    }

    private func verify() async {
        statusMessage = nil
        isVerifying = true
        defer { isVerifying = false }

        do {
            let outcome = try await auth.redeemBetaCode(code)
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
                statusMessage = "That code expired. Tap 'Resend a code'."
            case .rateLimited:
                statusIsError = true
                statusMessage = "Too many tries today. Try again tomorrow."
            case .notFound:
                statusIsError = true
                statusMessage = "We don't see your email on the waitlist."
            case .alreadyClaimed:
                statusIsError = true
                statusMessage = "Your waitlist entry is already linked to another account."
            }
        } catch {
            statusIsError = true
            statusMessage = "Couldn't reach the server: \(error.localizedDescription)"
        }
    }

    private func resend() async {
        isResending = true
        defer { isResending = false }
        await auth.resendBetaCode()
        // Server-side cooldown is 1 hour; mirror in the UI.
        resendCooldownUntil = Date().addingTimeInterval(60 * 60)
        statusIsError = false
        statusMessage = "If you're on the waitlist, a new code is on the way."
    }
}

#Preview {
    BetaCodeRedemptionView()
        .environmentObject(AuthManager())
}
