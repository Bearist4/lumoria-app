//
//  ShareSheet.swift
//  Lumoria App
//
//  Shared `UIActivityViewController` wrapper. Present via `.sheet` with an
//  array of activity items (UIImage, String, URL, …). Used by invite and
//  IM export flows.
//

import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var applicationActivities: [UIActivity]? = nil
    var excludedActivityTypes: [UIActivity.ActivityType]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items,
                                                  applicationActivities: applicationActivities)
        controller.excludedActivityTypes = excludedActivityTypes
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
