//
//  ShareViewController.swift
//  LumoriaPKPassImport
//
//  Silent share-sheet handler for `.pkpass`. Reads the shared pass
//  into the App Group container, then hands control to the main app
//  via the `lumoria://import/pkpass` URL scheme. No compose UI.
//

import UIKit
import os.log

private let extensionLog = OSLog(
    subsystem: "bearista.Lumoria-App.LumoriaPKPassImport",
    category: "import"
)

final class ShareViewController: UIViewController {

    /// App Group identifier — must match the `com.apple.security.application-groups`
    /// entitlement on both the main app and this extension target.
    private let appGroupId = "group.bearista.Lumoria-App"

    /// Filename the main app looks for inside the App Group container.
    private let pendingFilename = "pending-pass.pkpass"

    /// Attachment processing runs once, from `viewDidAppear` — the view
    /// needs to be attached to its window before the responder chain
    /// climb can reach `UIApplication`, and iOS 26 is strict about that
    /// ordering for share extensions.
    private var didProcess = false

    private let statusLabel = UILabel()
    private let subtitleLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        statusLabel.text = "Importing…"
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

    private func showSavedState() {
        statusLabel.text = "Pass saved"
        subtitleLabel.text = "Open Lumoria to finish importing."
    }

    private func showErrorState(_ message: String) {
        statusLabel.text = "Couldn’t import"
        subtitleLabel.text = message
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didProcess else { return }
        didProcess = true
        processAttachment()
    }

    // MARK: - Attachment extraction

    private func processAttachment() {
        os_log("processAttachment start", log: extensionLog, type: .default)
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let provider = item.attachments?.first(where: {
                  $0.hasItemConformingToTypeIdentifier("com.apple.pkpass")
              }) else {
            os_log("no pkpass attachment", log: extensionLog, type: .default)
            finish()
            return
        }

        provider.loadItem(
            forTypeIdentifier: "com.apple.pkpass",
            options: nil
        ) { [weak self] coerced, error in
            guard let self else { return }
            if let error {
                os_log("loadItem error: %{public}@",
                       log: extensionLog, type: .error,
                       String(describing: error))
            }
            let data: Data? = {
                if let url = coerced as? URL {
                    os_log("loadItem delivered URL: %{public}@",
                           log: extensionLog, type: .default, url.absoluteString)
                    return try? Data(contentsOf: url)
                }
                if let d = coerced as? Data {
                    os_log("loadItem delivered Data (%ld bytes)",
                           log: extensionLog, type: .default, d.count)
                    return d
                }
                os_log("loadItem delivered unknown: %{public}@",
                       log: extensionLog, type: .default,
                       String(describing: coerced))
                return nil
            }()
            DispatchQueue.main.async {
                guard let data else { self.finish(); return }
                self.handoff(data: data)
            }
        }
    }

    // MARK: - Handoff

    /// Writes the pass to the App Group container and opens the main
    /// app. The URL payload is a sentinel — the main app looks in the
    /// known shared location for the actual bytes.
    private func handoff(data: Data) {
        guard let container = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            os_log("containerURL nil — App Group missing on extension",
                   log: extensionLog, type: .error)
            showErrorState("Shared storage unavailable.")
            finishAfterDelay()
            return
        }
        let target = container.appendingPathComponent(pendingFilename)
        do {
            try data.write(to: target, options: .atomic)
            os_log("wrote pass (%ld bytes) to %{public}@",
                   log: extensionLog, type: .default,
                   data.count, target.path)
        } catch {
            os_log("write failed: %{public}@",
                   log: extensionLog, type: .error,
                   String(describing: error))
            showErrorState("Couldn’t stage the pass for import.")
            finishAfterDelay()
            return
        }

        // iOS 18+ blocks share extensions from opening URLs via every
        // supported path (extensionContext.open, responder chain).
        // Present a clear "Open Lumoria" hint instead — the main app's
        // scene-active handler drains the shared pass file on next
        // foreground, so the user just needs to tap the app icon.
        showSavedState()
        finishAfterDelay(1.6)
    }

    private func finishAfterDelay(_ seconds: TimeInterval = 0.0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            self?.finish()
        }
    }

    private func finish() {
        extensionContext?.completeRequest(
            returningItems: [],
            completionHandler: nil
        )
    }
}
