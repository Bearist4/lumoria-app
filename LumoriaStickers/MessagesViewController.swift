//
//  MessagesViewController.swift
//  LumoriaStickers (iMessage app extension)
//
//  Reads the shared sticker manifest the main app writes into the App
//  Group container and vends its entries as `MSSticker`s. The extension
//  never touches the network, Supabase, or the Keychain — everything
//  the browser shows has already been rendered by the main app.
//

import Messages
import UIKit

final class MessagesViewController: MSStickerBrowserViewController {

    private var stickers: [MSSticker] = []

    // Empty-state overlay shown when the user has no rendered tickets
    // in the shared cache.
    private let emptyStateView = EmptyStateView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(emptyStateView)
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        reload()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    // MARK: - Data source

    override func numberOfStickers(in stickerBrowserView: MSStickerBrowserView) -> Int {
        stickers.count
    }

    override func stickerBrowserView(
        _ stickerBrowserView: MSStickerBrowserView,
        stickerAt index: Int
    ) -> MSSticker {
        stickers[index]
    }

    // MARK: - Reload

    private func reload() {
        let manifestExists: Bool = {
            guard let url = StickerAppGroup.manifestURL else { return false }
            return FileManager.default.fileExists(atPath: url.path)
        }()

        let manifest = StickerManifest.load()
        let built: [MSSticker] = manifest.entries.compactMap { entry in
            guard let url = StickerAppGroup.pngURL(for: entry.filename),
                  FileManager.default.fileExists(atPath: url.path)
            else {
                return nil
            }
            return try? MSSticker(
                contentsOfFileURL: url,
                localizedDescription: entry.label
            )
        }
        stickers = built

        stickerBrowserView.reloadData()

        if stickers.isEmpty {
            emptyStateView.isHidden = false
            // No manifest at all → user hasn't opened Lumoria yet on this
            // install. Any other empty case (manifest present but no
            // entries) means they've run the app but have no tickets.
            emptyStateView.configure(manifestExists: manifestExists)
        } else {
            emptyStateView.isHidden = true
        }
    }
}

// MARK: - Empty state

private final class EmptyStateView: UIView {

    private let title = UILabel()
    private let subtitle = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        title.font = .preferredFont(forTextStyle: .headline)
        title.textColor = .label
        title.textAlignment = .center
        title.numberOfLines = 0

        subtitle.font = .preferredFont(forTextStyle: .subheadline)
        subtitle.textColor = .secondaryLabel
        subtitle.textAlignment = .center
        subtitle.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [title, subtitle])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        // Default copy until `configure` is called.
        configure(manifestExists: true)
    }

    /// `manifestExists == false` means the main app has never run on this
    /// install, so the extension has no cache to read. All other empty
    /// cases (manifest present with zero entries) mean the user simply
    /// has no tickets yet.
    func configure(manifestExists: Bool) {
        if manifestExists {
            title.text = "Nothing here yet."
            subtitle.text = "Craft a ticket in Lumoria."
        } else {
            title.text = "Nothing here yet."
            subtitle.text = "Open Lumoria to sync your tickets."
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
