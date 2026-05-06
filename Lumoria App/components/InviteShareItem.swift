//
//  InviteShareItem.swift
//  Lumoria App
//
//  `UIActivityItemSource` that wraps the user's invite link with a
//  rich share-sheet preview: Lumoria title, app logomark icon, and
//  the destination URL. Without this the share sheet renders a bare
//  URL chip and depends on iOS racing an OG-tag fetch — which is
//  slow and often fails on the short link domain.
//
//  Pair with a separate plain-string item in `UIActivityViewController`
//  so the recipient also sees a written pitch ("I've been making
//  beautiful ticket stubs with Lumoria. Join me:") in addition to the
//  preview card. Messages / Mail / WhatsApp will treat that as the
//  body and the URL as a tappable link.
//

import LinkPresentation
import UIKit

final class InviteShareItem: NSObject, UIActivityItemSource {

    private let url: URL
    private let title: String
    private let icon: UIImage?

    init(url: URL, title: String, icon: UIImage?) {
        self.url = url
        self.title = title
        self.icon = icon
    }

    // Placeholder shown to UIActivityViewController during item-type
    // negotiation. The URL is the right shape to advertise so iOS
    // routes us into the link-preview pipeline.
    func activityViewControllerPlaceholderItem(_ ac: UIActivityViewController) -> Any {
        url
    }

    // Real payload per activity. Returning the URL lets target apps
    // (Messages, iMessage, Mail, WhatsApp, etc.) attach it as a real
    // link instead of dropping it into the body as plain text.
    func activityViewController(
        _ ac: UIActivityViewController,
        itemForActivityType type: UIActivity.ActivityType?
    ) -> Any? {
        url
    }

    // Mail subject — used when the user picks Mail as the target.
    func activityViewController(
        _ ac: UIActivityViewController,
        subjectForActivityType type: UIActivity.ActivityType?
    ) -> String {
        title
    }

    // The metadata that drives the preview banner at the top of the
    // share sheet AND the iMessage rich-link card on the recipient
    // side. Without this iOS falls back to fetching OG tags from the
    // URL on the network — slow and unreliable for short links.
    func activityViewControllerLinkMetadata(
        _ ac: UIActivityViewController
    ) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.originalURL = url
        metadata.url = url
        metadata.title = title
        if let icon {
            metadata.iconProvider = NSItemProvider(object: icon)
        }
        return metadata
    }
}
