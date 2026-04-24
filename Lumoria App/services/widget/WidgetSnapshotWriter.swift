//
//  WidgetSnapshotWriter.swift
//  Lumoria App
//
//  Writes decrypted memory + ticket data to the shared App Group container
//  so the Memory widget (a separate process) can read it without touching
//  Supabase or the encryption key. Also pre-renders small PNGs of each
//  ticket's `TicketPreview` for the medium widget variant — SwiftUI
//  `ImageRenderer` is heavy for a widget extension to run on every tick.
//
//  Only compiled into the main app target.
//

import Combine
import CoreLocation
import Foundation
import SwiftUI
import WidgetKit

@MainActor
final class WidgetSnapshotWriter: ObservableObject {

    static let shared = WidgetSnapshotWriter()

    private var cancellables = Set<AnyCancellable>()
    private var pendingTask: Task<Void, Never>?
    /// Up to N tickets pre-rendered per memory. Medium variant only ever
    /// shows 3 at a time — we keep a small pool so rotation feels fresh
    /// without blowing up render cost.
    private static let ticketImagePoolSize = 10
    /// Fixed render size; the widget scales these tilted. Horizontal
    /// tickets match the 3:2 feel on the design, vertical use 1:1.8.
    private static let horizontalSize = CGSize(width: 340, height: 200)
    private static let verticalSize   = CGSize(width: 200, height: 340)

    private init() {}

    // MARK: - Observation

    /// Called once from the app's root so snapshot writes follow every
    /// update to the authoritative stores. Debounces — a burst of
    /// `@Published` changes (e.g. load → 20 tickets landing one by one)
    /// collapses into a single write.
    func observe(
        memoriesStore: MemoriesStore,
        ticketsStore: TicketsStore
    ) {
        cancellables.removeAll()

        Publishers.CombineLatest(
            memoriesStore.$memories,
            ticketsStore.$tickets
        )
        .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
        .sink { [weak self] memories, tickets in
            self?.scheduleWrite(memories: memories, tickets: tickets)
        }
        .store(in: &cancellables)
    }

    private func scheduleWrite(memories: [Memory], tickets: [Ticket]) {
        pendingTask?.cancel()
        pendingTask = Task { @MainActor [weak self] in
            guard let self, !Task.isCancelled else { return }
            await self.write(memories: memories, tickets: tickets)
        }
    }

    // MARK: - Write

    private func write(memories: [Memory], tickets: [Ticket]) async {
        guard let snapshotURL = WidgetSharedContainer.snapshotURL,
              let ticketsFolderURL = WidgetSharedContainer.ticketsFolderURL
        else {
            print("[WidgetSnapshotWriter] App Group container unavailable")
            return
        }

        try? FileManager.default.createDirectory(
            at: ticketsFolderURL,
            withIntermediateDirectories: true
        )

        var memorySnapshots: [WidgetMemorySnapshot] = []
        var keepFilenames: Set<String> = []

        for memory in memories {
            let ticketsInMemory = tickets.filter { $0.memoryIds.contains(memory.id) }
            let pool = Array(ticketsInMemory.prefix(Self.ticketImagePoolSize))

            var refs: [WidgetTicketImageRef] = []
            for ticket in pool {
                let filename = "\(ticket.id.uuidString).png"
                let url = ticketsFolderURL.appendingPathComponent(filename)
                renderTicketIfStale(ticket: ticket, to: url)
                refs.append(
                    WidgetTicketImageRef(
                        ticketId: ticket.id,
                        filename: filename,
                        orientation: ticket.orientation == .horizontal ? .horizontal : .vertical
                    )
                )
                keepFilenames.insert(filename)
            }

            let categoryRawValues = orderedCategoryRawValues(for: ticketsInMemory)
            let kmTotal = totalKilometres(for: ticketsInMemory)
            let dayCount = dayCount(for: memory, tickets: ticketsInMemory)

            memorySnapshots.append(
                WidgetMemorySnapshot(
                    id: memory.id,
                    name: memory.name,
                    emoji: memory.emoji,
                    colorFamily: memory.colorFamily,
                    ticketCount: ticketsInMemory.count,
                    categoryStyleRawValues: categoryRawValues,
                    kmTotal: kmTotal,
                    dayCount: dayCount,
                    ticketImageRefs: refs
                )
            )
        }

        pruneOrphanImages(folder: ticketsFolderURL, keep: keepFilenames)

        let snapshot = WidgetSnapshot(lastUpdated: Date(), memories: memorySnapshots)
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(snapshot)
            try data.write(to: snapshotURL, options: .atomic)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("[WidgetSnapshotWriter] write failed:", error)
        }
    }

    // MARK: - Ticket rendering

    private func renderTicketIfStale(ticket: Ticket, to url: URL) {
        let fm = FileManager.default
        if let attrs = try? fm.attributesOfItem(atPath: url.path),
           let mtime = attrs[.modificationDate] as? Date,
           mtime >= ticket.updatedAt {
            return
        }

        let size = ticket.orientation == .horizontal ? Self.horizontalSize : Self.verticalSize
        let content = TicketPreview(ticket: ticket, isCentered: false)
            .frame(width: size.width, height: size.height)
            .background(Color.clear)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 3.0
        guard let uiImage = renderer.uiImage, let data = uiImage.pngData() else {
            return
        }
        try? data.write(to: url, options: .atomic)
    }

    private func pruneOrphanImages(folder: URL, keep: Set<String>) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil
        ) else { return }
        for file in files where !keep.contains(file.lastPathComponent) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    // MARK: - Derivations

    private func orderedCategoryRawValues(for tickets: [Ticket]) -> [String] {
        let counts = Dictionary(grouping: tickets, by: { $0.kind.categoryStyle.rawValue })
            .mapValues(\.count)
        return counts
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.key < rhs.key
            }
            .map(\.key)
    }

    private func totalKilometres(for tickets: [Ticket]) -> Int? {
        var metres: Double = 0
        for t in tickets {
            guard let origin = t.originLocation, let destination = t.destinationLocation else {
                continue
            }
            let a = CLLocation(latitude: origin.lat, longitude: origin.lng)
            let b = CLLocation(latitude: destination.lat, longitude: destination.lng)
            metres += a.distance(from: b)
        }
        guard metres > 0 else { return nil }
        return Int((metres / 1000.0).rounded())
    }

    private func dayCount(for memory: Memory, tickets: [Ticket]) -> Int? {
        if let start = memory.startDate, let end = memory.endDate {
            let days = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
            return max(1, days + 1)
        }
        guard let earliest = tickets.map(\.createdAt).min(),
              let latest   = tickets.map(\.createdAt).max()
        else { return nil }
        let days = Calendar.current.dateComponents([.day], from: earliest, to: latest).day ?? 0
        return max(1, days + 1)
    }
}
