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

struct LumoriaDropdown<Item: Identifiable, Row: View>: View {

    // Label / copy
    let label: String
    let placeholder: String
    var isRequired: Bool = true
    var assistiveText: String? = nil

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
            } else if let assistiveText, !assistiveText.isEmpty {
                assistive(assistiveText)
            }
        }
    }

    // MARK: Label

    private var labelRow: some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .tracking(-0.23)
                .foregroundStyle(Color.Text.primary)
            if isRequired {
                Text("*")
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(-0.23)
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
                Text(selection.map(selectedLabel) ?? placeholder)
                    .foregroundStyle(selection == nil
                                     ? Color.Text.tertiary
                                     : Color.Text.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.Text.secondary)
            }
            .font(.system(size: 17, weight: .regular))
            .tracking(-0.43)
            .padding(.horizontal, 8)
            .frame(height: 50)
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.03))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.black.opacity(0.07), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: List

    private var list: some View {
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
        .frame(height: 56)
        .background(
            isSelected
                ? Color.Background.subtle.clipShape(RoundedRectangle(cornerRadius: 8))
                : nil
        )
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(Color.black.opacity(0.03))
                    .frame(height: 1)
            }
        }
    }

    // MARK: Assistive text

    private func assistive(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .regular))
            .tracking(0.06)
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
                    assistiveText: "The color will be displayed in the background of the Collection’s preview.",
                    options: ColorOption.all,
                    selection: $selection,
                    selectedLabel: { $0.name }
                ) { opt in
                    HStack(spacing: 8) {
                        ColorWell(color: opt.swatchColor)
                        Text(opt.name)
                            .font(.system(size: 17, weight: .regular))
                            .tracking(-0.43)
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
