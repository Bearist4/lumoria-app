//
//  WidgetSnapshotStore.swift
//  Lumoria (widget)
//
//  Reads the JSON snapshot written by `WidgetSnapshotWriter` in the main
//  app. All widget-side data access flows through here.
//

import Foundation

enum WidgetSnapshotStore {

    static func load() -> WidgetSnapshot? {
        guard let url = WidgetSharedContainer.snapshotURL,
              let data = try? Data(contentsOf: url)
        else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }
}
