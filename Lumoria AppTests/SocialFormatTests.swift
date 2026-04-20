//
//  SocialFormatTests.swift
//  Lumoria AppTests
//
//  Shape tests for `SocialFormat` — canvas sizes must match the Figma
//  frames, section grouping drives the grid layout, analytics
//  destinations stay unique per format.
//

import Foundation
import Testing
@testable import Lumoria_App

@Suite("SocialFormat")
struct SocialFormatTests {

    @Test("all cases have unique canvas sizes")
    func uniqueCanvasSizes() {
        let sizes = SocialFormat.allCases.map { $0.canvasSize }
        #expect(Set(sizes.map { "\($0.width)x\($0.height)" }).count == sizes.count)
    }

    @Test("canvas sizes match Figma frames")
    func canvasSizes() {
        #expect(SocialFormat.square.canvasSize    == CGSize(width: 1080, height: 1080))
        #expect(SocialFormat.story.canvasSize     == CGSize(width: 1080, height: 1920))
        #expect(SocialFormat.facebook.canvasSize  == CGSize(width: 1080, height: 1359))
        #expect(SocialFormat.instagram.canvasSize == CGSize(width: 1080, height: 1350))
        #expect(SocialFormat.x.canvasSize         == CGSize(width:  720, height: 1280))
    }

    @Test("section grouping matches Figma sheet")
    func sections() {
        #expect(SocialFormat.square.section    == .defaultFormats)
        #expect(SocialFormat.story.section     == .defaultFormats)
        #expect(SocialFormat.facebook.section  == .vertical)
        #expect(SocialFormat.instagram.section == .vertical)
        #expect(SocialFormat.x.section         == .vertical)
    }

    @Test("analytics destinations are distinct per format")
    func analyticsDestinations() {
        #expect(SocialFormat.square.analyticsDestination    == .social_square)
        #expect(SocialFormat.story.analyticsDestination     == .social_story)
        #expect(SocialFormat.facebook.analyticsDestination  == .social_facebook)
        #expect(SocialFormat.instagram.analyticsDestination == .social_instagram)
        #expect(SocialFormat.x.analyticsDestination         == .social_x)
    }
}
