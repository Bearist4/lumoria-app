//
//  HelpCenterContent.swift
//  Lumoria App
//
//  Static content for the in-app Help center. Articles mirror the public
//  guides at docs/notion-guides.md and are grouped by section.
//

import Foundation

enum HelpSection: String, Hashable, CaseIterable {
    case tickets = "Tickets"
    case export  = "Export"
}

struct HelpStep: Hashable {
    let title: String
    let body: String
}

struct HelpArticle: Hashable, Identifiable {
    let id: String
    let section: HelpSection
    let title: String
    let intro: String
    let steps: [HelpStep]
    let outro: String?
    /// Bundled video asset name (without extension) that demonstrates the flow.
    /// Nil articles render a static placeholder hero.
    let videoName: String?

    static func == (lhs: HelpArticle, rhs: HelpArticle) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum HelpCenterContent {

    static let all: [HelpArticle] = [
        createTicket,
        importFromWallet,
        browseCollection,
        editTicket,
        deleteTicket,
        saveToCameraRoll,
        shareViaMessaging,
        useInIMessage,
        useOnInstagram
    ]

    static func articles(in section: HelpSection) -> [HelpArticle] {
        all.filter { $0.section == section }
    }

    static func article(id: String) -> HelpArticle? {
        all.first { $0.id == id }
    }

    // MARK: - Tickets

    static let createTicket = HelpArticle(
        id: "create-a-ticket",
        section: .tickets,
        title: "Create a ticket",
        intro: "Every Lumoria ticket starts as a blank canvas. Pick a kind, choose a look, fill in the details — done.",
        steps: [
            HelpStep(
                title: "Tap the + to start.",
                body: "From the Collections or All tickets screen, tap the + to open the ticket funnel."
            ),
            HelpStep(
                title: "Choose the category.",
                body: "Pick Plane or Train. More kinds are on their way."
            ),
            HelpStep(
                title: "Choose the template.",
                body: "Each category has its own set of designs — Afterglow, Studio, Terminal, Heritage, Prism for planes; Express, Orient, Night for trains. Pick the one that matches the moment."
            ),
            HelpStep(
                title: "Choose the orientation.",
                body: "Vertical for a classic stub. Horizontal for a boarding-pass feel."
            ),
            HelpStep(
                title: "Fill in the details.",
                body: "Every field is optional. Fill in only what matters to you — airline, flight number, origin and destination, date, seat, gate."
            ),
            HelpStep(
                title: "Style it.",
                body: "Some templates come with palette variants — dark, warm, muted. Try a few. The preview updates instantly."
            ),
            HelpStep(
                title: "Save it forever.",
                body: "Tap Save. Watch it slide into your collection. It's yours now."
            )
        ],
        outro: nil,
        videoName: nil
    )

    static let importFromWallet = HelpArticle(
        id: "import-from-wallet",
        section: .tickets,
        title: "Import a ticket from Apple Wallet",
        intro: "If your boarding pass is already in Apple Wallet, Lumoria can read it and fill in the details for you.",
        steps: [
            HelpStep(
                title: "Open the pass.",
                body: "In Wallet, Mail, Files, or anywhere a .pkpass lives, tap the share icon."
            ),
            HelpStep(
                title: "Send it to Lumoria.",
                body: "Scroll the share sheet and tap Import to Lumoria. You'll see Pass saved — Open Lumoria and the sheet will close on its own."
            ),
            HelpStep(
                title: "Open Lumoria.",
                body: "The app picks up where Wallet left off. Lumoria reads the pass, matches the fields, and moves you straight to the form."
            ),
            HelpStep(
                title: "Choose a design.",
                body: "Pick a template, pick a style. The flight or journey details are already filled in."
            ),
            HelpStep(
                title: "Save it forever.",
                body: "Tap Save."
            )
        ],
        outro: "If something doesn't read cleanly, tap Fill manually — Lumoria will keep whatever it managed to pull, and you can finish the rest by hand.",
        videoName: nil
    )

    static let browseCollection = HelpArticle(
        id: "browse-collection",
        section: .tickets,
        title: "Browse all your tickets",
        intro: "Every ticket you save lives in All tickets — your full gallery of moments.",
        steps: [
            HelpStep(
                title: "Open All tickets.",
                body: "Tap All tickets from the home screen."
            ),
            HelpStep(
                title: "Scroll through your memories.",
                body: "Tickets arrange themselves into a two-column gallery. Vertical stubs pair up side by side; horizontal boarding passes take the full width. Tap any ticket to open it."
            ),
            HelpStep(
                title: "Sort them.",
                body: "Tap the sort icon and pick Sort by date, Sort by category, or Remove sorting. A small dot on the icon tells you when a sort is active."
            ),
            HelpStep(
                title: "Pull to refresh.",
                body: "Drag the gallery down to resync with the cloud. Anything you've made on another device shows up right here."
            )
        ],
        outro: "If your gallery is still empty, you'll see the seven-point star and a gentle nudge — your gallery starts with one tap.",
        videoName: "Sort"
    )

    static let editTicket = HelpArticle(
        id: "edit-a-ticket",
        section: .tickets,
        title: "Edit a ticket",
        intro: "Wrote the seat number wrong? Mistyped a gate? No problem. Every ticket stays editable forever.",
        steps: [
            HelpStep(
                title: "Open the ticket.",
                body: "From your collection, tap the one you want to change."
            ),
            HelpStep(
                title: "Open the menu.",
                body: "Tap the ellipsis (•••) in the top corner and choose Edit."
            ),
            HelpStep(
                title: "Change what you need.",
                body: "You'll land back in the ticket funnel with every field already filled in. Update anything — airline, date, seat, gate, passenger name, orientation. Every change previews live."
            ),
            HelpStep(
                title: "Save the changes.",
                body: "Tap Done. Your ticket updates everywhere it lives — your gallery, your iMessage sticker pack, your memories."
            )
        ],
        outro: "The template and style stay locked to keep the design consistent. If you want a different look for the same journey, save a new ticket instead.",
        videoName: nil
    )

    static let deleteTicket = HelpArticle(
        id: "delete-a-ticket",
        section: .tickets,
        title: "Delete a ticket",
        intro: "Some memories you keep, some you let go. Lumoria won't stop you.",
        steps: [
            HelpStep(
                title: "Open the ticket.",
                body: "Tap it from your collection."
            ),
            HelpStep(
                title: "Open the menu.",
                body: "Tap the ellipsis (•••) in the top corner."
            ),
            HelpStep(
                title: "Tap Delete ticket…",
                body: "Lumoria will ask once — Delete ticket or Keep ticket."
            ),
            HelpStep(
                title: "Confirm.",
                body: "Tap Delete ticket to let it go. The ticket disappears from your collection, your memories, and your iMessage sticker pack."
            )
        ],
        outro: "This one is permanent — there's no undo, so choose with care.",
        videoName: nil
    )

    // MARK: - Export

    static let saveToCameraRoll = HelpArticle(
        id: "save-to-camera-roll",
        section: .export,
        title: "Save a ticket to your Camera Roll",
        intro: "Lumoria makes export beautiful. Every ticket can leave the app as a polished image, ready for your camera roll, your lock screen, or anywhere you want to keep it.",
        steps: [
            HelpStep(
                title: "Open the ticket and tap Export.",
                body: "From any ticket, tap the ellipsis (•••) and choose Export…"
            ),
            HelpStep(
                title: "Tap Camera roll.",
                body: "The camera-roll export panel slides up with every control you need."
            ),
            HelpStep(
                title: "Dial in the look.",
                body: "Format: PNG for crisp edges and transparency, JPG for a smaller file. Crop: Full or Square. Resolution: 1x, 2x, or 3x. Background gradient and watermark toggles are yours to tune. The preview updates as you adjust."
            ),
            HelpStep(
                title: "Tap Export.",
                body: "The first time, iOS will ask for permission to add to your Photos — allow it. You'll see Saved to Camera roll and the image is yours."
            )
        ],
        outro: "Tip: a 3x PNG with gradient off is the sharpest cutout for Stories, wallpapers, and further editing.",
        videoName: nil
    )

    static let shareViaMessaging = HelpArticle(
        id: "share-via-messaging",
        section: .export,
        title: "Share a ticket via Instant Message",
        intro: "Sometimes the moment is worth sharing with one person. Lumoria makes it one tap.",
        steps: [
            HelpStep(
                title: "Open the ticket and tap Export.",
                body: "Tap the ellipsis (•••), then Export…"
            ),
            HelpStep(
                title: "Tap Instant messaging.",
                body: "Lumoria renders a high-resolution image ready to send."
            ),
            HelpStep(
                title: "Choose the app.",
                body: "iOS brings up the share sheet. Tap Messages, WhatsApp, Telegram, Signal, Messenger, Discord — whichever one the moment belongs in."
            ),
            HelpStep(
                title: "Send it.",
                body: "The ticket goes as a high-resolution image, alongside a short message you can edit before sending."
            )
        ],
        outro: "No setup, no configuration. One tap, one share.",
        videoName: nil
    )

    static let useInIMessage = HelpArticle(
        id: "imessage-sticker",
        section: .export,
        title: "Use a ticket as a sticker in iMessage",
        intro: "Every ticket you make in Lumoria becomes an iMessage sticker, automatically. No extra step, no export.",
        steps: [
            HelpStep(
                title: "Open Messages.",
                body: "Tap into any conversation."
            ),
            HelpStep(
                title: "Open the sticker drawer.",
                body: "Tap the + next to the text field, then tap Stickers. Swipe across to find the Lumoria pack."
            ),
            HelpStep(
                title: "Send the moment.",
                body: "Tap any ticket to drop it into the thread. Tap and hold to place it on top of another message."
            )
        ],
        outro: "First time using it? Open Lumoria at least once and save a ticket — that's what fills the sticker pack. Delete a ticket in Lumoria and it leaves the pack too.",
        videoName: nil
    )

    static let useOnInstagram = HelpArticle(
        id: "instagram-cutout",
        section: .export,
        title: "Use a ticket as a cutout on Instagram",
        intro: "Tickets make beautiful story stickers. Here's how to get one onto Instagram as a transparent cutout.",
        steps: [
            HelpStep(
                title: "Save the ticket to your camera roll.",
                body: "Export with PNG, Full crop, 3x resolution, background gradient off. Watermark is your call."
            ),
            HelpStep(
                title: "Open Instagram Stories.",
                body: "Tap the + at the top of your feed, then choose Story."
            ),
            HelpStep(
                title: "Add the ticket as a sticker.",
                body: "Tap the sticker icon, tap Cutout, and pick your ticket from the camera roll. Instagram lifts the ticket off the background and turns it into a sticker you can resize, rotate, and place anywhere."
            ),
            HelpStep(
                title: "Share it.",
                body: "Drop a backdrop, add a song, post."
            )
        ],
        outro: "Tip: the Studio and Heritage templates cut out especially cleanly.",
        videoName: nil
    )
}
