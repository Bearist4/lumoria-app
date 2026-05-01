//
//  AllTicketsSortSheet.swift
//  Lumoria App
//
//  Floating bottom-sheet content for the All tickets view's sort
//  picker. Shares structure with `MemorySortSheet` — title row +
//  close, "Date" group of three radio rows + Oldest/Newest segmented
//  pill, "Categories" group of two radio rows (A-Z / Z-A), and a
//  Reset/Done footer.
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1728-79133
//

import SwiftUI

struct AllTicketsSortSheet: View {

    let initialField: AllTicketsSortField?
    let initialAscending: Bool
    let onCommit: (_ field: AllTicketsSortField?, _ ascending: Bool) -> Void
    let onDismiss: () -> Void

    @State private var field: AllTicketsSortField?
    @State private var ascending: Bool

    init(
        initialField: AllTicketsSortField?,
        initialAscending: Bool,
        onCommit: @escaping (AllTicketsSortField?, Bool) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.initialField = initialField
        self.initialAscending = initialAscending
        self.onCommit = onCommit
        self.onDismiss = onDismiss
        _field = State(initialValue: initialField)
        _ascending = State(initialValue: initialAscending)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top) {
                Text("Sort by")
                    .font(.title3.bold())
                    .foregroundStyle(Color.Text.primary)
                Spacer(minLength: 0)
                LumoriaIconButton(systemImage: "xmark", size: .medium) {
                    onDismiss()
                }
            }

            dateGroup

            // `.transition(.identity)` insertion = no animation when
            // the pill appears/disappears, so the date rows don't
            // visibly animate while the radio's selected state pops
            // at its final position.
            if (field?.supportsDirection ?? true) {
                directionPill
                    .transition(.identity)
            }

            categoriesGroup

            HStack(spacing: 12) {
                Button("Reset") {
                    field = nil
                    ascending = true
                }
                .buttonStyle(LumoriaButtonStyle(hierarchy: .secondary, size: .large))

                Button("Done") {
                    onCommit(field, ascending)
                    onDismiss()
                }
                .buttonStyle(LumoriaButtonStyle(hierarchy: .primary, size: .large))
            }
        }
        .padding(24)
    }

    // MARK: - Date group

    private var dateGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Date")
                .font(.headline)
                .foregroundStyle(Color.Text.tertiary)

            VStack(spacing: 0) {
                ForEach(Array(AllTicketsSortField.dateOptions.enumerated()), id: \.element.id) { index, option in
                    sortRow(option)
                    if index < AllTicketsSortField.dateOptions.count - 1 {
                        Divider().opacity(0.4)
                    }
                }
            }
        }
    }

    // MARK: - Categories group

    private var categoriesGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Categories")
                .font(.headline)
                .foregroundStyle(Color.Text.tertiary)

            VStack(spacing: 0) {
                ForEach(Array(AllTicketsSortField.categoryOptions.enumerated()), id: \.element.id) { index, option in
                    sortRow(option)
                    if index < AllTicketsSortField.categoryOptions.count - 1 {
                        Divider().opacity(0.4)
                    }
                }
            }
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func sortRow(_ option: AllTicketsSortField) -> some View {
        Button {
            // Disable any inherited animation when changing field —
            // ensures the directionPill insertion + layout reflow
            // happen instantly instead of mid-flight, which would
            // otherwise desync the radio dot from its row.
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) { field = option }
        } label: {
            // Align HStack on the title's first text baseline so the
            // radio sits next to the title row regardless of whether
            // a subtitle is present. With `.center`, rows that have a
            // subtitle (Event) push their radio downward and look
            // misaligned with the radios in single-line rows.
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(.body)
                        .foregroundStyle(Color.Text.primary)
                    if let subtitle = option.subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(Color.Text.tertiary)
                    }
                }
                Spacer(minLength: 0)
                // The radio's hit area extends above the title's
                // baseline; `.alignmentGuide` shifts it back down so
                // the visual ring sits beside the title text.
                LumoriaRadio(isSelected: field == option)
                    .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Direction pill

    private var directionPill: some View {
        HStack(spacing: 0) {
            directionSegment(label: String(localized: "Oldest first"), value: true)
            directionSegment(label: String(localized: "Newest first"), value: false)
        }
        .padding(4)
        .background(
            Capsule().fill(Color.Background.subtle)
        )
    }

    private func directionSegment(label: String, value: Bool) -> some View {
        Button {
            ascending = value
        } label: {
            Text(label)
                .font(.subheadline.weight(ascending == value ? .semibold : .regular))
                .foregroundStyle(Color.Text.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(
                    Capsule()
                        .fill(ascending == value ? Color.Background.default : Color.clear)
                        .shadow(
                            color: ascending == value ? Color.black.opacity(0.06) : .clear,
                            radius: 4,
                            x: 0,
                            y: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AllTicketsSortSheet(
        initialField: .dateCreated,
        initialAscending: false,
        onCommit: { _, _ in },
        onDismiss: { }
    )
}
