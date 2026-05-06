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
        case .albania:        return String(localized: "Albania", locale: .ticket)
        case .armenia:        return String(localized: "Armenia", locale: .ticket)
        case .australia:      return String(localized: "Australia", locale: .ticket)
        case .austria:        return String(localized: "Austria", locale: .ticket)
        case .azerbaijan:     return String(localized: "Azerbaijan", locale: .ticket)
        case .belgium:        return String(localized: "Belgium", locale: .ticket)
        case .bulgaria:       return String(localized: "Bulgaria", locale: .ticket)
        case .croatia:        return String(localized: "Croatia", locale: .ticket)
        case .cyprus:         return String(localized: "Cyprus", locale: .ticket)
        case .czechia:        return String(localized: "Czechia", locale: .ticket)
        case .denmark:        return String(localized: "Denmark", locale: .ticket)
        case .estonia:        return String(localized: "Estonia", locale: .ticket)
        case .finland:        return String(localized: "Finland", locale: .ticket)
        case .france:         return String(localized: "France", locale: .ticket)
        case .georgia:        return String(localized: "Georgia", locale: .ticket)
        case .germany:        return String(localized: "Germany", locale: .ticket)
        case .greece:         return String(localized: "Greece", locale: .ticket)
        case .israel:         return String(localized: "Israel", locale: .ticket)
        case .italy:          return String(localized: "Italy", locale: .ticket)
        case .latvia:         return String(localized: "Latvia", locale: .ticket)
        case .lithuania:      return String(localized: "Lithuania", locale: .ticket)
        case .luxembourg:     return String(localized: "Luxembourg", locale: .ticket)
        case .malta:          return String(localized: "Malta", locale: .ticket)
        case .moldova:        return String(localized: "Moldova", locale: .ticket)
        case .montenegro:     return String(localized: "Montenegro", locale: .ticket)
        case .norway:         return String(localized: "Norway", locale: .ticket)
        case .poland:         return String(localized: "Poland", locale: .ticket)
        case .portugal:       return String(localized: "Portugal", locale: .ticket)
        case .romania:        return String(localized: "Romania", locale: .ticket)
        case .sanMarino:      return String(localized: "San Marino", locale: .ticket)
        case .serbia:         return String(localized: "Serbia", locale: .ticket)
        case .sweden:         return String(localized: "Sweden", locale: .ticket)
        case .switzerland:    return String(localized: "Switzerland", locale: .ticket)
        case .ukraine:        return String(localized: "Ukraine", locale: .ticket)
        case .unitedKingdom:  return String(localized: "United Kingdom", locale: .ticket)
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
