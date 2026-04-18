//
//  BrandArt.swift
//  Lumoria App
//
//  Maps the user's selected alternate app icon to the slug of the matching
//  in-app brand-art folder, so logomark / full / logo assets everywhere
//  (landing page, settings, ticket watermarks, IM share card) follow the
//  chosen icon variant.
//
//  Asset convention in `Assets.xcassets`:
//    brand/<slug>/logomark
//    brand/<slug>/full
//    brand/<slug>/logo
//  where <slug> ∈ { default, noir, earth, outline }.
//

import SwiftUI

enum BrandArt {
    /// Translate the `UIApplication.alternateIconName` value (or its stored
    /// `@AppStorage` mirror) into the brand-art folder slug. Empty string
    /// or nil = "default".
    static func slug(from alternateIconName: String?) -> String {
        switch alternateIconName {
        case "AppIcon Noir":    return "noir"
        case "AppIcon Earth":   return "earth"
        case "AppIcon Outline": return "outline"
        default:                return "default"
        }
    }
}

// MARK: - Environment

private struct BrandSlugKey: EnvironmentKey {
    static let defaultValue: String = "default"
}

extension EnvironmentValues {
    /// Current brand-art folder slug. Consumers read this and construct
    /// asset names: `Image("brand/\(brandSlug)/logomark")`. Set at the app
    /// root from `@AppStorage("appearance.iconName")`.
    var brandSlug: String {
        get { self[BrandSlugKey.self] }
        set { self[BrandSlugKey.self] = newValue }
    }
}
