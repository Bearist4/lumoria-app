//
//  MemorySortSheet.swift
//  Lumoria App
//
//  Floating bottom-sheet content for choosing how `MemoryDetailView`
//  orders its tickets. Three fields × oldest/newest direction. Persists
//  per memory via `MemoriesStore.updateSort` (host wires the callback).
//
//  Presented through the app's shared `.floatingBottomSheet` modifier,
//  so this view renders only the inner content — no `presentationDetents`,
//  no native sheet chrome.
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=2028-143016
//

import SwiftUI

struct MemorySortSheet: View {

    let initialField: MemorySortField
    let initialAscending: Bool
    let onChange: (_ field: MemorySortField, _ ascending: Bool) -> Void
    let onDismiss: () -> Void

    @State private var field: MemorySortField
    @State private var ascending: Bool

    init(
        initialField: MemorySortField,
        initialAscending: Bool,
        onChange: @escaping (MemorySortField, Bool) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.initialField = initialField
        self.initialAscending = initialAscending
        self.onChange = onChange
        self.onDismiss = onDismiss
        _field = State(initialValue: initialField)
        _ascending = State(initialValue: initialAscending)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Sort tickets")
                    .font(.title3.bold())
                    .foregroundStyle(Color.Text.primary)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.Text.secondary)
                }
                .accessibilityLabel("Close")
            }

            VStack(spacing: 0) {
                ForEach(MemorySortField.allCases) { option in
                    sortRow(option)
                    if option != MemorySortField.allCases.last {
                        Divider().opacity(0.4)
                    }
                }
            }

            Picker("Direction", selection: Binding(
                get: { ascending },
                set: { newValue in
                    ascending = newValue
                    onChange(field, newValue)
                }
            )) {
                Text("Oldest first").tag(true)
                Text("Newest first").tag(false)
            }
            .pickerStyle(.segmented)
        }
        .padding(24)
    }

    @ViewBuilder
    private func sortRow(_ option: MemorySortField) -> some View {
        Button {
            field = option
            onChange(option, ascending)
        } label: {
            HStack {
                Text(option.title)
                    .font(.body)
                    .foregroundStyle(Color.Text.primary)
                Spacer()
                if field == option {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MemorySortSheet(
        initialField: .dateAdded,
        initialAscending: true,
        onChange: { _, _ in },
        onDismiss: { }
    )
}
