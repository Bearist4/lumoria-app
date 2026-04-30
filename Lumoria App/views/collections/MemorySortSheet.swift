//
//  MemorySortSheet.swift
//  Lumoria App
//
//  Bottom sheet for choosing how `MemoryDetailView` orders its tickets.
//  Three fields × oldest/newest direction. Persists per memory via
//  `MemoriesStore.updateSort`.
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=2028-143016
//

import SwiftUI

struct MemorySortSheet: View {

    let memoryId: UUID
    @Binding var field: MemorySortField
    @Binding var ascending: Bool
    let onChange: (_ field: MemorySortField, _ ascending: Bool) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Sort tickets")
                    .font(.title3.bold())
                    .foregroundStyle(Color.Text.primary)
                Spacer()
                Button {
                    dismiss()
                } label: {
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
        .background(Color.Background.default)
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.visible)
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
    @Previewable @State var field: MemorySortField = .dateAdded
    @Previewable @State var ascending = true
    return MemorySortSheet(
        memoryId: UUID(),
        field: $field,
        ascending: $ascending
    ) { _, _ in }
}
