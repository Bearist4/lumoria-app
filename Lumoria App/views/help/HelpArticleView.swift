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
                if let name = article.videoName, let url = videoURL(named: name) {
                    BezeledVideoPlayer(url: url)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                } else {
                    placeholderHero
                }
            }
            .frame(maxWidth: .infinity)
    }

    /// Looks up a bundled video asset by name, tolerant of `.mp4` or `.mov`.
    private func videoURL(named name: String) -> URL? {
        for ext in ["mp4", "mov"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                return url
            }
        }
        return nil
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
        HelpArticleView(article: HelpCenterContent.browseCollection)
    }
}

// MARK: - Bezeled video player

/// Renders an iPhone bezel image with the video inlaid over the screen
/// region of the frame. Playback starts after a 3-second delay on appear.
private struct BezeledVideoPlayer: View {
    let url: URL

    /// Which bezel color to render behind the video.
    private let bezelAsset: String = "bezels/iphone/gray"

    /// Bezel artwork is 1206×2622 with a ~96pt radius around the device
    /// screen. These numbers are proportions of the full bezel image;
    /// they crop the video to the visible screen area so the status-bar
    /// notch and rounded corners never peek through.
    private let screenInsets = EdgeInsets(top: 0.015, leading: 0.037, bottom: 0.015, trailing: 0.037)
    private let screenCornerRatio: CGFloat = 0.072

    @State private var player: AVPlayer = AVPlayer()
    @State private var didStart = false

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let screenCornerRadius = min(w, h) * screenCornerRatio

            ZStack {
                VideoPlayer(player: player)
                    .frame(
                        width: w * (1 - screenInsets.leading - screenInsets.trailing),
                        height: h * (1 - screenInsets.top - screenInsets.bottom)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: screenCornerRadius, style: .continuous))

                Image(bezelAsset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: w, height: h)
                    .allowsHitTesting(false)
            }
            .frame(width: w, height: h)
        }
        .aspectRatio(1206.0 / 2622.0, contentMode: .fit)
        .onAppear { scheduleStart() }
        .onDisappear {
            player.pause()
            didStart = false
        }
    }

    private func scheduleStart() {
        guard !didStart else { return }
        didStart = true
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        player.isMuted = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            player.play()
        }
    }
}
