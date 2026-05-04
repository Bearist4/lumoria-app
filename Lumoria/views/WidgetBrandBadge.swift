//
//  WidgetBrandBadge.swift
//  Lumoria (widget)
//
//  Shared 24×24 brand logomark badge used in the corner of every widget
//  variant. Reads the pre-rendered PNG written by `WidgetSnapshotWriter`
//  in the main app — falls back to a cream-filled rounded square so the
//  layout never collapses if the file is missing (signed-out / first run).
//

import SwiftUI
import UIKit

struct WidgetBrandBadge: View {
    var size: CGFloat = 24
    var cornerRadius: CGFloat = 7.2

    var body: some View {
        Group {
            if let image = loadBrandLogomark() {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(red: 1.0, green: 0.988, blue: 0.941))
            }
        }
        .frame(width: size, height: size)
    }

    private func loadBrandLogomark() -> UIImage? {
        guard let url = WidgetSharedContainer.brandLogomarkURL else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}
