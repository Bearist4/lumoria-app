//
//  ImportStep.swift
//  Lumoria App
//
//  Funnel step inserted between orientation and form when the user
//  launched via an Import entry point. Today only Apple Wallet
//  `.pkpass` is wired; other sources (PDF, email) are deferred.
//

import SwiftUI
import UniformTypeIdentifiers

struct NewTicketImportStep: View {

    @ObservedObject var funnel: NewTicketFunnel

    @State private var isPicking = false
    @State private var isParsing = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            switch funnel.importSource {
            case .share:
                shareImportBody
            case .wallet, .none:
                walletImportBody
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fileImporter(
            isPresented: $isPicking,
            allowedContentTypes: [pkPassType],
            allowsMultipleSelection: false
        ) { result in
            handlePickResult(result)
        }
        .onAppear {
            // Wallet path: pass data delivered via the app-root share
            // handler skips the file picker — parse immediately.
            if funnel.importSource == .wallet, let data = funnel.pendingPassData {
                funnel.pendingPassData = nil
                parse(data: data)
            }
            // Share path: result was parsed in the extension; apply
            // immediately and advance to .form.
            if funnel.importSource == .share, let result = funnel.pendingShareImport {
                funnel.pendingShareImport = nil
                funnel.applyShareImport(result)
            }
        }
    }

    @ViewBuilder
    private var walletImportBody: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)
            illustration
            VStack(spacing: 8) {
                Text(isParsing ? "Reading pass…" : "Drop in a boarding pass")
                    .font(.title3.bold())
                    .foregroundStyle(Color.Text.primary)
                Text("Pick a `.pkpass` from Files and we’ll prefill every field we can read.")
                    .font(.subheadline)
                    .foregroundStyle(Color.Text.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            if let errorMessage {
                errorBanner(errorMessage)
            }
            Spacer(minLength: 0)
            VStack(spacing: 12) {
                Button {
                    isPicking = true
                } label: {
                    if isParsing {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Reading pass…")
                        }
                    } else {
                        Text("Choose a file")
                    }
                }
                .lumoriaButtonStyle(.primary, size: .large)
                .disabled(isParsing)

                Button("Fill manually") {
                    funnel.importSource = nil
                    funnel.importFailureBanner = false
                    funnel.pendingPassData = nil
                    funnel.step = .form
                }
                .lumoriaButtonStyle(.tertiary, size: .large)
                .disabled(isParsing)
            }
        }
    }

    @ViewBuilder
    private var shareImportBody: some View {
        // Share-import results are parsed in the extension before the
        // funnel ever opens, so this step renders for one frame at
        // most before `.onAppear` advances to `.form`.
        VStack(spacing: 16) {
            ProgressView()
            Text("Pre-filling your ticket…")
                .font(.subheadline)
                .foregroundStyle(Color.Text.secondary)
        }
    }

    // MARK: - Picker handling

    private func handlePickResult(_ result: Result<[URL], Error>) {
        switch result {
        case .failure:
            errorMessage = String(localized: "We couldn’t open that file.")
        case .success(let urls):
            guard let url = urls.first else { return }
            parse(url: url)
        }
    }

    private func parse(url: URL) {
        // Security-scoped access is required for Files-provided URLs.
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart { url.stopAccessingSecurityScopedResource() }
        }
        guard let data = try? Data(contentsOf: url) else {
            errorMessage = String(localized: "We couldn’t read that file.")
            return
        }
        parse(data: data)
    }

    private func parse(data: Data) {
        isParsing = true
        errorMessage = nil

        guard let template = funnel.template else {
            isParsing = false
            errorMessage = String(localized: "Pick a template first.")
            return
        }

        do {
            let parsed = try TicketImportService.importPKPass(
                data: data,
                template: template
            )
            isParsing = false
            funnel.applyImported(parsed)
        } catch let error as ImportError {
            isParsing = false
            errorMessage = error.errorDescription
                ?? String(localized: "We couldn’t parse that pass.")
        } catch {
            isParsing = false
            errorMessage = String(localized: "We couldn’t read that file.")
        }
    }

    // MARK: - Visuals

    private var illustration: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.Background.elevated)
                .frame(width: 120, height: 120)
            Image(systemName: "wallet.pass")
                .font(.system(size: 56, weight: .regular))
                .foregroundStyle(Color.Text.primary)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.Feedback.Danger.icon)
            Text(message)
                .font(.footnote)
                .foregroundStyle(Color.Feedback.Danger.text)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.Feedback.Danger.subtle)
        )
        .padding(.horizontal, 8)
    }

    // MARK: - UTType

    /// `.pkpass` isn't exposed as a first-class `UTType` constant, so
    /// we resolve it by extension first (iOS registers the association
    /// via PassKit) and fall back to the reverse-DNS identifier.
    private var pkPassType: UTType {
        UTType(filenameExtension: "pkpass")
            ?? UTType("com.apple.pkpass")
            ?? .data
    }
}
