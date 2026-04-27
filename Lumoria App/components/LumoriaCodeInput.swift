//
//  LumoriaCodeInput.swift
//  Lumoria App
//
//  6-digit OTP-style numeric input. Per Figma node 1983:128613 — six
//  equal-width cells, 50pt tall, soft border + low-alpha fill, SF Pro
//  Rounded Semibold 20 digits, "0" tertiary-text placeholder when empty.
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
                .frame(maxWidth: .infinity, maxHeight: 50)
                .onChange(of: code) { _, new in
                    let cleaned = Self.sanitize(new)
                    if cleaned != new { code = cleaned }
                    if Self.isComplete(cleaned) { onComplete?(cleaned) }
                }

            HStack(spacing: 4) {
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
        let isEmpty = char == nil

        return ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.03))
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isCursor ? Color.accentColor : Color.black.opacity(0.07),
                    lineWidth: isCursor ? 2 : 1
                )
            Text(isEmpty ? "0" : String(char!))
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isEmpty ? Color(.tertiaryLabel) : Color.primary)
                .tracking(-0.43)
        }
        .frame(maxWidth: .infinity, minHeight: 50, maxHeight: 50)
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
