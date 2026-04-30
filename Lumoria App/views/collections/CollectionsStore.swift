//
//  MemoriesStore.swift
//  Lumoria App
//
//  Loads / creates / deletes the signed-in user's memories via Supabase.
//

import Combine
import Foundation
import Supabase
import SwiftUI

@MainActor
final class MemoriesStore: ObservableObject {
    @Published private(set) var memories: [Memory] = []
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    /// Set from `ContentView` after both are in the env. Weak so the
    /// coordinator's lifetime isn't pinned to the store.
    weak var onboardingCoordinator: OnboardingCoordinator?

    #if DEBUG
    /// Preview-only flag: once `seedForPreview` runs, `load()` becomes a
    /// no-op so the unauthenticated preview path can't blank the seeded
    /// memories out.
    private var skipLoadForPreview = false
    #endif

    // MARK: - Load

    func load() async {
        #if DEBUG
        if skipLoadForPreview { return }
        #endif

        isLoading = true
        defer { isLoading = false }

        guard supabase.auth.currentUser != nil else {
            memories = []
            return
        }

        do {
            let rows: [MemoryRow] = try await supabase
                .from("memories")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            self.memories = rows.compactMap { row in
                do { return try row.toMemory() }
                catch {
                    print("[MemoriesStore] skipping row \(row.id):", error)
                    return nil
                }
            }
            self.errorMessage = nil
        } catch is CancellationError {
            // View dismissed mid-load — normal, don't surface.
        } catch let error as URLError where error.code == .cancelled {
            // URLSession cancellation — same treatment.
        } catch {
            self.errorMessage = String(localized: "Couldn’t load memories. \(error.localizedDescription)")
            print("[MemoriesStore] load failed:", error)
        }
    }

    // MARK: - Free-tier gate

    /// Whether the user can create another memory under the free-tier
    /// cap. Premium / grandfathered / lifetime / active subscriber →
    /// always true. Mirrors the enforce_memory_cap trigger.
    func canCreate(entitlement: EntitlementStore) -> Bool {
        if entitlement.hasPremium { return true }
        let cap = FreeCaps.memoryCap(rewardKind: entitlement.inviteRewardKind)
        return memories.count < cap
    }

    // MARK: - Create

    @discardableResult
    func create(
        name: String,
        colorFamily: String,
        emoji: String?,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) async -> Memory? {

        guard let userId = supabase.auth.currentUser?.id else {
            errorMessage = String(localized: "You need to be signed in to create a memory.")
            return nil
        }

        do {
            let payload = try NewMemoryPayload.make(
                userId: userId,
                name: name,
                colorFamily: colorFamily,
                emoji: emoji,
                startDate: startDate,
                endDate: endDate
            )

            let row: MemoryRow = try await supabase
                .from("memories")
                .insert(payload)
                .select()
                .single()
                .execute()
                .value
            let inserted = try row.toMemory()

            memories.insert(inserted, at: 0)
            errorMessage = nil

            let colorProp = MemoryColorFamilyProp(rawValue: colorFamily.lowercased()) ?? .gray
            Analytics.track(.memoryCreated(
                colorFamily: colorProp,
                hasEmoji: !(emoji?.isEmpty ?? true),
                nameLength: name.count
            ))
            Analytics.updateUserProperties([
                "memories_created_lifetime": memories.count,
            ])
            if memories.count == 1 {
                Analytics.track(.firstMemoryCreated(colorFamily: colorProp))
                Analytics.updateUserProperties(["has_created_first_memory": true])
            }

            if onboardingCoordinator?.currentStep == .createMemory {
                let c = onboardingCoordinator
                Task { await c?.advance(from: .createMemory) }
            }

            return inserted
        } catch {
            errorMessage = String(localized: "Couldn’t save memory. \(error.localizedDescription)")
            print("[MemoriesStore] create failed:", error)
            Analytics.track(.appError(
                domain: .memory,
                code: (error as NSError).code.description,
                viewContext: "MemoriesStore.create"
            ))
            return nil
        }
    }

    // MARK: - Update

    func update(
        _ memory: Memory,
        name: String,
        colorFamily: String,
        emoji: String?,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) async {

        let nameChanged = memory.name != name
        let colorChanged = memory.colorFamily != colorFamily
        let emojiChanged = memory.emoji != emoji

        do {
            let payload = try UpdateMemoryPayload.make(
                name: name,
                colorFamily: colorFamily,
                emoji: emoji,
                startDate: startDate,
                endDate: endDate
            )

            try await supabase
                .from("memories")
                .update(payload)
                .eq("id", value: memory.id.uuidString)
                .execute()

            if let idx = memories.firstIndex(where: { $0.id == memory.id }) {
                var m = memories[idx]
                m.name = name
                m.colorFamily = colorFamily
                m.emoji = emoji
                m.startDate = startDate
                m.endDate = endDate
                memories[idx] = m
            }
            errorMessage = nil

            Analytics.track(.memoryEdited(
                nameChanged: nameChanged,
                emojiChanged: emojiChanged,
                colorChanged: colorChanged,
                memoryIdHash: AnalyticsIdentity.hashUUID(memory.id)
            ))
        } catch {
            errorMessage = String(localized: "Couldn’t update memory. \(error.localizedDescription)")
            print("[MemoriesStore] update failed:", error)
            Analytics.track(.appError(
                domain: .memory,
                code: (error as NSError).code.description,
                viewContext: "MemoriesStore.update"
            ))
        }
    }

    // MARK: - Sort prefs

    /// Persists a per-memory sort preference. Optimistic local update so
    /// the sheet feels instant; rolls back on Supabase failure.
    func updateSort(
        memoryId: UUID,
        field: MemorySortField,
        ascending: Bool
    ) async {
        guard let idx = memories.firstIndex(where: { $0.id == memoryId }) else { return }
        let prevField = memories[idx].sortField
        let prevAsc   = memories[idx].sortAscending

        memories[idx].sortField     = field
        memories[idx].sortAscending = ascending

        let payload = UpdateMemorySortPayload(
            sortField: field.rawValue,
            sortAscending: ascending
        )

        do {
            try await supabase
                .from("memories")
                .update(payload)
                .eq("id", value: memoryId.uuidString)
                .execute()
            errorMessage = nil
        } catch {
            // Roll back if the network failed.
            if let idx = memories.firstIndex(where: { $0.id == memoryId }) {
                memories[idx].sortField     = prevField
                memories[idx].sortAscending = prevAsc
            }
            errorMessage = String(localized: "Couldn’t save sort. \(error.localizedDescription)")
            print("[MemoriesStore] updateSort failed:", error)
            Analytics.track(.appError(
                domain: .memory,
                code: (error as NSError).code.description,
                viewContext: "MemoriesStore.updateSort"
            ))
        }
    }

    // MARK: - Reorder

    /// Persists a manual order for tickets in a memory. Each ticket
    /// gets a 0-based `display_order` matching its index in `ordered`.
    /// Also flips `sort_field` to `.manual` so the new arrangement is
    /// what the detail view shows by default.
    func reorderTickets(
        in memoryId: UUID,
        ordered ticketIds: [UUID]
    ) async {
        do {
            // Postgres `update` doesn't support bulk position updates;
            // iterate. Sequential awaits keep the writes ordered.
            for (index, ticketId) in ticketIds.enumerated() {
                try await supabase
                    .from("memory_tickets")
                    .update(["display_order": index])
                    .eq("memory_id", value: memoryId.uuidString)
                    .eq("ticket_id", value: ticketId.uuidString)
                    .execute()
            }

            // Flip sort_field to manual locally + remotely. updateSort
            // already handles optimistic update + rollback.
            await updateSort(memoryId: memoryId, field: .manual, ascending: true)

            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Couldn’t save the new order. \(error.localizedDescription)")
            print("[MemoriesStore] reorderTickets failed:", error)
            Analytics.track(.appError(
                domain: .memory,
                code: (error as NSError).code.description,
                viewContext: "MemoriesStore.reorderTickets"
            ))
        }
    }

    // MARK: - Delete

    func delete(_ memory: Memory) async {
        do {
            try await supabase
                .from("memories")
                .delete()
                .eq("id", value: memory.id.uuidString)
                .execute()

            memories.removeAll { $0.id == memory.id }

            Analytics.track(.memoryDeleted(
                ticketCount: 0,
                memoryIdHash: AnalyticsIdentity.hashUUID(memory.id)
            ))
        } catch {
            errorMessage = String(localized: "Couldn’t delete memory. \(error.localizedDescription)")
            print("[MemoriesStore] delete failed:", error)
            Analytics.track(.appError(
                domain: .memory,
                code: (error as NSError).code.description,
                viewContext: "MemoriesStore.delete"
            ))
        }
    }

    // MARK: - Preview seeding

    /// Preview-only — lets `#Preview` blocks populate the store without
    /// going through Supabase. Sets `skipLoadForPreview` so the view's
    /// auto `.task { await store.load() }` doesn't wipe the seed back
    /// to an empty array when there's no authenticated user.
    func seedForPreview(_ memories: [Memory]) {
        self.memories = memories
        #if DEBUG
        skipLoadForPreview = true
        #endif
    }
}
