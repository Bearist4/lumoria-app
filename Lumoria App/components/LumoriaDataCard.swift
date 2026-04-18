//
//  LumoriaDataCard.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1124-262329
//
//  A 180×180 rounded tile that surfaces a single calculated metric from the
//  database. Extensible — new variants can be added by introducing new
//  `LumoriaDataCardContent` cases.
//

import SwiftUI

// MARK: - Content model

/// The body displayed inside a `LumoriaDataCard`.
enum LumoriaDataCardContent {
    /// A single big value (number or short text) + a small caption.
    /// Example: "3" / "memories created".
    case value(String, caption: String)

    /// A big value followed by an inline suffix + a caption below.
    /// Example: "3" "months" / "Longest gap between tickets".
    case valueWithSuffix(String, suffix: String, caption: String)
}

// MARK: - Card

/// A compact card that displays one calculated stat from the database.
/// Accepts a palette family (e.g. `"Orange"`, `"Blue"`, `"Pink"`,
/// `"Yellow"`, `"Lime"`) used to tint the big value and the decorative
/// glow in the top-right corner.
struct LumoriaDataCard: View {

    let content: LumoriaDataCardContent
    /// Palette family name. Resolves to `Colors/<family>/400` for the
    /// value color and the decorative glow tint.
    let accentColorFamily: String

    init(
        content: LumoriaDataCardContent,
        accentColorFamily: String
    ) {
        self.content = content
        self.accentColorFamily = accentColorFamily
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            glow
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            VStack(alignment: .leading, spacing: 0) {
                valueRow

                Spacer(minLength: 0)

                Text(caption)
                    .font(.subheadline)
                    .foregroundStyle(Color.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 16)
        }
        .frame(width: 180, height: 180)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.Background.default)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.Background.fieldFill, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    // MARK: Subviews

    private var valueRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(primaryValue)
                .font(.largeTitle.bold()).fontDesign(.rounded)
                .foregroundStyle(accentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            if let suffix = valueSuffix {
                Text(suffix)
                    .font(.caption)
                    .foregroundStyle(Color.Text.tertiary)
            }

            Spacer(minLength: 0)
        }
    }

    private var glow: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [accentColor.opacity(0.35), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 70
                )
            )
            .frame(width: 140, height: 140)
            .blur(radius: 18)
            .offset(x: 28, y: -40)
            .allowsHitTesting(false)
    }

    // MARK: Derived

    private var accentColor: Color {
        Color("Colors/\(accentColorFamily)/400")
    }

    private var primaryValue: String {
        switch content {
        case .value(let v, _):                return v
        case .valueWithSuffix(let v, _, _):   return v
        }
    }

    private var valueSuffix: String? {
        switch content {
        case .value:                           return nil
        case .valueWithSuffix(_, let s, _):    return s
        }
    }

    private var caption: String {
        switch content {
        case .value(_, let c):                 return c
        case .valueWithSuffix(_, _, let c):    return c
        }
    }
}

// MARK: - Preview

#Preview("Data cards") {
    ScrollView {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 16
        ) {
            LumoriaDataCard(
                content: .value("3", caption: "memories created"),
                accentColorFamily: "Orange"
            )
            LumoriaDataCard(
                content: .value("120", caption: "tickets created this year"),
                accentColorFamily: "Pink"
            )
            LumoriaDataCard(
                content: .value("9", caption: "tickets created this month"),
                accentColorFamily: "Blue"
            )
            LumoriaDataCard(
                content: .valueWithSuffix(
                    "3",
                    suffix: "months",
                    caption: "Longest gap between tickets"
                ),
                accentColorFamily: "Yellow"
            )
            LumoriaDataCard(
                content: .value("Plane", caption: "Most used category"),
                accentColorFamily: "Lime"
            )
        }
        .padding(24)
    }
    .background(Color.Background.elevated)
}
