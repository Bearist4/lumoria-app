//
//  LumoriaCodeInput.swift
//  Lumoria App
//

import SwiftUI

struct LumoriaCodeInput: View {
    @Binding var code: String
    var onComplete: ((String) -> Void)? = nil

    @FocusState private var focused: Bool
    private let length = 6

    var body: some View {
        ZStack {
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focused)
                .opacity(0.001)
                .frame(maxWidth: .infinity, maxHeight: 64)
                .onChange(of: code) { _, new in
                    let cleaned = Self.sanitize(new)
                    if cleaned != new { code = cleaned }
                    if Self.isComplete(cleaned) { onComplete?(cleaned) }
                }

            HStack(spacing: 10) {
                ForEach(0..<length, id: \.self) { i in
                    digitCell(at: i)
                }
            }
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
        .onAppear { focused = true }
    }

    private func digitCell(at index: Int) -> some View {
        let chars = Array(code)
        let char: Character? = index < chars.count ? chars[index] : nil
        let isCursor = index == chars.count && focused

        return Text(char.map { String($0) } ?? "")
            .font(.system(size: 28, weight: .semibold, design: .monospaced))
            .frame(width: 44, height: 56)
            .background(Color(.systemGray6))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isCursor ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    static func sanitize(_ raw: String) -> String {
        let digits = raw.filter { $0.isNumber }
        return String(digits.prefix(6))
    }

    static func isComplete(_ value: String) -> Bool {
        value.count == 6 && value.allSatisfy { $0.isNumber }
    }
}

#Preview {
    @Previewable @State var code = ""
    return LumoriaCodeInput(code: $code)
        .padding()
}
