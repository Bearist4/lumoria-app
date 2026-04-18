//
//  EditMemoryView.swift
//  Lumoria App
//
//  Modal sheet for editing an existing memory.
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1017-24963
//

import SwiftUI

struct EditMemoryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var memoriesStore: MemoriesStore

    let memory: Memory

    @Binding var previewColorFamily: String?

    @State private var title: String
    @State private var selectedColor: ColorOption?
    @State private var emoji: String?

    private let originalTitle: String
    private let originalColor: ColorOption?
    private let originalEmoji: String?

    init(
        memory: Memory,
        previewColorFamily: Binding<String?> = .constant(nil)
    ) {
        self.memory = memory
        self._previewColorFamily = previewColorFamily

        let title = memory.name
        let color = memory.colorOption
        let emoji = memory.emoji

        _title = State(initialValue: title)
        _selectedColor = State(initialValue: color)
        _emoji = State(initialValue: emoji)

        self.originalTitle = title
        self.originalColor = color
        self.originalEmoji = emoji
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s8) {
                intro
                titleField
                emojiColorRow
            }
            .padding(.horizontal, Spacing.s6)
            .padding(.top, 72)
            .padding(.bottom, Spacing.s6)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.Background.default)
        .safeAreaInset(edge: .bottom) {
            saveButton
                .padding(.horizontal, Spacing.s6)
                .padding(.top, Spacing.s3)
                .padding(.bottom, Spacing.s2)
                .background(Color.Background.default)
        }
        .overlay(alignment: .topLeading) {
            LumoriaIconButton(
                systemImage: "xmark",
                size: .large,
                action: { dismiss() }
            )
            .padding(.horizontal, Spacing.s6)
            .padding(.top, Spacing.s4)
        }
        .onChange(of: selectedColor) { _, newValue in
            previewColorFamily = newValue?.family
        }
    }

    // MARK: - Intro

    private var intro: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            Text("Edit Memory Name")
                .font(.largeTitle.bold())
                .foregroundStyle(Color.Text.primary)

            Text("Memories are where your tickets come together. Group them by trip, event, or place — whatever you want to remember.")
                .font(.body)
                .foregroundStyle(Color.Text.secondary)
        }
    }

    // MARK: - Title field

    private var titleField: some View {
        LumoriaInputField(
            label: "Memory title",
            placeholder: "Name your memory",
            text: $title,
            isRequired: true,
            state: titleDirty ? .warning : .default,
            assistiveText: titleDirty
                ? "You edited this field but your changes have not been saved yet."
                : nil
        )
    }

    // MARK: - Emoji + Color row

    private var emojiColorRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 16) {
                LumoriaInputField(
                    label: "Emoji",
                    emoji: $emoji,
                    isRequired: false,
                    state: emojiDirty ? .warning : .default
                )

                LumoriaDropdown(
                    label: "Color",
                    placeholder: "Choose a color",
                    isRequired: true,
                    state: colorDirty ? .warning : .default,
                    options: ColorOption.all,
                    selection: $selectedColor,
                    selectedLabel: { $0.name }
                ) { option in
                    HStack(spacing: 8) {
                        ColorWell(color: option.swatchColor)
                        Text(option.name)
                            .font(.body)
                            .foregroundStyle(Color.Text.primary)
                    }
                }
            }

            Text(assistiveCopy)
                .font(.caption2)
                .foregroundStyle(assistiveColor)
        }
    }

    private var assistiveCopy: String {
        switch (emojiDirty, colorDirty) {
        case (true, true):
            return String(localized: "You edited these fields but your changes have not been saved yet.")
        case (true, false), (false, true):
            return String(localized: "You edited this field but your changes have not been saved yet.")
        case (false, false):
            return String(localized: "Add an emoji and a color to personalize your memory.")
        }
    }

    private var assistiveColor: Color {
        (emojiDirty || colorDirty) ? Color(hex: "8A4500") : Color(hex: "525252")
    }

    // MARK: - Primary CTA

    private var saveButton: some View {
        Button {
            performSave()
        } label: {
            Text("Save changes")
        }
        .lumoriaButtonStyle(.primary, size: .large)
        .disabled(!canSave)
    }

    private func performSave() {
        guard let color = selectedColor else { return }
        Task {
            await memoriesStore.update(
                memory,
                name: title.trimmingCharacters(in: .whitespaces),
                colorFamily: color.family,
                emoji: emoji
            )
            dismiss()
        }
    }

    // MARK: - Derived

    private var titleDirty: Bool {
        title.trimmingCharacters(in: .whitespaces)
            != originalTitle.trimmingCharacters(in: .whitespaces)
    }

    private var colorDirty: Bool {
        selectedColor?.family != originalColor?.family
    }

    private var emojiDirty: Bool {
        emoji != originalEmoji
    }

    private var hasChanges: Bool {
        titleDirty || colorDirty || emojiDirty
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && selectedColor != nil
            && hasChanges
    }
}

// MARK: - Preview

#Preview {
    struct Host: View {
        @State var show = true
        var body: some View {
            Color.Background.subtle
                .ignoresSafeArea()
                .sheet(isPresented: $show) {
                    EditMemoryView(
                        memory: Memory(
                            id: UUID(),
                            userId: UUID(),
                            name: "Holidays 2026",
                            colorFamily: "Blue",
                            emoji: "🌴",
                            createdAt: .now,
                            updatedAt: .now
                        )
                    )
                    .environmentObject(MemoriesStore())
                }
        }
    }
    return Host()
}
