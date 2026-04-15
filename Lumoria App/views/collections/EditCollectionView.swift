//
//  EditCollectionView.swift
//  Lumoria App
//
//  Modal sheet for editing an existing collection.
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1017-24963
//

import SwiftUI
import MapKit

struct EditCollectionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var collectionsStore: CollectionsStore

    let collection: Collection

    @Binding var previewColorFamily: String?

    @State private var title: String
    @State private var selectedColor: ColorOption?
    @State private var locationEnabled: Bool
    @State private var selectedLocation: SelectedLocation?

    @State private var showRemoveLocationConfirm = false

    private let originalTitle: String
    private let originalColor: ColorOption?
    private let originalLocationEnabled: Bool
    private let originalLocation: SelectedLocation?

    init(
        collection: Collection,
        previewColorFamily: Binding<String?> = .constant(nil)
    ) {
        self.collection = collection
        self._previewColorFamily = previewColorFamily

        let title = collection.name
        let color = collection.colorOption
        let location: SelectedLocation? = {
            guard
                let name = collection.locationName,
                let lat = collection.locationLat,
                let lng = collection.locationLng
            else { return nil }
            return SelectedLocation(
                title: name,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng)
            )
        }()

        _title = State(initialValue: title)
        _selectedColor = State(initialValue: color)
        _locationEnabled = State(initialValue: location != nil)
        _selectedLocation = State(initialValue: location)

        self.originalTitle = title
        self.originalColor = color
        self.originalLocationEnabled = location != nil
        self.originalLocation = location
    }

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
        .alert(
            "Remove location?",
            isPresented: $showRemoveLocationConfirm
        ) {
            Button("Remove location", role: .destructive) { performSave() }
            Button("Keep location", role: .cancel) { }
        } message: {
            Text("The location attached to this collection will be removed and lost. Do you want to continue?")
        }
    }

    // MARK: - Intro

    private var intro: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            Text("Edit Collection Name")
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
            isRequired: true,
            state: titleDirty ? .warning : .default,
            assistiveText: titleDirty
                ? "You edited this field but your changes have not been saved yet."
                : nil
        )
    }

    // MARK: - Color dropdown

    private var colorField: some View {
        LumoriaDropdown(
            label: "Color",
            placeholder: "Choose a color",
            isRequired: true,
            assistiveText: colorDirty
                ? "You edited this field but your changes have not been saved yet."
                : "The color will be displayed in the background of the Collection’s preview.",
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

    private var saveButton: some View {
        Button {
            if isRemovingLocation {
                showRemoveLocationConfirm = true
            } else {
                performSave()
            }
        } label: {
            Text("Save changes")
        }
        .lumoriaButtonStyle(.primary, size: .large)
        .disabled(!canSave)
    }

    private func performSave() {
        guard let color = selectedColor else { return }
        Task {
            await collectionsStore.update(
                collection,
                name: title.trimmingCharacters(in: .whitespaces),
                colorFamily: color.family,
                location: locationEnabled ? selectedLocation : nil
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

    private var locationDirty: Bool {
        if locationEnabled != originalLocationEnabled { return true }
        return selectedLocation != originalLocation
    }

    private var hasChanges: Bool {
        titleDirty || colorDirty || locationDirty
    }

    /// True when the user had a location attached and is saving with the
    /// toggle off — we warn before dropping the coordinates permanently.
    private var isRemovingLocation: Bool {
        originalLocation != nil && !locationEnabled
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
                    EditCollectionView(
                        collection: Collection(
                            id: UUID(),
                            userId: UUID(),
                            name: "Holidays 2026",
                            colorFamily: "Blue",
                            locationName: nil,
                            locationLat: nil,
                            locationLng: nil,
                            createdAt: .now,
                            updatedAt: .now
                        )
                    )
                    .environmentObject(CollectionsStore())
                }
        }
    }
    return Host()
}
