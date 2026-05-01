//
//  ShareViewController.swift
//  LumoriaShareImport
//
//  Silent share-sheet handler that runs OCR + classification on the
//  shared payload (image/text/URL), writes the parsed result into
//  the App Group, and prompts the user to open Lumoria.
//

import UIKit
import os.log

private let extensionLog = OSLog(
    subsystem: "bearista.Lumoria-App.LumoriaShareImport",
    category: "import"
)

final class ShareViewController: UIViewController {

    private var didProcess = false

    private let statusLabel = UILabel()
    private let subtitleLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        statusLabel.text = "Reading…"
        statusLabel.textColor = .label
        statusLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.text = " "
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.font = .systemFont(ofSize: 15, weight: .regular)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(statusLabel)
        view.addSubview(subtitleLabel)
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -16),
            subtitleLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
        ])

        os_log("ShareViewController loaded", log: extensionLog, type: .default)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didProcess else { return }
        didProcess = true
        Task { await process() }
    }

    private func showSavedState(_ subtitle: String) {
        statusLabel.text = "Ready"
        subtitleLabel.text = subtitle
    }

    private func showErrorState(_ message: String) {
        statusLabel.text = "Couldn't read"
        subtitleLabel.text = message
    }

    private func finishAfterDelay(_ seconds: TimeInterval = 1.6) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    // MARK: - Processing

    private func process() async {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = item.attachments, !attachments.isEmpty else {
            os_log("no attachments", log: extensionLog, type: .default)
            showErrorState("Nothing to read.")
            finishAfterDelay()
            return
        }

        let payload = await loadPayload(from: attachments)
        guard !payload.text.isEmpty else {
            os_log("empty payload after extraction", log: extensionLog, type: .default)
            showErrorState("We couldn't find any ticket details.")
            finishAfterDelay()
            return
        }

        // Full text dump for debugging classification + extraction
        // mismatches between fixture tests and real OCR output.
        // Filter Console.app by subsystem `bearista.Lumoria-App.LumoriaShareImport`
        // (or process LumoriaShareImport) to read these.
        os_log("=== payload.text (length=%d) ===\n%{public}@",
               log: extensionLog, type: .default,
               payload.text.count, payload.text)

        var classification = ShareCategoryClassifier.classify(text: payload.text)
        os_log(
            "classified: category=%{public}@ confidence=%.2f signals=%{public}@",
            log: extensionLog, type: .default,
            classification.category ?? "nil",
            classification.confidence,
            classification.signals.joined(separator: ",")
        )

        var flight: SharePlaneFields?
        var event: ShareConcertFields?
        switch classification.category {
        case "plane":
            flight = SharePlaneExtractor.extract(text: payload.text)
            if let f = flight {
                os_log(
                    "plane fields: flightNumber=%{public}@ origin=%{public}@ dest=%{public}@ gate=%{public}@ seat=%{public}@ terminal=%{public}@",
                    log: extensionLog, type: .default,
                    f.flightNumber, f.originCode, f.destinationCode,
                    f.gate, f.seat, f.terminal
                )
            }
        case "concert":
            event = ShareConcertExtractor.extract(text: payload.text)
            if let e = event {
                os_log(
                    "concert fields: artist=%{public}@ tour=%{public}@ venue=%{public}@ ticketNumber=%{public}@",
                    log: extensionLog, type: .default,
                    e.artist, e.tourName, e.venue, e.ticketNumber
                )
            }
        default:
            // Regex/keyword classifier didn't clear the threshold —
            // fall back to on-device Foundation Models when the
            // device supports it. iOS 26+ + Apple Intelligence only.
            if #available(iOS 26.0, *) {
                if let guess = await ShareFoundationModelsExtractor.guess(text: payload.text) {
                    os_log(
                        "FM guess: category=%{public}@ artist=%{public}@ tour=%{public}@ venue=%{public}@ flight=%{public}@",
                        log: extensionLog, type: .default,
                        guess.category,
                        guess.artist ?? "nil",
                        guess.tourName ?? "nil",
                        guess.venue ?? "nil",
                        guess.flightNumber ?? "nil"
                    )
                    switch guess.category.lowercased() {
                    case "plane":
                        flight = guess.toPlaneFields()
                        classification = ShareClassification(
                            category: "plane",
                            confidence: 0.6,
                            signals: classification.signals + ["fm:fallback"]
                        )
                    case "concert":
                        event = guess.toConcertFields()
                        classification = ShareClassification(
                            category: "concert",
                            confidence: 0.6,
                            signals: classification.signals + ["fm:fallback"]
                        )
                    default:
                        break
                    }
                }
            }
        }

        let result = ShareImportResult(
            classification: classification,
            flight: flight,
            event: event,
            payload: payload
        )

        do {
            _ = try SharePayloadHandoff.writePending(result)
            os_log("wrote pending share JSON", log: extensionLog, type: .default)
            let subtitle: String
            switch classification.category {
            case "plane":   subtitle = "Open Lumoria to finish your plane ticket."
            case "concert": subtitle = "Open Lumoria to finish your concert ticket."
            default:        subtitle = "Open Lumoria to pick a category."
            }
            showSavedState(subtitle)
            finishAfterDelay(1.6)
        } catch {
            os_log("write failed: %{public}@", log: extensionLog, type: .error,
                   String(describing: error))
            showErrorState("Couldn't stage your ticket for import.")
            finishAfterDelay()
        }
    }

    // MARK: - Payload extraction

    private func loadPayload(from providers: [NSItemProvider]) async -> SharePayload {
        var combinedText = ""
        var imageData: Data?
        var sourceURL: URL?

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.image") {
                if let image = await loadImage(from: provider) {
                    let recognized = await SharePayloadOCR.recognize(image: image)
                    combinedText.appendLine(recognized)
                    if let png = image.pngData() {
                        imageData = png
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier("public.plain-text") ||
                      provider.hasItemConformingToTypeIdentifier("public.text") {
                if let text = await loadText(from: provider) {
                    combinedText.appendLine(text)
                }
            } else if provider.hasItemConformingToTypeIdentifier("public.url") {
                if let url = await loadURL(from: provider) {
                    sourceURL = url
                    combinedText.appendLine(url.absoluteString)
                }
            }
        }

        return SharePayload(
            text: combinedText.trimmingCharacters(in: .whitespacesAndNewlines),
            image: imageData,
            sourceURL: sourceURL
        )
    }

    private func loadImage(from provider: NSItemProvider) async -> UIImage? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: "public.image", options: nil) { item, _ in
                if let url = item as? URL,
                   let data = try? Data(contentsOf: url),
                   let image = UIImage(data: data) {
                    continuation.resume(returning: image)
                } else if let image = item as? UIImage {
                    continuation.resume(returning: image)
                } else if let data = item as? Data,
                          let image = UIImage(data: data) {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func loadText(from provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { item, _ in
                continuation.resume(returning: item as? String)
            }
        }
    }

    private func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: "public.url", options: nil) { item, _ in
                continuation.resume(returning: item as? URL)
            }
        }
    }
}

private extension String {
    mutating func appendLine(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !isEmpty { append("\n") }
        append(trimmed)
    }
}
