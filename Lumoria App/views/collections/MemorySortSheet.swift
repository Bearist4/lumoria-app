//
//  MemorySortSheet.swift
//  Lumoria App
//
//  Floating bottom-sheet content for choosing how `MemoryDetailView`
//  orders its tickets. Three fields (under a "Date" group) × oldest /
//  newest direction. Edits buffer locally — Reset reverts to system
//  defaults, Done commits + closes.
//
//  Presented through the app's shared `.floatingBottomSheet` modifier.
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=2028-143016
//

import SwiftUI

struct MemorySortSheet: View {

    let initialField: MemorySortField
    let initialAscending: Bool
    let onCommit: (_ field: MemorySortField, _ ascending: Bool) -> Void
    let onDismiss: () -> Void

    @State private var field: MemorySortField
    @State private var ascending: Bool

    /// Defaults that match the `memories` table column defaults (see
    /// `20260512000001_memory_sort_prefs.sql`). Reset returns the sheet
    /// to these values without persisting until Done.
    private static let defaultField: MemorySortField = .dateAdded
    private static let defaultAscending: Bool = true

    init(
        initialField: MemorySortField,
        initialAscending: Bool,
        onCommit: @escaping (MemorySortField, Bool) -> Void,
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
            Text("Sort by")
                .font(.title3.bold())
                .foregroundStyle(Color.Text.primary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Date")
                    .font(.footnote)
                    .foregroundStyle(Color.Text.tertiary)

                VStack(spacing: 0) {
                    ForEach(Array(MemorySortField.pickerOptions.enumerated()), id: \.element.id) { index, option in
                        sortRow(option)
                        if index < MemorySortField.pickerOptions.count - 1 {
                            Divider().opacity(0.4)
                        }
                    }
                }
            }

            directionPill

            HStack(spacing: 12) {
                Button("Reset") {
                    field = Self.defaultField
                    ascending = Self.defaultAscending
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

    @ViewBuilder
    private func sortRow(_ option: MemorySortField) -> some View {
        Button {
            field = option
        } label: {
            HStack(alignment: .center, spacing: 12) {
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
                LumoriaRadio(isSelected: field == option)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    /// Capsule with two pill segments. The selected segment renders on
    /// a white card with a subtle shadow; the inactive segment is plain
    /// text. Mirrors the segmented control used elsewhere in Lumoria
    /// (compact form filter chips) without the iOS default segmented
    /// look the system Picker would render.
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
    MemorySortSheet(
        initialField: .dateCreated,
        initialAscending: true,
        onCommit: { _, _ in },
        onDismiss: { }
    )
}
