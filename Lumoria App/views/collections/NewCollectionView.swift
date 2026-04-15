//
//  NewCollectionView.swift
//  Lumoria App
//
//  Modal sheet for creating a new collection.
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=982-27918
//

import SwiftUI
import MapKit

struct NewCollectionView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var selectedColor: ColorOption? = nil
    @State private var locationEnabled: Bool = false
    @State private var selectedLocation: SelectedLocation? = nil

    /// Invoked when the user taps Create.
    var onCreate: ((String, ColorOption?, SelectedLocation?) -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s8) {
                intro
                titleField
                colorField
                locationCard
                if locationEnabled {
                    LumoriaLocationField(selected: $selectedLocation)
                }
            }
            .padding(.horizontal, Spacing.s6)
            .padding(.top, 72)
            .padding(.bottom, Spacing.s6)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.Background.default)
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
            Text("Create a new collection")
                .font(.system(size: 34, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(Color.Text.primary)

            Text("Collections are where your tickets come together. Group them by trip, theme, or memory to keep everything organized.")
                .font(.system(size: 17, weight: .regular))
                .tracking(-0.43)
                .foregroundStyle(Color.Text.secondary)
        }
    }

    // MARK: - Title field

    private var titleField: some View {
        LumoriaInputField(
            label: "Collection title",
            placeholder: "Name your collection",
            text: $title,
            isRequired: true
        )
    }

    // MARK: - Color dropdown

    private var colorField: some View {
        LumoriaDropdown(
            label: "Color",
            placeholder: "Choose a color",
            isRequired: true,
            assistiveText: "The color will be displayed in the background of the Collection’s preview.",
            options: ColorOption.all,
            selection: $selectedColor,
            selectedLabel: { $0.name }
        ) { option in
            HStack(spacing: 8) {
                ColorWell(color: option.swatchColor)
                Text(option.name)
                    .font(.system(size: 17, weight: .regular))
                    .tracking(-0.43)
                    .foregroundStyle(Color.Text.primary)
            }
        }
    }

    // MARK: - Location toggle card

    private var locationCard: some View {
        HStack(alignment: .top, spacing: Spacing.s4) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Location")
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(-0.43)
                    .foregroundStyle(Color.Text.primary)

                Text("You can associate this collection to a location of your choice.")
                    .font(.system(size: 13, weight: .regular))
                    .tracking(-0.08)
                    .foregroundStyle(Color.Text.primary)
            }

            Spacer(minLength: 0)

            Toggle("", isOn: $locationEnabled.animation(.easeInOut(duration: 0.2)))
                .labelsHidden()
                .tint(Color("Colors/Green/500"))
        }
        .padding(Spacing.s4)
        .background(Color.Background.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Primary CTA

    private var createButton: some View {
        Button {
            onCreate?(
                title.trimmingCharacters(in: .whitespaces),
                selectedColor,
                locationEnabled ? selectedLocation : nil
            )
            dismiss()
        } label: {
            Text("Create collection")
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
    /// Saturated color used for the collection preview background.
    var primaryColor: Color { Color("Colors/\(family)/500") }
    /// Legacy alias — some callers ask for `color`.
    var color: Color { primaryColor }
    /// Asset path to the 500-weight, e.g. "Blue/500".
    var assetPath: String { "\(family)/500" }

    static let all: [ColorOption] = [
        .init(name: "Blue",   family: "Blue"),
        .init(name: "Indigo", family: "Indigo"),
        .init(name: "Cyan",   family: "Cyan"),
        .init(name: "Teal",   family: "Teal"),
        .init(name: "Green",  family: "Green"),
        .init(name: "Lime",   family: "Lime"),
        .init(name: "Yellow", family: "Yellow"),
        .init(name: "Orange", family: "Orange"),
        .init(name: "Red",    family: "Red"),
        .init(name: "Pink",   family: "Pink"),
        .init(name: "Purple", family: "Purple"),
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
                    NewCollectionView()
                }
        }
    }
    return Host()
}
