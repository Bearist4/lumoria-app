//
//  EurovisionCountry.swift
//  Lumoria App
//
//  The 35 countries selectable in the Eurovision form's country
//  dropdown. Only the centered logo is per-country — the horizontal
//  and vertical backgrounds are shared across every variant.
//
//  Slots are pre-created (empty) under `Assets.xcassets/tickets/eurovision/`:
//
//      eurovision/
//        background/
//          eurovision-bg-h.imageset    (shared horizontal bg)
//          eurovision-bg-v.imageset    (shared vertical bg)
//        logo/
//          eurovision-logo-<cc>.imageset × 35
//
//  Drop a designer PNG into a slot to ship artwork. Missing-image
//  fall-throughs render a swatch background and a flag-emoji
//  placeholder so the template stays readable while assets are in
//  flight.
//

import Foundation

enum EurovisionCountry: String, CaseIterable, Codable, Hashable, Identifiable {

    case albania, armenia, australia, austria, azerbaijan
    case belgium, bulgaria, croatia, cyprus, czechia
    case denmark, estonia, finland, france, georgia
    case germany, greece, israel, italy, latvia
    case lithuania, luxembourg, malta, moldova, montenegro
    case norway, poland, portugal, romania, sanMarino
    case serbia, sweden, switzerland, ukraine, unitedKingdom

    var id: String { rawValue }

    /// ISO 3166-1 alpha-2 country code, lowercased. Used as the asset
    /// suffix (`eurovision-bg-fr`) and as the persisted payload field
    /// so the same string survives encode/decode.
    var isoCode: String {
        switch self {
        case .albania:        return "al"
        case .armenia:        return "am"
        case .australia:      return "au"
        case .austria:        return "at"
        case .azerbaijan:     return "az"
        case .belgium:        return "be"
        case .bulgaria:       return "bg"
        case .croatia:        return "hr"
        case .cyprus:         return "cy"
        case .czechia:        return "cz"
        case .denmark:        return "dk"
        case .estonia:        return "ee"
        case .finland:        return "fi"
        case .france:         return "fr"
        case .georgia:        return "ge"
        case .germany:        return "de"
        case .greece:         return "gr"
        case .israel:         return "il"
        case .italy:          return "it"
        case .latvia:         return "lv"
        case .lithuania:      return "lt"
        case .luxembourg:     return "lu"
        case .malta:          return "mt"
        case .moldova:        return "md"
        case .montenegro:     return "me"
        case .norway:         return "no"
        case .poland:         return "pl"
        case .portugal:       return "pt"
        case .romania:        return "ro"
        case .sanMarino:      return "sm"
        case .serbia:         return "rs"
        case .sweden:         return "se"
        case .switzerland:    return "ch"
        case .ukraine:        return "ua"
        case .unitedKingdom:  return "gb"
        }
    }

    /// User-facing country name shown in the dropdown row and (via
    /// `displayLabel`) on the rendered ticket if the per-country logo
    /// asset is missing. English names match the EBU's broadcast labels.
    var displayName: String {
        switch self {
        case .albania:        return String(localized: "Albania")
        case .armenia:        return String(localized: "Armenia")
        case .australia:      return String(localized: "Australia")
        case .austria:        return String(localized: "Austria")
        case .azerbaijan:     return String(localized: "Azerbaijan")
        case .belgium:        return String(localized: "Belgium")
        case .bulgaria:       return String(localized: "Bulgaria")
        case .croatia:        return String(localized: "Croatia")
        case .cyprus:         return String(localized: "Cyprus")
        case .czechia:        return String(localized: "Czechia")
        case .denmark:        return String(localized: "Denmark")
        case .estonia:        return String(localized: "Estonia")
        case .finland:        return String(localized: "Finland")
        case .france:         return String(localized: "France")
        case .georgia:        return String(localized: "Georgia")
        case .germany:        return String(localized: "Germany")
        case .greece:         return String(localized: "Greece")
        case .israel:         return String(localized: "Israel")
        case .italy:          return String(localized: "Italy")
        case .latvia:         return String(localized: "Latvia")
        case .lithuania:      return String(localized: "Lithuania")
        case .luxembourg:     return String(localized: "Luxembourg")
        case .malta:          return String(localized: "Malta")
        case .moldova:        return String(localized: "Moldova")
        case .montenegro:     return String(localized: "Montenegro")
        case .norway:         return String(localized: "Norway")
        case .poland:         return String(localized: "Poland")
        case .portugal:       return String(localized: "Portugal")
        case .romania:        return String(localized: "Romania")
        case .sanMarino:      return String(localized: "San Marino")
        case .serbia:         return String(localized: "Serbia")
        case .sweden:         return String(localized: "Sweden")
        case .switzerland:    return String(localized: "Switzerland")
        case .ukraine:        return String(localized: "Ukraine")
        case .unitedKingdom:  return String(localized: "United Kingdom")
        }
    }

    /// Flag emoji derived from the alpha-2 code. Drives the dropdown
    /// row's leading glyph and the placeholder rendered on the ticket
    /// when `eurovision-logo-<code>` is missing.
    var flagEmoji: String {
        let base: UInt32 = 127397
        var s = ""
        for scalar in isoCode.uppercased().unicodeScalars {
            if let pair = UnicodeScalar(base + scalar.value) {
                s.unicodeScalars.append(pair)
            }
        }
        return s
    }

    /// Asset slot for the centered "Eurovision · <country>" heart logo.
    /// Shared between horizontal and vertical templates.
    var logoAssetName: String { "eurovision-logo-\(isoCode)" }

    /// Looks up a country by its persisted `isoCode`. Used by the
    /// renderer when decoding tickets that store only the code string.
    static func fromIsoCode(_ code: String) -> EurovisionCountry? {
        let needle = code.lowercased()
        return allCases.first { $0.isoCode == needle }
    }
}
