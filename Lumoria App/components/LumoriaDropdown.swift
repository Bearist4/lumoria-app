//
//  LumoriaDropdown.swift
//  Lumoria App
//
//  Generic labeled dropdown field. Matches the "Dropdown" type in the
//  input-field matrix (see figma node 102-2883).
//
//  The caller supplies:
//    • options         – an array of Identifiable items
//    • selectedLabel   – how to stringify the selected option in the field
//    • rowContent      – custom row content for the expanded list
//

import SwiftUI

/// Max height the open dropdown list grows to before it starts
/// scrolling. ~5 rows at 56pt. Defined at module scope because Swift
/// forbids static stored properties on generic types.
private let lumoriaDropdownListMaxHeight: CGFloat = 280

struct LumoriaDropdown<Item: Identifiable, Row: View>: View {

    // Label / copy
    let label: LocalizedStringKey
    let placeholder: LocalizedStringKey
    var isRequired: Bool = true
    var assistiveText: LocalizedStringKey? = nil
    var state: LumoriaInputFieldState = .default

    // Data
    let options: [Item]
    @Binding var selection: Item?

    // Row builders
    let selectedLabel: (Item) -> String
    @ViewBuilder let rowContent: (Item) -> Row

    @State private var isOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            labelRow
            field
            if isOpen {
                list
            } else if let assistiveText {
                assistive(assistiveText)
            }
        }
    }

    // MARK: Label

    private var labelRow: some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.Text.primary)
            if isRequired {
                Text(verbatim: "*")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color("Colors/Red/400"))
            }
        }
    }

    // MARK: Field

    private var field: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { isOpen.toggle() }
        } label: {
            HStack(spacing: 8) {
                Group {
                    if let item = selection {
                        Text(verbatim: selectedLabel(item))
                    } else {
                        Text(placeholder)
                    }
                }
                .foregroundStyle(selection == nil
                                 ? Color.Text.tertiary
                                 : Color.Text.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                    .font(.footnote)
                    .foregroundStyle(Color.Text.secondary)
            }
            .font(.body)
            .padding(.horizontal, 8)
            .frame(height: 50)
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Derived style

    private var backgroundColor: Color {
        switch state {
        case .default, .disabled: return Color.Background.fieldFill
        case .error:              return Color.Feedback.Danger.subtle
        case .warning:            return Color.Feedback.Warning.subtle
        }
    }

    private var borderColor: Color {
        switch state {
        case .default, .disabled: return Color.Border.hairline
        case .error:              return Color.Feedback.Danger.icon
        case .warning:            return Color.Feedback.Warning.icon
        }
    }

    // MARK: List

    private var list: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                    Button {
                        selection = option
                        withAnimation(.easeInOut(duration: 0.15)) { isOpen = false }
                    } label: {
                        row(for: option, isLast: index == options.count - 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        // Constrain height only once the intrinsic content exceeds it,
        // so short lists still size to content (no trailing whitespace).
        .frame(maxHeight: lumoriaDropdownListMaxHeight)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.Background.elevated)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.Border.default, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.top, 4)
    }

    private func row(for option: Item, isLast: Bool) -> some View {
        let isSelected = selection?.id == option.id
        return HStack(spacing: 0) {
            rowContent(option)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 56)
        // Make the entire row's bounds the hit area — without this,
        // only the `rowContent`'s intrinsic text width is tappable.
        .contentShape(Rectangle())
        .background(
            isSelected
                ? Color.Background.subtle.clipShape(RoundedRectangle(cornerRadius: 8))
                : nil
        )
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(Color.Background.fieldFill)
                    .frame(height: 1)
            }
        }
    }

    // MARK: Assistive text

    private func assistive(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(Color.Feedback.Neutral.text)
            .lineSpacing(2)
            .padding(.top, 2)
    }
}

// MARK: - Preview

#Preview("Color dropdown") {
    struct Demo: View {
        @State var selection: ColorOption? = nil
        var body: some View {
            VStack {
                LumoriaDropdown(
                    label: "Color",
                    placeholder: "Choose a color",
                    assistiveText: "The color will be displayed in the background of the memory’s preview.",
                    options: ColorOption.all,
                    selection: $selection,
                    selectedLabel: { $0.name }
                ) { opt in
                    HStack(spacing: 8) {
                        ColorWell(color: opt.swatchColor)
                        Text(opt.name)
                            .font(.body)
                            .foregroundStyle(Color.Text.primary)
                    }
                }
                Spacer()
            }
            .padding(24)
        }
    }
    return Demo()
}
