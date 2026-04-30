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

    // Buffered draft state — committed only when Done is tapped.
    @State private var emoji: String?
    @State private var name: String
    @State private var colorFamily: String
    @State private var orderedTicketIds: [UUID]

    @State private var showColorPicker = false
    @State private var showEmojiPicker = false
    @FocusState private var nameFocused: Bool

    init(memory: Memory, tickets: [Ticket], onExit: @escaping () -> Void) {
        self.memory = memory
        self.tickets = tickets
        self.onExit = onExit
        _emoji = State(initialValue: memory.emoji)
        _name = State(initialValue: memory.name)
        _colorFamily = State(initialValue: memory.colorFamily)
        _orderedTicketIds = State(initialValue: tickets.map(\.id))
    }

    var body: some View {
        ZStack(alignment: .top) {
            tintBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 8)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        emojiCard
                        nameCard
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
                .frame(maxHeight: 320)

                ticketsList
            }
        }
        .floatingBottomSheet(isPresented: $showColorPicker) {
            MemoryColorPickerSheet(
                initialColor: ColorOption.all.first(where: { $0.family == colorFamily })
                    ?? memory.colorOption
                    ?? ColorOption.all[0],
                onCommit: { option in colorFamily = option.family },
                onDismiss: { showColorPicker = false }
            )
        }
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
                showColorPicker = true
            } label: {
                Image(systemName: "paintbrush.fill")
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
        List {
            ForEach(orderedTickets) { ticket in
                TicketEntryRow(ticket: ticket, showHandle: false)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 0, trailing: 16))
            }
            .onMove { source, dest in
                orderedTicketIds.move(fromOffsets: source, toOffset: dest)
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(.active))
        .scrollContentBackground(.hidden)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 32,
                topTrailingRadius: 32,
                style: .continuous
            )
            .fill(Color.Background.default)
        )
    }

    private var orderedTickets: [Ticket] {
        let byId = Dictionary(uniqueKeysWithValues: tickets.map { ($0.id, $0) })
        return orderedTicketIds.compactMap { byId[$0] }
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
