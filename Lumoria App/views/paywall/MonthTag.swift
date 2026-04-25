//
//  MonthTag.swift
//  Lumoria App
//
//  Yellow capsule that sits inside the annual PlanCard tile.
//  Figma: 968:17993 (yellow/300 #FDDC51, 16pt SF Pro Semibold black,
//  4pt vertical / 16pt horizontal padding, fully rounded).
//

import SwiftUI

struct MonthTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 16, weight: .semibold))
            .kerning(-0.31)
            .foregroundStyle(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(Color(red: 0.992, green: 0.863, blue: 0.318), in: Capsule())
    }
}

#Preview {
    MonthTag(text: "2 months free")
}
