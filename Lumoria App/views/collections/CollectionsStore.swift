//
//  CollectionsStore.swift
//  Lumoria App
//
//  Loads / creates / deletes the signed-in user's collections via Supabase.
//

import Foundation
import Supabase
import SwiftUI
import CoreLocation
import Combine

@MainActor
final class CollectionsStore: ObservableObject {
    @Published private(set) var collections: [Collection] = []
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // MARK: - Load

    func load() async {
        isLoading = true
        defer { isLoading = false }

        guard supabase.auth.currentUser != nil else {
            collections = []
            return
        }

        do {
            let rows: [CollectionRow] = try await supabase
                .from("collections")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            self.collections = rows.compactMap { row in
                do { return try row.toCollection() }
                catch {
                    print("[CollectionsStore] skipping row \(row.id):", error)
                    return nil
                }
            }
            self.errorMessage = nil
        } catch is CancellationError {
            // View dismissed mid-load — normal, don't surface.
        } catch let error as URLError where error.code == .cancelled {
            // URLSession cancellation — same treatment.
        } catch {
            self.errorMessage = "Couldn’t load collections. \(error.localizedDescription)"
            print("[CollectionsStore] load failed:", error)
        }
    }

    // MARK: - Create

    @discardableResult
    func create(
        name: String,
        colorFamily: String,
        location: SelectedLocation?
    ) async -> Collection? {

        guard let userId = supabase.auth.currentUser?.id else {
            errorMessage = "You need to be signed in to create a collection."
            return nil
        }

        do {
            let payload = try NewCollectionPayload.make(
                userId: userId,
                name: name,
                colorFamily: colorFamily,
                location: location
            )

            let row: CollectionRow = try await supabase
                .from("collections")
                .insert(payload)
                .select()
                .single()
                .execute()
                .value
            let inserted = try row.toCollection()

            collections.insert(inserted, at: 0)
            errorMessage = nil
            return inserted
        } catch {
            errorMessage = "Couldn’t save collection. \(error.localizedDescription)"
            print("[CollectionsStore] create failed:", error)
            return nil
        }
    }

    // MARK: - Update

    func update(
        _ collection: Collection,
        name: String,
        colorFamily: String,
        location: SelectedLocation?
    ) async {

        do {
            let payload = try UpdateCollectionPayload.make(
                name: name,
                colorFamily: colorFamily,
                location: location
            )

            try await supabase
                .from("collections")
                .update(payload)
                .eq("id", value: collection.id.uuidString)
                .execute()

            if let idx = collections.firstIndex(where: { $0.id == collection.id }) {
                var c = collections[idx]
                c.name = name
                c.colorFamily = colorFamily
                c.locationName = location?.title
                c.locationLat = location?.coordinate.latitude
                c.locationLng = location?.coordinate.longitude
                collections[idx] = c
            }
            errorMessage = nil
        } catch {
            errorMessage = "Couldn’t update collection. \(error.localizedDescription)"
            print("[CollectionsStore] update failed:", error)
        }
    }

    // MARK: - Delete

    func delete(_ collection: Collection) async {
        do {
            try await supabase
                .from("collections")
                .delete()
                .eq("id", value: collection.id.uuidString)
                .execute()

            collections.removeAll { $0.id == collection.id }
        } catch {
            errorMessage = "Couldn’t delete collection. \(error.localizedDescription)"
            print("[CollectionsStore] delete failed:", error)
        }
    }
}
