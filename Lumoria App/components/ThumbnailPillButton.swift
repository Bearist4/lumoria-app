//
//  ThumbnailPillButton.swift
//  Lumoria App
//
//  Pill button with a 32pt rounded thumbnail on the leading side and a label
//  on the right. Used for "View map" today; "View calendar" and similar
//  shortcuts share the same layout.
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=948-12240
//

import SwiftUI

struct ThumbnailPillButton<Leading: View>: View {
    let title: String
    let action: () -> Void
    let leading: Leading

    init(
        title: String,
        action: @escaping () -> Void,
        @ViewBuilder leading: () -> Leading
    ) {
        self.title = title
        self.action = action
        self.leading = leading()
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                leading
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.Text.primary)
            }
            .padding(.leading, 8)
            .padding(.trailing, 12)
            .padding(.vertical, 8)
            .background(Color.Background.elevated, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
