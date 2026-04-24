//
//  WidgetPalette.swift
//  Lumoria (widget)
//
//  Hard-coded 300-weight values mirrored from `Assets.xcassets/Colors/…`.
//  The widget target doesn't ship the main app's asset catalog, so we
//  resolve palette colours from a self-contained table rather than
//  `Color("Colors/<family>/300")` lookups that would silently return
//  clear.
//

import SwiftUI
import UIKit

enum WidgetPalette {

    /// Light + dark 300-weight per palette family. Values mirror the
    /// canonical asset catalog under `Colors/<family>/300.colorset`.
    private static let shade300: [String: (light: (Int, Int, Int), dark: (Int, Int, Int))] = [
        "Blue":   ((0x57, 0xB7, 0xF5), (0x91, 0xC7, 0xE9)),
        "Cyan":   ((0x54, 0xD2, 0xEE), (0x8C, 0xD3, 0xE3)),
        "Teal":   ((0x60, 0xD9, 0xBB), (0x8F, 0xD6, 0xC4)),
        "Green":  ((0x86, 0xD7, 0x75), (0xAC, 0xD8, 0xA2)),
        "Lime":   ((0xAB, 0xD0, 0x5F), (0xB8, 0xCE, 0x8B)),
        "Yellow": ((0xFD, 0xDC, 0x51), (0xEE, 0xDC, 0x8F)),
        "Orange": ((0xFF, 0xA9, 0x6C), (0xF1, 0xC0, 0x9D)),
        "Red":    ((0xFF, 0xA3, 0x9D), (0xED, 0x85, 0x7E)),
        "Pink":   ((0xFF, 0x9C, 0xCC), (0xEC, 0x7D, 0xB3)),
        "Purple": ((0xC4, 0x92, 0xFB), (0xAC, 0x77, 0xE7)),
        "Indigo": ((0x8E, 0xA8, 0xFF), (0x72, 0x8E, 0xEB)),
    ]

    /// Adaptive 300-weight color for a family. Falls back to Pink/300 if
    /// the family name is unrecognised so the widget stays readable.
    /// Lookup is case-insensitive so any stray casing (`"lime"`, `"LIME"`)
    /// still resolves instead of silently landing on the Pink fallback.
    static func color300(for family: String) -> Color {
        let key = family.capitalized
        let pair: (light: (Int, Int, Int), dark: (Int, Int, Int))
        if let match = shade300[key] {
            pair = match
        } else {
            NSLog("[WidgetPalette] unknown color family \"%@\" — falling back to Pink", family)
            pair = shade300["Pink"]!
        }
        let light = UIColor(
            red: CGFloat(pair.light.0) / 255,
            green: CGFloat(pair.light.1) / 255,
            blue: CGFloat(pair.light.2) / 255,
            alpha: 1
        )
        let dark = UIColor(
            red: CGFloat(pair.dark.0) / 255,
            green: CGFloat(pair.dark.1) / 255,
            blue: CGFloat(pair.dark.2) / 255,
            alpha: 1
        )
        return Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? dark : light
        })
    }
}
