//
//  ReorderableTicketList.swift
//  Lumoria App
//
//  Custom drag-to-reorder list for the memory edit mode. SwiftUI's
//  built-in `List` + `.onMove` injects a system drag indicator we
//  can't suppress, so we render `TicketEntryRow`s in a plain stack and
//  drive the reorder ourselves with a long-press → drag gesture.
//
//  Behavior matches Figma node 2028-142460 — dragged row scales up,
//  shadows, and follows the finger; non-dragged rows shift to make
//  space; releasing snaps to the new index.
//

import SwiftUI

struct ReorderableTicketList: View {

    let tickets: [Ticket]
    @Binding var orderedIds: [UUID]

    /// Match `TicketEntryRow.frame(height:)`.
    private let rowHeight: CGFloat = 72
    private let rowSpacing: CGFloat = 16
    private var slot: CGFloat { rowHeight + rowSpacing }

    /// `@GestureState` auto-resets to nil when the gesture ends —
    /// eliminates the class of "stale state" bugs that come from manual
    /// cleanup, including the one where exactly one reorder per session
    /// would succeed.
    @GestureState private var dragSession: DragSession?

    /// Mirror of the live drag translation. `dragSession` resets the
    /// instant the gesture ends, so `.onEnded` would see nil if it
    /// tried to read from it. We update this in `.onChanged` and read
    /// it in `.onEnded`.
    @State private var lastTranslation: CGFloat = 0

    private struct DragSession: Equatable {
        let ticketId: UUID
        var translation: CGFloat
    }

    private var orderedTickets: [Ticket] {
        let byId = Dictionary(uniqueKeysWithValues: tickets.map { ($0.id, $0) })
        return orderedIds.compactMap { byId[$0] }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: rowSpacing) {
                ForEach(Array(orderedTickets.enumerated()), id: \.element.id) { index, ticket in
                    row(ticket: ticket, index: index)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }

    @ViewBuilder
    private func row(ticket: Ticket, index: Int) -> some View {
        let isDragged = dragSession?.ticketId == ticket.id
        let yOffset = visualOffset(for: index, isDragged: isDragged)

        TicketEntryRow(ticket: ticket, showHandle: true)
            .offset(y: yOffset)
            .scaleEffect(isDragged ? 1.04 : 1, anchor: .center)
            .shadow(
                color: .black.opacity(isDragged ? 0.18 : 0),
                radius: 8, x: 0, y: 4
            )
            .opacity(isDragged ? 0.97 : 1)
            .zIndex(isDragged ? 1 : 0)
            // Only animate non-dragged rows. The dragged row must
            // follow the finger 1:1 — any spring response makes the
            // visual position lag behind the actual translation, and
            // the user drops "where they see the row" while the math
            // commits "where the translation says it is."
            .animation(
                isDragged ? nil : .interactiveSpring(response: 0.3),
                value: yOffset
            )
            .gesture(
                LongPressGesture(minimumDuration: 0.2)
                    .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
                    .updating($dragSession) { value, state, _ in
                        switch value {
                        case .first(true):
                            // Long-press recognized; arm the row.
                            state = DragSession(ticketId: ticket.id, translation: 0)
                        case .second(true, let drag):
                            state = DragSession(
                                ticketId: ticket.id,
                                translation: drag?.translation.height ?? 0
                            )
                        default:
                            break
                        }
                    }
                    .onChanged { value in
                        // Mirror the live translation to @State so
                        // .onEnded can use it even after @GestureState
                        // has already reset.
                        if case .second(_, let drag) = value, let drag {
                            lastTranslation = drag.translation.height
                        }
                    }
                    .onEnded { _ in
                        commitDrop(of: ticket, translation: lastTranslation)
                        lastTranslation = 0
                    }
            )
    }

    /// Y-offset to apply to a row at the given index. The dragged row
    /// follows the finger; other rows slide to make room based on which
    /// slot the dragged row currently occupies.
    private func visualOffset(for index: Int, isDragged: Bool) -> CGFloat {
        guard let session = dragSession else { return 0 }

        if isDragged { return session.translation }

        guard let dragIdx = orderedIds.firstIndex(of: session.ticketId) else {
            return 0
        }

        let slotsMoved = Int(round(session.translation / slot))
        let target = max(0, min(orderedIds.count - 1, dragIdx + slotsMoved))

        if target > dragIdx, index > dragIdx, index <= target {
            return -slot // shift up to fill the dragged row's old slot
        }
        if target < dragIdx, index >= target, index < dragIdx {
            return slot  // shift down to push out of the way
        }
        return 0
    }

    private func commitDrop(of ticket: Ticket, translation: CGFloat) {
        guard let currentIdx = orderedIds.firstIndex(of: ticket.id) else { return }
        let slotsMoved = Int(round(translation / slot))
        let newIdx = max(0, min(orderedIds.count - 1, currentIdx + slotsMoved))
        guard newIdx != currentIdx else { return }
        withAnimation(.spring(response: 0.35)) {
            let item = orderedIds.remove(at: currentIdx)
            orderedIds.insert(item, at: newIdx)
        }
    }
}
