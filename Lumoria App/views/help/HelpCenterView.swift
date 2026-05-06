//
//  HelpCenterView.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1771-64485
//

import SwiftUI

struct HelpCenterView: View {

    @Environment(\.dismiss) private var dismiss
    let onArticleSelected: (HelpArticle) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                topBar
                    .padding(.top, 6)
                    .padding(.bottom, 8)

                Text("Help center")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color.Text.primary)
                    .padding(.bottom, 8)

                ForEach(HelpSection.allCases, id: \.self) { section in
                    sectionGroup(section)
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

    // MARK: - Section

    @ViewBuilder
    private func sectionGroup(_ section: HelpSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey(section.rawValue))
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.Text.primary)

            VStack(spacing: 0) {
                ForEach(HelpCenterContent.articles(in: section)) { article in
                    articleRow(article)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.Background.elevated)
            )
        }
    }

    // MARK: - Row

    private func articleRow(_ article: HelpArticle) -> some View {
        Button {
            onArticleSelected(article)
        } label: {
            HStack(spacing: 12) {
                Text(LocalizedStringKey(article.title))
                    .font(.body)
                    .foregroundStyle(Color.Text.primary)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.Text.primary)
                    .frame(width: 32, height: 32)
            }
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .padding(.vertical, 8)
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        HelpCenterView { _ in }
    }
}
