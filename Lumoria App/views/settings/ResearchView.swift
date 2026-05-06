//
//  ResearchView.swift
//  Lumoria App
//
//  Hub for research-related touchpoints surfaced once the user holds
//  an early-adopter seat: surveys, interview invites, and an opt-out.
//  Lives behind the Research row on the Settings stack — only reachable
//  when `EntitlementStore.isEarlyAdopter` is true, but rendered on its
//  own so a stale deep-link can't NPE.
//

import SwiftUI

struct ResearchView: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Research")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color.Text.primary)

                emptyState
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color.Background.default.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                LumoriaIconButton(systemImage: "arrow.left") { dismiss() }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(Color.Text.tertiary)
                .padding(.top, 24)

            Text("No active research")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.Text.primary)

            Text("Surveys and interview invites land here when the team is collecting feedback. Quiet for now.")
                .font(.body)
                .foregroundStyle(Color.Text.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.Background.elevated)
        )
    }
}

#if DEBUG
#Preview {
    NavigationStack { ResearchView() }
}
#endif
