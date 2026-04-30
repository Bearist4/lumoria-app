//
//  MemoryColorPickerSheet.swift
//  Lumoria App
//
//  Floating bottom-sheet for picking a memory's color family. 11
//  swatches in a fixed 4-column grid using the existing palette
//  tokens. Done commits the current selection.
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=2028-143737
//

import SwiftUI

struct MemoryColorPickerSheet: View {

    let initialColor: ColorOption
    let onCommit: (ColorOption) -> Void
    let onDismiss: () -> Void

    @State private var selection: ColorOption

    /// Fixed 4-column grid. Eager `LazyVGrid` columns let the swatches
    /// inherit the parent sheet's slide-in transition cleanly — adaptive
    /// columns occasionally re-flow on first appear and look detached
    /// from the sheet animation.
    private static let columns: [GridItem] = Array(
        repeating: GridItem(.flexible(), spacing: 8),
        count: 4
    )

    init(
        initialColor: ColorOption,
        onCommit: @escaping (ColorOption) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.initialColor = initialColor
        self.onCommit = onCommit
        self.onDismiss = onDismiss
        _selection = State(initialValue: initialColor)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Color")
                .font(.title2.bold())
                .foregroundStyle(Color.Text.primary)

            LazyVGrid(columns: Self.columns, spacing: 8) {
                ForEach(ColorOption.all) { option in
                    swatch(option)
                }
            }

            Button("Done") {
                onCommit(selection)
                onDismiss()
            }
            .buttonStyle(LumoriaButtonStyle(hierarchy: .primary, size: .large))
        }
        .padding(24)
    }

    private func swatch(_ option: ColorOption) -> some View {
        let isSelected = selection.family == option.family
        return Button {
            selection = option
        } label: {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(option.swatchColor)
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            isSelected ? Color.Text.primary : Color.Border.default,
                            lineWidth: isSelected ? 3 : 1
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.name)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    MemoryColorPickerSheet(
        initialColor: ColorOption.all.first(where: { $0.family == "Orange" })
            ?? ColorOption.all[0],
        onCommit: { _ in },
        onDismiss: { }
    )
}
