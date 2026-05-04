//
//  ColorListField.swift
//  Lumoria App
//
//  Horizontal scroll of color swatches used inside the new-ticket
//  style step's "Accent" / "Background color" / etc. collapsibles.
//  Surfaces a curated preset palette plus a trailing tile that opens
//  iOS's native `ColorPicker` for an arbitrary hex.
//
//  Selection is a `Binding<String?>` of a 6-char uppercase hex. Nil
//  means "no override" (use the variant default). The picker's
//  `Color` binding is internal — we round-trip through hex so the
//  ticket payload stays plain JSON.
//

import SwiftUI

struct ColorListField: View {

    /// Hex strings (no leading `#`) shown as preset swatches. The
    /// caller picks a sensible curated set per element (e.g. accents
    /// for "Accent", neutrals for "Text color").
    let presets: [String]
    /// Selected hex string (nil = no override). Updating this binding
    /// fires any `onPick` callbacks the host wires up.
    @Binding var selectedHex: String?
    /// Fired before the binding is updated. Lets the host gate the
    /// pick on entitlement (returning `false` cancels the write).
    var onPickAttempt: (String) -> Bool = { _ in true }

    /// Backing for the native `ColorPicker`. Mirrored from
    /// `selectedHex` on appear and pushed back via `onChange`.
    @State private var customColor: Color = .white

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(presets, id: \.self) { hex in
                    presetTile(hex: hex)
                }

                customPickerTile
            }
            .padding(.vertical, 4)
        }
        .onAppear {
            if let hex = selectedHex {
                customColor = Color(hex: hex)
            }
        }
        .onChange(of: customColor) { _, newColor in
            // Only react when the user actively interacted with the
            // native picker — avoid clobbering preset selections.
            let hex = newColor.hexString
            guard hex != selectedHex else { return }
            attemptPick(hex)
        }
    }

    // MARK: - Tiles

    private func presetTile(hex: String) -> some View {
        Button {
            attemptPick(hex)
        } label: {
            ColorWell(color: Color(hex: hex), size: CGSize(width: 80, height: 80))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(
                            isSelected(hex)
                                ? Color("Colors/Opacity/Black/inverse/40")
                                : Color("Colors/Opacity/Black/inverse/7"),
                            lineWidth: isSelected(hex) ? 2 : 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    /// Trailing tile — wraps SwiftUI's native `ColorPicker`. Tapping
    /// the swatch face opens the system grid/spectrum/sliders sheet.
    /// The tile itself is the picker's label, so the whole 80×80 area
    /// is hit-testable.
    private var customPickerTile: some View {
        ColorPicker(
            "Custom color",
            selection: $customColor,
            supportsOpacity: false
        )
        .labelsHidden()
        .frame(width: 80, height: 80)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    Color("Colors/Opacity/Black/inverse/7"),
                    lineWidth: 1
                )
        )
        .overlay(
            // "+" glyph layered over the native picker so users can
            // tell the trailing tile is the custom-color affordance.
            // Pointer events fall through to the picker beneath.
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.Text.primary)
                .allowsHitTesting(false)
        )
    }

    // MARK: - Helpers

    private func isSelected(_ hex: String) -> Bool {
        selectedHex?.uppercased() == hex.uppercased()
    }

    private func attemptPick(_ hex: String) {
        let normalised = hex.uppercased()
        guard onPickAttempt(normalised) else { return }
        selectedHex = normalised
    }
}

// MARK: - Color → hex helper

extension Color {
    /// Returns a 6-character uppercase hex string for the receiver.
    /// Goes via `UIColor` so `.systemBackground`-style dynamic colors
    /// resolve to a concrete RGB triple. Ignores alpha because the
    /// override store is RGB-only today.
    var hexString: String {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        let R = Int((r * 255).rounded())
        let G = Int((g * 255).rounded())
        let B = Int((b * 255).rounded())
        return String(format: "%02X%02X%02X", R, G, B)
    }
}

// MARK: - Preview

#Preview {
    struct Wrapper: View {
        @State private var hex: String? = "D94544"
        var body: some View {
            ColorListField(
                presets: ["D94544", "3B5B8C", "1B2340", "E7B85F", "C7D1C0", "B5432C"],
                selectedHex: $hex
            )
            .padding(16)
            .background(Color.Background.elevated)
        }
    }
    return Wrapper()
}
