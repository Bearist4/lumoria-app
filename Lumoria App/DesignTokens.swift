//
//  DesignTokens.swift
//  Lumoria App
//
//  Generated from the Figma "App" design system.
//  Palette colors live in Assets.xcassets/Colors/... as color sets with
//  Light / Dark / HC Light / HC Dark appearances and can be referenced
//  directly, e.g. `Color("Colors/Blue/500")`.
//
//  The tokens below mirror the "Components" variable collection in the
//  App file — semantic aliases that encode intent. Prefer these in UI
//  code over raw palette references.
//

import SwiftUI

// MARK: - Spacing

/// Spacing scale (in points). `base` = 4. Indexed steps are multiples of 4.
enum Spacing {
    static let base: CGFloat = 4

    static let s0:  CGFloat = 0
    static let s1:  CGFloat = 4
    static let s2:  CGFloat = 8
    static let s3:  CGFloat = 12
    static let s4:  CGFloat = 16
    static let s5:  CGFloat = 20
    static let s6:  CGFloat = 24
    static let s7:  CGFloat = 28
    static let s8:  CGFloat = 32
    static let s9:  CGFloat = 36
    static let s10: CGFloat = 40
    static let s11: CGFloat = 44
    static let s12: CGFloat = 48
    static let s13: CGFloat = 52
    static let s14: CGFloat = 56
    static let s15: CGFloat = 60
    static let s16: CGFloat = 64
    static let s17: CGFloat = 68
    static let s18: CGFloat = 72
    static let s19: CGFloat = 76
    static let s20: CGFloat = 80
    static let s24: CGFloat = 96
    static let s28: CGFloat = 112
    static let s32: CGFloat = 128
    static let s36: CGFloat = 144
    static let s40: CGFloat = 160
    static let s44: CGFloat = 176
    static let s48: CGFloat = 192
    static let s56: CGFloat = 224
    static let s64: CGFloat = 256
    static let s80: CGFloat = 320
    static let s96: CGFloat = 384
}

// MARK: - Semantic component tokens

private func c(_ path: String) -> Color { Color("Colors/\(path)") }

extension Color {

    // MARK: Button

    enum Button {
        enum Primary {
            enum Background {
                static let `default` = c("Gray/1100")
                static let hover     = c("Gray/900")
                static let pressed   = c("Gray/700")
                static let inactive  = c("Gray/300")
            }
            enum Label {
                static let `default` = c("Gray/0")
            }
        }
        enum Secondary {
            enum Background {
                static let `default` = c("Opacity/Black/inverse/5")
                static let hover     = c("Opacity/Black/inverse/10")
                static let pressed   = c("Opacity/Black/inverse/15")
            }
            enum Label {
                static let `default` = c("Gray/1100")
                static let inactive  = c("Gray/300")
            }
            enum Border {
                static let `default` = c("Gray/1100")
                static let inactive  = c("Gray/300")
            }
        }
        enum Tertiary {
            enum Label {
                static let `default` = c("Gray/1100")
                static let inactive  = c("Gray/300")
            }
        }
        enum Danger {
            enum Background {
                static let `default` = c("Red/600")
                static let hover     = c("Red/700")
                static let pressed   = c("Red/800")
                static let inactive  = c("Red/900")
            }
            enum Label {
                static let `default` = c("Gray/0")
            }
        }
    }

    // MARK: Text

    enum Text {
        static let primary   = c("Gray/1100")
        static let secondary = c("Gray/500")
        static let tertiary  = c("Gray/400")
        static let disabled  = c("Gray/300")

        enum OnColor {
            static let black = c("Gray/Black")
            static let white = c("Gray/White")
        }
    }

    // MARK: Background

    enum Background {
        static let `default` = c("Gray/0")
        static let elevated  = c("Gray/50")
        static let subtle    = c("Gray/100")
    }

    // MARK: Border

    enum Border {
        static let `default` = c("Gray/200")
        static let strong    = c("Gray/300")

        enum OnBG {
            static let `default` = c("Gray/0")
            static let elevated  = c("Gray/50")
            static let subtle    = c("Gray/100")
        }
    }

    // MARK: Feedback

    enum Feedback {
        enum Danger {
            static let text   = c("Red/700")
            static let icon   = c("Red/500")
            static let subtle = c("Red/50")
        }
        enum Warning {
            static let text   = c("Orange/700")
            static let icon   = c("Orange/500")
            static let subtle = c("Orange/50")
        }
        enum Information {
            static let text   = c("Blue/700")
            static let icon   = c("Blue/500")
            static let subtle = c("Blue/50")
        }
        enum Success {
            static let text   = c("Green/700")
            static let icon   = c("Green/500")
            static let subtle = c("Green/50")
        }
        enum Neutral {
            static let text   = c("Gray/600")
            static let icon   = c("Gray/400")
            static let subtle = c("Gray/100")
        }
    }
}
