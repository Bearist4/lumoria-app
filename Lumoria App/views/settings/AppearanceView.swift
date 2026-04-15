//
//  AppearanceView.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=970-22833
//

import SwiftUI
import UIKit

struct AppearanceView: View {

    @Environment(\.dismiss) private var dismiss

    @AppStorage("appearance.mode") private var storedMode: String = AppearanceMode.system.rawValue
    @AppStorage("appearance.highContrast") private var highContrast: Bool = false
    @AppStorage("appearance.iconName") private var storedIconName: String = ""

    // Add more options here as new app icons are added to Assets.xcassets.
    // `alternateIconName` must match the additional .appiconset name.
    // `previewAsset` is the in-app preview image (separate PNG asset).
    private let iconOptions: [AppIconOption] = [
        AppIconOption(alternateIconName: nil,          name: "Default",     previewAsset: "brand/default/logomark"),
        AppIconOption(alternateIconName: "AppIcon Transpride", name: "Transpride",  previewAsset: "brand/transpride/logomark"),
    ]

    private var selectedMode: AppearanceMode {
        AppearanceMode(rawValue: storedMode) ?? .system
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.Background.default.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Appearance")
                        .font(.system(size: 34, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(Color.Text.primary)
                        .padding(.top, 64)

                    themeSection
                    accessibilitySection
                    appIconSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 120)
            }

            topBar
                .padding(.horizontal, 16)
                .padding(.top, 6)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            storedIconName = UIApplication.shared.alternateIconName ?? ""
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            LumoriaIconButton(
                systemImage: "chevron.left",
                position: .onBackground
            ) { dismiss() }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Theme

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Theme")

            HStack(spacing: 8) {
                ForEach(AppearanceMode.allCases) { mode in
                    ModeSelect(
                        mode: mode,
                        isSelected: mode == selectedMode
                    ) {
                        storedMode = mode.rawValue
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Accessibility

    private var accessibilitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Accessibility")

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("High contrast")
                        .font(.system(size: 17, weight: .regular))
                        .tracking(-0.43)
                        .foregroundStyle(Color.Text.primary)

                    Text("Increases border and text contrast throughout the app.")
                        .font(.system(size: 15, weight: .regular))
                        .tracking(-0.23)
                        .foregroundStyle(Color.Text.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Toggle("", isOn: $highContrast)
                    .labelsHidden()
                    .tint(Color("Colors/Green/500"))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.Background.elevated)
            )
        }
    }

    // MARK: - App icon

    private var appIconSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("App Icon")

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                ],
                spacing: 8
            ) {
                ForEach(iconOptions) { option in
                    IconSelect(
                        option: option,
                        isSelected: (option.alternateIconName ?? "") == storedIconName
                    ) {
                        setAppIcon(option.alternateIconName)
                    }
                }
            }
        }
    }

    private func setAppIcon(_ name: String?) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        let previous = storedIconName
        storedIconName = name ?? ""
        let current = UIApplication.shared.alternateIconName
        guard current != name else { return }
        Task { @MainActor in
            do {
                try await UIApplication.shared.setAlternateIconName(name)
            } catch {
                print("[AppearanceView] setAlternateIconName failed: \(error)")
                storedIconName = previous
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 20, weight: .semibold))
            .tracking(-0.45)
            .foregroundStyle(Color.Text.primary)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AppearanceView()
    }
}
