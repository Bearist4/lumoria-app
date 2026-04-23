//
//  NewMemoryView.swift
//  Lumoria App
//
//  Modal sheet for creating a new memory.
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=982-27918
//

import SwiftUI

struct NewMemoryView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var selectedColor: ColorOption? = nil
    @State private var emoji: String? = nil
    @State private var startDate: Date? = nil
    @State private var endDate: Date? = nil

    /// Invoked when the user taps Create.
    var onCreate: ((String, ColorOption?, String?, Date?, Date?) -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s8) {
                intro
                titleField
                emojiColorRow
                dateRow
            }
            .padding(.horizontal, Spacing.s6)
            .padding(.top, 72)
            .padding(.bottom, Spacing.s6)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.Background.default)
        .onAppear { Analytics.track(.memoryCreationStarted) }
        .safeAreaInset(edge: .bottom) {
            createButton
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
    }

    // MARK: - Intro

    private var intro: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            Text("Create a new memory")
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
            isRequired: true
        )
    }

    // MARK: - Emoji + Color row

    private var emojiColorRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 16) {
                LumoriaInputField(
                    label: "Emoji",
                    emoji: $emoji,
                    isRequired: false
                )
                // Tapping either picker right after typing the title
                // should drop the keyboard so the presented sheet /
                // popover isn't hidden behind it. `simultaneousGesture`
                // lets the field still handle its own tap to present.
                .simultaneousGesture(
                    TapGesture().onEnded { Self.dismissKeyboard() }
                )

                LumoriaDropdown(
                    label: "Color",
                    placeholder: "Choose a color",
                    isRequired: true,
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
                .simultaneousGesture(
                    TapGesture().onEnded { Self.dismissKeyboard() }
                )
            }
            // SwiftUI renders VStack children in document order, so a
            // later sibling draws on top of overlays that extend out of
            // earlier ones. Raising the row's z-index keeps the
            // dropdown's open list above this caption — the dropdown
            // visibly covers the caption while open instead of slipping
            // behind it.
            .zIndex(1)

            Text("Add an emoji and a color to personalize your memory.")
                .font(.caption2)
                .foregroundStyle(Color(hex: "525252"))
        }
    }

    // MARK: - Start / end date row

    private var dateRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 16) {
                LumoriaDateField(label: "Start date", date: $startDate)
                LumoriaDateField(label: "End date",   date: $endDate)
            }

            Text("Add a start and end date to track your memory.")
                .font(.caption2)
                .foregroundStyle(Color(hex: "525252"))
        }
    }

    private static func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }

    // MARK: - Primary CTA

    private var createButton: some View {
        Button {
            onCreate?(
                title.trimmingCharacters(in: .whitespaces),
                selectedColor,
                emoji,
                startDate,
                endDate
            )
            dismiss()
        } label: {
            Text("Create memory")
        }
        .lumoriaButtonStyle(.primary, size: .large)
        .disabled(!canCreate)
    }

    private var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && selectedColor != nil
    }
}

// MARK: - Color option model

struct ColorOption: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let family: String

    /// Soft tint used in the dropdown color well.
    var swatchColor: Color { Color("Colors/\(family)/50") }
    /// Saturated color used for the memory preview background.
    var primaryColor: Color { Color("Colors/\(family)/500") }
    /// Legacy alias — some callers ask for `color`.
    var color: Color { primaryColor }
    /// Asset path to the 500-weight, e.g. "Blue/500".
    var assetPath: String { "\(family)/500" }

    static let all: [ColorOption] = [
        .init(name: String(localized: "Blue"),   family: "Blue"),
        .init(name: String(localized: "Indigo"), family: "Indigo"),
        .init(name: String(localized: "Cyan"),   family: "Cyan"),
        .init(name: String(localized: "Teal"),   family: "Teal"),
        .init(name: String(localized: "Green"),  family: "Green"),
        .init(name: String(localized: "Lime"),   family: "Lime"),
        .init(name: String(localized: "Yellow"), family: "Yellow"),
        .init(name: String(localized: "Orange"), family: "Orange"),
        .init(name: String(localized: "Red"),    family: "Red"),
        .init(name: String(localized: "Pink"),   family: "Pink"),
        .init(name: String(localized: "Purple"), family: "Purple"),
    ]
}

// MARK: - Preview

#Preview {
    struct Host: View {
        @State var show = true
        var body: some View {
            Color.Background.subtle
                .ignoresSafeArea()
                .sheet(isPresented: $show) {
                    NewMemoryView()
                }
        }
    }
    return Host()
}
