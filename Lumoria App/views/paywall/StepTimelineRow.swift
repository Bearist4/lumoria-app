//
//  StepTimelineRow.swift
//  Lumoria App
//
//  Vertical timeline row used by InviteExplanationView and
//  TrialExplanationView. Shows a circular icon badge on the left, a
//  bold heading + secondary body on the right, and a thin vertical
//  connector line between consecutive rows.
//

import SwiftUI

/// One row in a vertical step timeline.
///
/// `isLast` collapses the connector line below the badge so the final
/// row terminates cleanly.
struct StepTimelineRow<Icon: View>: View {
    let icon: Icon
    let heading: LocalizedStringKey
    let bodyText: LocalizedStringKey
    let isLast: Bool

    init(
        heading: LocalizedStringKey,
        body: LocalizedStringKey,
        isLast: Bool = false,
        @ViewBuilder icon: () -> Icon
    ) {
        self.icon = icon()
        self.heading = heading
        self.bodyText = body
        self.isLast = isLast
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.05))
                        .frame(width: 40, height: 40)
                    icon
                        .font(.headline)
                        .foregroundStyle(.black)
                }
                if !isLast {
                    Rectangle()
                        .fill(Color.black.opacity(0.1))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(heading)
                    .font(.headline)
                    .foregroundStyle(.black)
                Text(bodyText)
                    .font(.subheadline)
                    .foregroundStyle(Color.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, isLast ? 0 : 20)
            .padding(.top, 8)
        }
    }
}
