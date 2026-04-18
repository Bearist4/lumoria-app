//
//  LumoriaLinks.swift
//  Lumoria App
//
//  Brand-level links and share copy used by the IM share flow and any
//  other surface that needs to point at the public landing page.
//

import Foundation

enum LumoriaLinks {
    /// Public landing page. On iOS resolves to App Store; elsewhere shows a
    /// waitlist form.
    static let shareURL = URL(string: "https://getlumoria.app")!

    /// Message pre-populated in the IM activity sheet alongside the rendered
    /// ticket image.
    static let shareMessage = "Look what I made on Lumoria — https://getlumoria.app"
}
