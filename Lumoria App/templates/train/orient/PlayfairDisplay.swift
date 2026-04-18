//
//  PlayfairDisplay.swift
//  Lumoria App
//
//  Convenience accessor for the bundled Playfair Display family. Uses
//  explicit PostScript names per face — `Font.custom(family).fontWeight()`
//  is unreliable on custom fonts; SwiftUI ignores the requested weight
//  unless we hand it the right physical font directly.
//

import SwiftUI

extension Font {
    /// Picks the right Playfair Display face by combining requested
    /// `weight` and `italic` flags. Falls back to Regular for unknown
    /// combinations. Tries the PostScript name first, then the
    /// human-readable full name as a fallback — Core Text accepts
    /// either, but custom font lookup is finicky and one often works
    /// when the other doesn't.
    static func playfair(
        size: CGFloat,
        weight: Font.Weight = .regular,
        italic: Bool = false
    ) -> Font {
        let (postscript, fullName): (String, String)
        switch (weight, italic) {
        case (.bold, true):
            (postscript, fullName) = ("PlayfairDisplay-BoldItalic", "Playfair Display Bold Italic")
        case (.bold, false):
            (postscript, fullName) = ("PlayfairDisplay-Bold", "Playfair Display Bold")
        case (_, true):
            (postscript, fullName) = ("PlayfairDisplay-Italic", "Playfair Display Italic")
        default:
            (postscript, fullName) = ("PlayfairDisplay-Regular", "Playfair Display Regular")
        }

        // Prefer the PostScript name when Core Text knows it; otherwise
        // fall back to the full name. Either resolves the same physical
        // file when both are registered.
        let preferred = UIFont(name: postscript, size: size) != nil
            ? postscript
            : fullName
        return .custom(preferred, size: size)
    }
}

// MARK: - Debug

extension Font {
    /// Prints every registered Playfair face to the console. Call once
    /// from `App.init` to confirm the .ttf files actually loaded.
    static func dumpPlayfairFaces() {
        let families = UIFont.familyNames.filter { $0.lowercased().contains("playfair") }
        for family in families {
            print("👀 family:", family)
            for face in UIFont.fontNames(forFamilyName: family) {
                print("   • face:", face)
            }
        }
        if families.isEmpty {
            print("⚠️ No Playfair Display family registered. UIAppFonts entry or bundle membership is wrong.")
        }
    }
}
