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
            HStack(alignment: .top) {
                Text("Color")
                    .font(.title2.bold())
                    .foregroundStyle(Color.Text.primary)
                Spacer(minLength: 0)
                LumoriaIconButton(systemImage: "xmark", size: .medium) {
                    onDismiss()
                }
            }

            // Eager `Grid` (not LazyVGrid) so every swatch is laid out
            // before the sheet starts its slide-in transition.
            // LazyVGrid resolves children just-in-time, which made the
            // colors pop into place after the sheet card had already
            // moved up.
            colorGrid

            Button("Done") {
                onCommit(selection)
                onDismiss()
            }
            .buttonStyle(LumoriaButtonStyle(hierarchy: .primary, size: .large))
        }
        .padding(24)
    }

    /// 4-column eager grid. 11 colors split into 4 + 4 + 3 rows; the
    /// trailing slot in the last row stays empty so the row preserves
    /// the same column geometry.
    @ViewBuilder
    private var colorGrid: some View {
        let rows = ColorOption.all.chunked(into: 4)
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(row) { option in
                        swatch(option)
                    }
                    // Pad short rows with empty cells so all GridRows
                    // share the same 4-column geometry.
                    if row.count < 4 {
                        ForEach(0..<(4 - row.count), id: \.self) { _ in
                            Color.clear
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }
        }
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

// MARK: - Helpers

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
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
