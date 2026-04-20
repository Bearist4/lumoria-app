//
//  HelpArticleView.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1771-65006
//

import SwiftUI
import AVKit

struct HelpArticleView: View {

    @Environment(\.dismiss) private var dismiss
    let article: HelpArticle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                topBar
                    .padding(.top, 6)

                Text(article.title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color.Text.primary)
                    .padding(.top, 8)
                    .padding(.bottom, 8)

                videoHero

                Text(article.intro)
                    .font(.body)
                    .foregroundStyle(Color.Text.primary)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(Array(article.steps.enumerated()), id: \.offset) { index, step in
                    stepCard(number: index + 1, step: step)
                }

                if let outro = article.outro {
                    Text(outro)
                        .font(.subheadline)
                        .foregroundStyle(Color.Text.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 120)
        }
        .background(Color.Background.default.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            LumoriaIconButton(
                systemImage: "chevron.left",
                position: .onBackground
            ) { dismiss() }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Video hero

    @ViewBuilder
    private var videoHero: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.Background.elevated)
            .aspectRatio(408.0 / 458.0, contentMode: .fit)
            .overlay {
                if let name = article.videoName,
                   let url = Bundle.main.url(forResource: name, withExtension: "mp4") {
                    VideoPlayer(player: AVPlayer(url: url))
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                } else {
                    placeholderHero
                }
            }
            .frame(maxWidth: .infinity)
    }

    private var placeholderHero: some View {
        VStack(spacing: 12) {
            Image(systemName: "play.circle")
                .font(.system(size: 56, weight: .regular))
                .foregroundStyle(Color.Text.tertiary)

            Text("Walkthrough coming soon")
                .font(.subheadline)
                .foregroundStyle(Color.Text.secondary)
        }
    }

    // MARK: - Step card

    private func stepCard(number: Int, step: HelpStep) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "\(number).circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.Text.primary)

                Text(step.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.Text.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(step.body)
                .font(.body)
                .foregroundStyle(Color.Text.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.Background.fieldFill)
        )
    }
}

#Preview {
    NavigationStack {
        HelpArticleView(article: HelpCenterContent.createTicket)
    }
}
