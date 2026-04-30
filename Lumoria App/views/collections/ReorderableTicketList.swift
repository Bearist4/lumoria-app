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

    @State private var draggingId: UUID?
    @State private var dragTranslation: CGFloat = 0

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
        let isDragged = draggingId == ticket.id
        let yOffset = visualOffset(for: index, ticketId: ticket.id, isDragged: isDragged)

        TicketEntryRow(ticket: ticket, showHandle: true)
            .offset(y: yOffset)
            .scaleEffect(isDragged ? 1.04 : 1, anchor: .center)
            .shadow(
                color: .black.opacity(isDragged ? 0.18 : 0),
                radius: 8, x: 0, y: 4
            )
            .opacity(isDragged ? 0.97 : 1)
            .zIndex(isDragged ? 1 : 0)
            .animation(.interactiveSpring(response: 0.3), value: yOffset)
            .gesture(
                LongPressGesture(minimumDuration: 0.2)
                    .sequenced(before: DragGesture(minimumDistance: 0))
                    .onChanged { value in
                        switch value {
                        case .first(true):
                            // Long-press recognized; arm but don't move yet.
                            if draggingId != ticket.id {
                                draggingId = ticket.id
                            }
                        case .second(true, let drag):
                            draggingId = ticket.id
                            dragTranslation = drag?.translation.height ?? 0
                        default:
                            break
                        }
                    }
                    .onEnded { _ in
                        commitDrop(of: ticket)
                    }
            )
    }

    /// Y-offset to apply to a row at the given index. The dragged row
    /// follows the finger; other rows slide to make room based on which
    /// slot the dragged row currently occupies.
    private func visualOffset(for index: Int, ticketId: UUID, isDragged: Bool) -> CGFloat {
        if isDragged { return dragTranslation }

        guard let dragId = draggingId,
              let dragIdx = orderedIds.firstIndex(of: dragId) else {
            return 0
        }

        let slotsMoved = Int(round(dragTranslation / slot))
        let target = max(0, min(orderedIds.count - 1, dragIdx + slotsMoved))

        if target > dragIdx, index > dragIdx, index <= target {
            return -slot // shift up to fill the dragged row's old slot
        }
        if target < dragIdx, index >= target, index < dragIdx {
            return slot  // shift down to push out of the way
        }
        return 0
    }

    private func commitDrop(of ticket: Ticket) {
        guard let currentIdx = orderedIds.firstIndex(of: ticket.id) else {
            resetDrag()
            return
        }
        let slotsMoved = Int(round(dragTranslation / slot))
        let newIdx = max(0, min(orderedIds.count - 1, currentIdx + slotsMoved))
        if newIdx != currentIdx {
            withAnimation(.spring(response: 0.35)) {
                let item = orderedIds.remove(at: currentIdx)
                orderedIds.insert(item, at: newIdx)
            }
        }
        resetDrag()
    }

    private func resetDrag() {
        withAnimation(.spring(response: 0.3)) {
            draggingId = nil
            dragTranslation = 0
        }
    }
}
