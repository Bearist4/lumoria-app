//
//  MemoryEditMode.swift
//  Lumoria App
//
//  Inline edit mode for `MemoryDetailView`. Shows a tappable emoji card
//  + inline-editable name card + draggable list of `TicketEntryRow`s.
//  Top-bar buttons: color picker (opens `MemoryColorPickerSheet`) and
//  green Done (commits buffered edits via the stores and exits).
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=2028-142207
//

import SwiftUI

struct MemoryEditMode: View {

    let memory: Memory
    let tickets: [Ticket]
    let onExit: () -> Void

    @EnvironmentObject private var memoriesStore: MemoriesStore
    @EnvironmentObject private var ticketsStore: TicketsStore
    @EnvironmentObject private var colorPresenter: MemoryColorPresenter
    @EnvironmentObject private var emojiPresenter: MemoryEmojiPresenter

    // Buffered draft state — committed only when Done is tapped.
    @State private var emoji: String?
    @State private var name: String
    @State private var colorFamily: String
    @State private var orderedTicketIds: [UUID]

    @FocusState private var nameFocused: Bool

    init(memory: Memory, tickets: [Ticket], onExit: @escaping () -> Void) {
        // Sort the entry list using the memory's current sort prefs so
        // the edit view opens in the same order the user sees in
        // reading mode. Without this, the raw store order (created_at
        // desc) leaks through and reordering "starts from a different
        // list" than what the user expected.
        let sorted = MemorySortApplier.apply(
            tickets,
            field: memory.sortField,
            ascending: memory.sortAscending,
            memoryId: memory.id
        )
        self.memory = memory
        self.tickets = sorted
        self.onExit = onExit
        _emoji = State(initialValue: memory.emoji)
        _name = State(initialValue: memory.name)
        _colorFamily = State(initialValue: memory.colorFamily)
        _orderedTicketIds = State(initialValue: sorted.map(\.id))
    }

    var body: some View {
        ZStack(alignment: .top) {
            tintBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 8)

                // Header cards. Padding matches Figma 2028:142207 — a
                // small breath above and below so the tickets card
                // sits right under the name field. The edit-mode
                // header is taller than the reading-mode title block,
                // so we don't reuse reading-mode's 64pt padding here.
                VStack(alignment: .leading, spacing: 16) {
                    emojiCard
                    nameCard
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 16)

                ticketsList
            }
        }
        // Lock layout so the keyboard appearing for the name field
        // doesn't push the ticket area up.
        .ignoresSafeArea(.keyboard)
    }

    // MARK: - Background

    private var tintBackground: Color {
        Color.Background.memory(colorFamily)
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 8) {
            Button {
                let initial = ColorOption.all.first(where: { $0.family == colorFamily })
                    ?? memory.colorOption
                    ?? ColorOption.all[0]
                colorPresenter.present(initialColor: initial) { picked in
                    colorFamily = picked.family
                }
            } label: {
                Image(systemName: "paint.bucket.classic")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.Text.primary)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Color.Background.default))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Choose color")

            Spacer(minLength: 0)

            Button {
                commit()
            } label: {
                Image(systemName: "checkmark")
                    .font(.body.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Color("Colors/Green/500")))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Done")
        }
    }

    // MARK: - Header cards

    private var emojiCard: some View {
        Button {
            emojiPresenter.present(
                initialEmoji: emoji,
                onCommit: { picked in emoji = picked }
            )
        } label: {
            ZStack {
                if let emoji, !emoji.isEmpty {
                    Text(emoji)
                        .font(.system(size: 36))
                } else {
                    Text("🙂")
                        .font(.system(size: 36))
                        .opacity(0.3)
                }
            }
            .frame(width: 96, height: 96)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.Text.primary.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var nameCard: some View {
        TextField("Name", text: $name)
            .focused($nameFocused)
            .font(.title.bold())
            .foregroundStyle(Color.Text.primary)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.Text.primary.opacity(0.05))
            )
    }

    // MARK: - Tickets list

    private var ticketsList: some View {
        ReorderableTicketList(
            tickets: tickets,
            orderedIds: $orderedTicketIds
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 32,
                topTrailingRadius: 32,
                style: .continuous
            )
            .fill(Color.Background.default)
        )
        // Bleed under the home indicator so the card looks anchored to
        // the bottom edge — same as the reading-mode contentCard.
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Commit

    /// Apply edits optimistically to local state, dismiss the editor
    /// immediately, then persist via Supabase in the background. The
    /// reading view sees the new state right away; if a network write
    /// fails, `MemoriesStore` / `TicketsStore` surface the error and
    /// the next refresh will resolve any drift.
    private func commit() {
        let originalOrder = tickets.map(\.id)
        let textChanged =
            name != memory.name
            || emoji != memory.emoji
            || colorFamily != memory.colorFamily
        let orderChanged = originalOrder != orderedTicketIds

        // 1. Optimistic local updates.
        if textChanged {
            memoriesStore.applyLocalEdit(
                memoryId: memory.id,
                name: name,
                colorFamily: colorFamily,
                emoji: emoji
            )
        }
        if orderChanged {
            ticketsStore.applyLocalDisplayOrder(
                memoryId: memory.id,
                orderedIds: orderedTicketIds
            )
            memoriesStore.applyLocalSort(
                memoryId: memory.id,
                field: .manual,
                ascending: true
            )
        }

        // 2. Dismiss right away — feels instant.
        onExit()

        // 3. Persist in background. Capture references so the task
        //    survives the view's removal.
        guard textChanged || orderChanged else { return }

        let memoryId = memory.id
        let originalMemory = memory
        let pendingName = name
        let pendingEmoji = emoji
        let pendingColor = colorFamily
        let pendingOrder = orderedTicketIds
        let memories = memoriesStore

        Task {
            if textChanged {
                await memories.update(
                    originalMemory,
                    name: pendingName,
                    colorFamily: pendingColor,
                    emoji: pendingEmoji,
                    startDate: originalMemory.startDate,
                    endDate: originalMemory.endDate
                )
            }
            if orderChanged {
                // Local display order is already in sync, so we can
                // skip the heavy `ticketsStore.load()` refresh.
                await memories.reorderTickets(
                    in: memoryId,
                    ordered: pendingOrder
                )
            }
        }
    }
}
