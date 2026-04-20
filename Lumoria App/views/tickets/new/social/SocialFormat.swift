//
//  SocialFormat.swift
//  Lumoria App
//
//  Single source of truth for every export format in the Social Media
//  destination. Encodes canvas size (matches the Figma frame), which
//  grid section the tile sits in, its analytics destination, and the
//  platform icon asset name.
//

import Foundation
import SwiftUI

enum SocialFormat: String, CaseIterable, Identifiable {
    case square
    case story
    case facebook
    case instagram
    case x

    var id: String { rawValue }

    enum Section {
        case defaultFormats
        case vertical
    }

    var section: Section {
        switch self {
        case .square, .story:           return .defaultFormats
        case .facebook, .instagram, .x: return .vertical
        }
    }

    var canvasSize: CGSize {
        switch self {
        case .square:    return CGSize(width: 1080, height: 1080)
        case .story:     return CGSize(width: 1080, height: 1920)
        case .facebook:  return CGSize(width: 1080, height: 1359)
        case .instagram: return CGSize(width: 1080, height: 1350)
        case .x:         return CGSize(width:  720, height: 1280)
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .square:    return "Square"
        case .story:     return "Story"
        case .facebook:  return "Facebook"
        case .instagram: return "Instagram"
        case .x:         return "X"
        }
    }

    var platformIconAssetName: String? {
        switch self {
        case .square, .story: return nil
        case .facebook:       return "export/social/Facebook"
        case .instagram:      return "export/social/IG"
        case .x:              return "export/social/X"
        }
    }

    var analyticsDestination: ExportDestinationProp {
        switch self {
        case .square:    return .social_square
        case .story:     return .social_story
        case .facebook:  return .social_facebook
        case .instagram: return .social_instagram
        case .x:         return .social_x
        }
    }
}
