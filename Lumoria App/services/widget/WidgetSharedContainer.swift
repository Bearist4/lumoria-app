//
//  WidgetSharedContainer.swift
//  Lumoria App + Lumoria (widget)
//
//  App Group coordinates and file paths for data exchanged between the
//  main app (writer) and the Memory widget (reader). Both targets include
//  this file in their compile sources.
//

import Foundation

enum WidgetSharedContainer {

    /// App Group identifier declared in both targets' entitlements.
    static let appGroup = "group.bearista.Lumoria-App"

    /// `UserDefaults` instance backed by the App Group suite — both
    /// targets read / write user preferences through this so the widget
    /// stays in sync with what the user picked in Settings (e.g. the
    /// distance unit toggle).
    static let sharedDefaults = UserDefaults(suiteName: appGroup) ?? .standard

    /// Keys read from `sharedDefaults` by the widget.
    enum DefaultsKey {
        /// Raw value of `MapDistanceUnit`. `"km"` (default) or `"mi"`.
        static let distanceUnit = "map.distanceUnit"
        /// Mirror of `EntitlementStore.isEarlyAdopter`. The widget
        /// process can't read the in-memory store, so the main app
        /// pushes the bool here on every `refresh()`. Widgets gate
        /// their rendered content on this — false → upsell placeholder.
        static let isEarlyAdopter = "user.isEarlyAdopter"
    }

    /// Filename of the JSON snapshot at the root of the shared container.
    static let snapshotFilename = "memory-widget-snapshot.json"

    /// Subfolder of the shared container holding rendered ticket mini PNGs.
    static let ticketsFolder = "ticket-minis"

    /// Filename of the rendered brand logomark PNG at the root of the
    /// shared container. Re-rendered when the user picks a different
    /// alternate app icon so the widget badge tracks the chosen variant.
    static let brandLogomarkFilename = "brand-logomark.png"

    /// Root URL of the shared App Group container. Nil only if entitlements
    /// are misconfigured.
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
    }

    /// Absolute URL of the snapshot JSON file.
    static var snapshotURL: URL? {
        containerURL?.appendingPathComponent(snapshotFilename)
    }

    /// Absolute URL of the ticket minis folder. Created lazily on first write.
    static var ticketsFolderURL: URL? {
        containerURL?.appendingPathComponent(ticketsFolder, isDirectory: true)
    }

    /// URL for a specific ticket mini PNG by filename.
    static func ticketImageURL(filename: String) -> URL? {
        ticketsFolderURL?.appendingPathComponent(filename)
    }

    /// Absolute URL of the brand logomark PNG.
    static var brandLogomarkURL: URL? {
        containerURL?.appendingPathComponent(brandLogomarkFilename)
    }
}
