//
//  EmptyStateInlineBadge.swift
//  Lumoria App
//
//  Tiny inline affordance baked into empty-state copy — points the
//  user toward a toolbar button. 18×18 circle at 5% black with a
//  7.5pt SF Symbol. Non-interactive; purely a visual hint.
//

import SwiftUI

struct EmptyStateInlineBadge: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 7.5, weight: .semibold))
            .foregroundStyle(Color.Text.primary)
            .frame(width: 18, height: 18)
            .background(Color.Border.subtle)
            .clipShape(Circle())
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 6) {
        Text("Tap")
        EmptyStateInlineBadge(systemImage: "plus")
        Text("to start one.")
    }
    .font(.system(size: 17))
    .padding(24)
}
