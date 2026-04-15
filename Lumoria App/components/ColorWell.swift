//
//  ColorWell.swift
//  Lumoria App
//
//  Small rounded swatch used inside dropdown rows, collection previews, etc.
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=982-28058
//

import SwiftUI

struct ColorWell: View {
    let color: Color
    var size: CGSize = CGSize(width: 50, height: 28)
    var cornerRadius: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(color)
            .frame(width: size.width, height: size.height)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.Border.default, lineWidth: 1)
            )
    }
}

#Preview {
    VStack(spacing: 12) {
        ColorWell(color: Color("Colors/Blue/50"))
        ColorWell(color: Color("Colors/Green/50"))
        ColorWell(color: Color("Colors/Red/50"))
        ColorWell(color: Color("Colors/Yellow/50"))
    }
    .padding(24)
}
