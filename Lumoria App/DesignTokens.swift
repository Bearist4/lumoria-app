//
//  DesignTokens.swift
//  Lumoria App
//
//  Generated to mirror the Figma "Colors" variable collection.
//
//  Asset layout (Shared.xcassets/Colors):
//    • Palette folders preserve Figma case: `Blue/100`, `Gray/0`,
//      `Opacity/Black/regular/5`, `Opacity/White/inverse/15`, etc.
//    • Alias folders are lowercased to avoid case-collisions on the
//      case-insensitive macOS filesystem (Figma has both `Overlay/...`
//      and `overlay/...` so a single canonical case is required):
//        - background/{surface,memory}/...
//        - category/{background,content}/<style>
//        - text/{primary,secondary,tertiary,inactive}
//        - feedback/<level>/{surface,border,text,content}
//        - overlay/{default,dark,sheet,alert,loading}
//        - components/{button,iconbutton,inputfield,memory,ticketentry}/...
//        - controls/radio/{border,content}
//        - misc/required
//
//  Every alias colorset is generated with all 4 appearance modes baked
//  in (Light, Dark, HC Light, HC Dark) so SwiftUI's asset lookup picks
//  the right value without any runtime branching.
//
//  `Shared.xcassets` is target-membered into BOTH the main app target
//  AND the `Lumoria` widget extension target so this file compiles in
//  either bundle.
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

// MARK: - Color helper

private func c(_ path: String) -> Color { Color("Colors/\(path)") }

extension Color {
    /// Linear-interpolate between two colours in sRGB. `t` is the
    /// amount of `other` (0 → self, 1 → other). Used by templates
    /// that derive a palette ramp from a single user-picked accent
    /// (Heritage's plane tint, label colour, code colour, etc.).
    func mixed(with other: Color, by t: Double) -> Color {
        let a = UIColor(self)
        let b = UIColor(other)
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        let t = CGFloat(t)
        return Color(
            red: Double(ar + (br - ar) * t),
            green: Double(ag + (bg - ag) * t),
            blue: Double(ab + (bb - ab) * t),
            opacity: Double(aa + (ba - aa) * t)
        )
    }
}

extension Color {

    // MARK: Background

    enum Background {
        /// Page surface (Figma `Background/surface/default`) → Gray/0.
        static let `default` = c("background/surface/default")
        /// Elevated card (Figma `Background/surface/elevated`) → Gray/50.
        static let elevated  = c("background/surface/elevated")
        /// Muted surface (Figma `Background/surface/subtle`) → Gray/100.
        static let subtle    = c("background/surface/subtle")
        /// Subtle fill used for input fields & pill chips (Figma
        /// `Components/inputfield/background/default`).
        static let fieldFill = c("components/inputfield/background/default")

        /// Memory detail page tint per color family (Figma
        /// `Background/memory/<family>`). `family` is case-insensitive.
        static func memory(_ family: String) -> Color {
            c("background/memory/\(family.lowercased())")
        }
    }

    // MARK: Text

    enum Text {
        static let primary   = c("text/primary")
        static let secondary = c("text/secondary")
        static let tertiary  = c("text/tertiary")
        static let inactive  = c("text/inactive")
        /// Legacy alias for the disabled state — same value as `inactive`.
        static let disabled  = c("text/inactive")

        enum OnColor {
            static let black = c("Gray/Black")
            static let white = c("Gray/White")
        }
    }

    // MARK: Border

    enum Border {
        static let `default` = c("Gray/200")
        static let strong    = c("Gray/300")
        /// ~5% inverse tint — subtle dividers (TicketSlot bottom, etc.).
        static let subtle    = c("Opacity/Black/inverse/5")
        /// Thin field stroke (Figma `Components/inputfield/border/default`).
        static let hairline  = c("components/inputfield/border/default")

        enum OnBG {
            static let `default` = c("Gray/0")
            static let elevated  = c("Gray/50")
            static let subtle    = c("Gray/100")
        }
    }

    // MARK: Feedback

    enum Feedback {
        enum Danger {
            static let surface = c("feedback/danger/surface")
            static let border  = c("feedback/danger/border")
            static let text    = c("feedback/danger/text")
            static let content = c("feedback/danger/content")
            // Legacy aliases — kept for backwards compat with existing call sites.
            static let icon   = c("feedback/danger/border")
            static let subtle = c("feedback/danger/surface")
        }
        enum Warning {
            static let surface = c("feedback/warning/surface")
            static let border  = c("feedback/warning/border")
            static let text    = c("feedback/warning/text")
            static let content = c("feedback/warning/content")
            static let icon   = c("feedback/warning/border")
            static let subtle = c("feedback/warning/surface")
        }
        enum Information {
            static let surface = c("feedback/information/surface")
            static let border  = c("feedback/information/border")
            static let text    = c("feedback/information/text")
            static let content = c("feedback/information/content")
            static let icon   = c("feedback/information/border")
            static let subtle = c("feedback/information/surface")
        }
        enum Success {
            static let surface = c("feedback/success/surface")
            static let border  = c("feedback/success/border")
            static let text    = c("feedback/success/text")
            static let content = c("feedback/success/content")
            static let icon   = c("feedback/success/border")
            static let subtle = c("feedback/success/surface")
        }
        enum Neutral {
            static let surface = c("feedback/neutral/surface")
            static let border  = c("feedback/neutral/border")
            static let content = c("feedback/neutral/content")
            // Neutral has no `text` token in Figma — fall back to `border`.
            static let text   = c("feedback/neutral/border")
            static let icon   = c("feedback/neutral/border")
            static let subtle = c("feedback/neutral/surface")
        }
        enum Promotion {
            static let surface = c("feedback/promotion/surface")
            static let border  = c("feedback/promotion/border")
            static let text    = c("feedback/promotion/text")
            static let content = c("feedback/promotion/content")
        }
    }

    // MARK: Button

    enum Button {
        enum Primary {
            enum Background {
                static let `default` = c("components/button/primary/background/default")
                static let hover     = c("components/button/primary/background/hover")
                static let pressed   = c("components/button/primary/background/pressed")
                static let inactive  = c("components/button/primary/background/inactive")
            }
            enum Label {
                static let `default` = c("components/button/primary/label/default")
                static let inactive  = c("components/button/primary/label/inactive")
            }
        }
        enum Secondary {
            enum Background {
                static let `default` = c("components/button/secondary/background/default")
                static let hover     = c("components/button/secondary/background/hover")
                static let pressed   = c("components/button/secondary/background/pressed")
                static let inactive  = c("components/button/secondary/background/inactive")
            }
            enum Label {
                static let `default` = c("components/button/secondary/label/default")
                static let inactive  = c("components/button/secondary/label/inactive")
            }
            /// Outlined-button border. Figma has no semantic alias for the
            /// secondary stroke colour, so we map directly to the palette
            /// extremes — the same intent as the existing brand spec.
            enum Border {
                static let `default` = c("Gray/1100")
                static let inactive  = c("Gray/300")
            }
        }
        enum Tertiary {
            enum Background {
                static let `default` = c("components/button/tertiary/background/default")
                static let hover     = c("components/button/tertiary/background/hover")
                static let pressed   = c("components/button/tertiary/background/pressed")
                static let inactive  = c("components/button/tertiary/background/inactive")
            }
            enum Label {
                static let `default` = c("components/button/tertiary/label/default")
                static let inactive  = c("components/button/tertiary/label/inactive")
            }
        }
        /// Danger has no semantic alias in Figma — direct palette references
        /// match the brand spec (Red/600 → Red/900 across states).
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

    // MARK: InputField

    enum InputField {
        enum Background {
            static let `default` = c("components/inputfield/background/default")
            static let hover     = c("components/inputfield/background/hover")
            static let pressed   = c("components/inputfield/background/pressed")
            static let warning   = c("components/inputfield/background/warning")
            static let danger    = c("components/inputfield/background/danger")
        }
        enum Border {
            static let `default` = c("components/inputfield/border/default")
            static let hover     = c("components/inputfield/border/hover")
            static let pressed   = c("components/inputfield/border/pressed")
            static let warning   = c("components/inputfield/border/warning")
            static let danger    = c("components/inputfield/border/danger")
            static let inactive  = c("components/inputfield/border/inactive")
        }
        enum Label {
            static let `default` = c("components/inputfield/label/default")
            static let inactive  = c("components/inputfield/label/inactive")
            static let required  = c("components/inputfield/label/required")
        }
        enum Content {
            static let `default`   = c("components/inputfield/content/default")
            static let placeholder = c("components/inputfield/content/placeholder")
            static let inactive    = c("components/inputfield/content/inactive")
        }
        /// Assistive caption under the field. Figma doesn't expose a
        /// dedicated alias, so we map to the closest semantic colors.
        enum AssistiveText {
            static let `default` = c("Gray/600")
            static let danger    = c("feedback/danger/text")
            static let warning   = c("feedback/warning/text")
        }
    }

    // MARK: IconButton

    enum IconButton {
        enum OnBackground {
            enum Background {
                static let `default` = c("components/iconbutton/onbackground/background/default")
                static let hover     = c("components/iconbutton/onbackground/background/hover")
                static let pressed   = c("components/iconbutton/onbackground/background/pressed")
                static let active    = c("components/iconbutton/onbackground/background/active")
            }
            enum Content {
                static let `default` = c("components/iconbutton/onbackground/content/default")
                static let active    = c("components/iconbutton/onbackground/content/active")
                static let inactive  = c("components/iconbutton/onbackground/content/inactive")
            }
        }
        enum OnSurface {
            enum Background {
                static let `default` = c("components/iconbutton/onsurface/background/default")
                static let hover     = c("components/iconbutton/onsurface/background/hover")
                static let pressed   = c("components/iconbutton/onsurface/background/pressed")
                static let active    = c("components/iconbutton/onsurface/background/active")
            }
            enum Content {
                static let `default` = c("components/iconbutton/onsurface/content/default")
                static let active    = c("components/iconbutton/onsurface/content/active")
                static let inactive  = c("components/iconbutton/onsurface/content/inactive")
            }
        }
        /// Custom — no Figma alias. Used for icon buttons floating over
        /// dark imagery (e.g. full-screen photo sheets).
        enum OnDark {
            enum Background {
                static let `default` = c("Opacity/White/regular/15")
                static let pressed   = c("Opacity/White/regular/25")
            }
            enum Content {
                static let `default` = c("Gray/White")
            }
        }
        /// Custom — no Figma alias. Affirmative-action icon button (e.g.
        /// the green checkmark in the memory-edit top bar).
        enum Success {
            enum Background {
                static let `default` = c("Green/500")
                static let pressed   = c("Green/600")
            }
            enum Content {
                static let `default` = c("Gray/White")
            }
        }
    }

    // MARK: Memory components

    enum Memory {
        /// `Components/memory/background` — outer card tint.
        static let background = c("components/memory/background")
        enum Content {
            static let label = c("components/memory/content/label")
            static let count = c("components/memory/content/count")
        }
        enum TicketSlot {
            static let border = c("components/memory/ticketslot/border")
        }
    }

    // MARK: Ticket entry component

    enum TicketEntry {
        static let background = c("components/ticketentry/background/default")
    }

    // MARK: Controls

    enum Controls {
        enum Radio {
            static let border  = c("controls/radio/border")
            static let content = c("controls/radio/content")
        }
    }

    // MARK: Overlay

    enum Overlay {
        /// Sheet scrim — 70% black across all modes. Used behind custom
        /// bottom sheets and `fullScreenCover` content where SwiftUI's
        /// built-in dim isn't applied.
        ///
        /// Other Figma overlay tokens (`overlay/alert`, `overlay/loading`,
        /// `Overlay/default`, `Overlay/dark`) live in the asset catalog
        /// but aren't surfaced here — the system `.alert(...)` modifier
        /// owns its scrim, and we don't ship custom alert/loading
        /// components yet. Add bindings when a consumer exists.
        static let sheet = c("overlay/sheet")
    }

    // MARK: Misc

    enum Misc {
        /// Required-field marker (red asterisk).
        static let required = c("misc/required")
    }
}
