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

    /// Filename of the JSON snapshot at the root of the shared container.
    static let snapshotFilename = "memory-widget-snapshot.json"

    /// Subfolder of the shared container holding rendered ticket mini PNGs.
    static let ticketsFolder = "ticket-minis"

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
}
