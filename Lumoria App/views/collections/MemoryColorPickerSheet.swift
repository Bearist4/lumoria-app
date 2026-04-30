//
//  MemoryColorPickerSheet.swift
//  Lumoria App
//
//  Floating bottom-sheet for picking a memory's color family. 11
//  swatches in an adaptive grid using the existing palette tokens.
//  Reset reverts the local selection to the value the sheet opened
//  with; Done commits.
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=2028-143737
//

import SwiftUI

struct MemoryColorPickerSheet: View {

    let initialColor: ColorOption
    let onCommit: (ColorOption) -> Void
    let onDismiss: () -> Void

    @State private var selection: ColorOption

    private static let columns = [
        GridItem(.adaptive(minimum: 80, maximum: 80), spacing: 8)
    ]

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

            HStack(spacing: 12) {
                Button("Reset") { selection = initialColor }
                    .buttonStyle(LumoriaButtonStyle(hierarchy: .secondary, size: .large))

                Button("Done") {
                    onCommit(selection)
                    onDismiss()
                }
                .buttonStyle(LumoriaButtonStyle(hierarchy: .primary, size: .large))
            }
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
                .frame(width: 80, height: 80)
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
