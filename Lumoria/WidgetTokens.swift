//
//  WidgetTokens.swift
//  Lumoria (widget)
//
//  Semantic surface tokens mirrored from the main app's
//  `Lumoria App/DesignTokens.swift`. The widget target doesn't ship
//  the main app's `Assets.xcassets/Colors/Gray/...` color sets, so
//  these are inlined as adaptive UIColors.
//
//  Naming follows the app side (`Color.Background.default`,
//  `Color.Background.elevated`) so widget views read identically to
//  app views.
//

import SwiftUI
import UIKit

extension Color {
    enum Background {
        /// Gray/0 — primary surface. Light: #FFFFFF · Dark: #0A0A0A.
        static let `default`: Color = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.039, green: 0.039, blue: 0.039, alpha: 1)
                : UIColor.white
        })

        /// Gray/50 — slightly elevated surface (cards, side panels).
        /// Light: #FAFAFA · Dark: #171717.
        static let elevated: Color = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.090, green: 0.090, blue: 0.090, alpha: 1)
                : UIColor(red: 0.980, green: 0.980, blue: 0.980, alpha: 1)
        })
    }

    enum Text {
        /// Gray/1100 — primary text. Light: #000000 · Dark: #FFFFFF.
        static let primary: Color = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? .white : .black
        })

        /// Gray/500 — secondary text. Light: #737373 · Dark: #A3A3A3.
        static let secondary: Color = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.639, green: 0.639, blue: 0.639, alpha: 1)
                : UIColor(red: 0.451, green: 0.451, blue: 0.451, alpha: 1)
        })

        /// Gray/400 — tertiary text. Light: #A3A3A3 · Dark: #737373.
        static let tertiary: Color = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.451, green: 0.451, blue: 0.451, alpha: 1)
                : UIColor(red: 0.639, green: 0.639, blue: 0.639, alpha: 1)
        })
    }
}
