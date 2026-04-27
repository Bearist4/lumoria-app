//
//  LumoriaNumberedData.swift
//  Lumoria App
//
//  Compact stat pill — a big value over a small label, inside a subtle
//  rounded tile. Sibling of `LumoriaDataCard`; this variant is used when
//  multiple metrics need to pack into a dense 2×2 grid (see `DataArea`
//  at the bottom of `MemoryMapView`).
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1841-39703
//

import SwiftUI

struct LumoriaNumberedData: View {

    let value: String
    let label: LocalizedStringKey

    init(value: String, label: LocalizedStringKey) {
        self.value = value
        self.label = label
    }

    /// Convenience: render an integer value directly.
    init(value: Int, label: LocalizedStringKey) {
        self.init(value: "\(value)", label: label)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.title3.weight(.semibold)).fontDesign(.rounded)
                .foregroundStyle(Color.Text.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(label)
                .font(.footnote)
                .foregroundStyle(Color.Text.primary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color("Colors/Opacity/Black/inverse/5"))
        )
    }
}

// MARK: - Preview

#Preview("NumberedData") {
    LazyVGrid(
        columns: [GridItem(.flexible()), GridItem(.flexible())],
        spacing: 8
    ) {
        LumoriaNumberedData(value: 9,       label: "Tickets")
        LumoriaNumberedData(value: 8,       label: "Days")
        LumoriaNumberedData(value: 4,       label: "Categories")
        LumoriaNumberedData(value: "20.85", label: "Kilometers")
    }
    .padding(16)
    .background(Color.Background.default)
}
