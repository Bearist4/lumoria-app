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

    // Buffered draft state — committed only when Done is tapped.
    @State private var emoji: String?
    @State private var name: String
    @State private var colorFamily: String
    @State private var orderedTicketIds: [UUID]

    @State private var showEmojiPicker = false
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

                // Header cards mirror the reading-mode title block —
                // same 24h padding and 64pt vertical inset on either
                // side so the gap to the tickets card stays constant
                // when toggling edit mode.
                VStack(alignment: .leading, spacing: 16) {
                    emojiCard
                    nameCard
                }
                .padding(.horizontal, 24)
                .padding(.top, 64)
                .padding(.bottom, 64)

                ticketsList
            }
        }
        // Lock layout so the keyboard appearing for the name field
        // doesn't push the ticket area up.
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showEmojiPicker) {
            EmojiPickerSheet(emoji: $emoji) { showEmojiPicker = false }
                .presentationDetents([.medium])
        }
    }

    // MARK: - Background

    private var tintBackground: Color {
        Color("Colors/\(colorFamily)/50")
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
                Task { await commit() }
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
            showEmojiPicker = true
        } label: {
            ZStack(alignment: .topTrailing) {
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

                Image(systemName: "pencil")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.Text.primary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.Background.default))
                    .offset(x: 12, y: -12)
            }
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

    private func commit() async {
        // Persist text changes if anything moved.
        if name != memory.name
            || emoji != memory.emoji
            || colorFamily != memory.colorFamily {
            await memoriesStore.update(
                memory,
                name: name,
                colorFamily: colorFamily,
                emoji: emoji,
                startDate: memory.startDate,
                endDate: memory.endDate
            )
        }

        // Persist new order if it changed.
        let originalOrder = tickets.map(\.id)
        if originalOrder != orderedTicketIds {
            await memoriesStore.reorderTickets(
                in: memory.id,
                ordered: orderedTicketIds
            )
            await ticketsStore.load()
        }

        onExit()
    }
}
