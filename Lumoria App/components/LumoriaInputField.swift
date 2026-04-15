//
//  LumoriaInputField.swift
//  Lumoria App
//
//  Labeled input field matching the Lumoria design system.
//  Supports: Text, Number, Email, Password, Area (multiline).
//  States:   default, error, warning, disabled.
//

import SwiftUI

// MARK: - State

enum LumoriaInputFieldState {
    case `default`
    case error
    case warning
    case disabled
}

// MARK: - View

struct LumoriaInputField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var isRequired: Bool = true
    var isSecure: Bool = false
    var isMultiline: Bool = false
    var state: LumoriaInputFieldState = .default
    var assistiveText: String? = nil
    var contentType: UITextContentType? = nil
    var keyboardType: UIKeyboardType = .default

    @State private var isRevealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            labelRow
            inputContainer
            if let assistive = assistiveText, !assistive.isEmpty {
                Text(assistive)
                    .font(.system(size: 11, weight: .regular))
                    .tracking(0.06)
                    .foregroundStyle(assistiveTextColor)
                    .lineSpacing(2)
            }
        }
        .disabled(state == .disabled)
    }

    // MARK: - Label

    private var labelRow: some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .tracking(-0.23)
                .foregroundStyle(.black)
            if isRequired {
                Text("*")
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(-0.23)
                    .foregroundStyle(Color(hex: "FF867E"))
            }
        }
        .opacity(state == .disabled ? 0.4 : 1)
    }

    // MARK: - Input

    private var inputContainer: some View {
        Group {
            if isMultiline {
                multilineInput
                    .frame(height: 97, alignment: .top)
            } else {
                singleLineInput
                    .frame(height: 50)
            }
        }
        .background(backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private var singleLineInput: some View {
        HStack(spacing: 8) {
            Group {
                if isSecure && !isRevealed {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
            }
            .font(.system(size: 17, weight: .regular))
            .tracking(-0.43)
            .foregroundStyle(textColor)
            .textContentType(contentType)

            if isSecure {
                revealButton
            }
        }
        .padding(.horizontal, 12)
    }

    private var multilineInput: some View {
        TextField(placeholder, text: $text, axis: .vertical)
            .lineLimit(3...)
            .font(.system(size: 17, weight: .regular))
            .tracking(-0.43)
            .foregroundStyle(textColor)
            .textContentType(contentType)
            .keyboardType(keyboardType)
            .autocapitalization(.none)
            .autocorrectionDisabled()
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var revealButton: some View {
        Button {
            isRevealed.toggle()
        } label: {
            Image(systemName: isRevealed ? "eye.slash" : "eye")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.black)
                .frame(width: 32, height: 32)
                .background(Color.black.opacity(0.05))
                .clipShape(Circle())
        }
    }

    // MARK: - Derived style

    private var cornerRadius: CGFloat { isMultiline ? 20 : 16 }

    private var backgroundColor: Color {
        switch state {
        case .default, .disabled: return Color.black.opacity(0.03)
        case .error:              return Color(hex: "FFF1EF")
        case .warning:            return Color(hex: "FFF6D1")
        }
    }

    private var borderColor: Color {
        switch state {
        case .default, .disabled: return Color.black.opacity(0.07)
        case .error:              return Color(hex: "FF867E")
        case .warning:            return Color(hex: "F5934A")
        }
    }

    private var textColor: Color {
        switch state {
        case .disabled: return Color(hex: "A3A3A3")
        default:        return .black
        }
    }

    private var assistiveTextColor: Color {
        switch state {
        case .error:   return Color(hex: "AC001A")
        case .warning: return Color(hex: "8A4500")
        default:       return Color(hex: "525252")
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var a = ""
    @Previewable @State var b = "user@example.com"
    @Previewable @State var c = "wrong password"
    @Previewable @State var d = "approaching limit"
    @Previewable @State var e = "disabled content"
    @Previewable @State var f = ""

    return ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            LumoriaInputField(
                label: "Name",
                placeholder: "Placeholder",
                text: $a,
                assistiveText: "Helper text"
            )
            LumoriaInputField(
                label: "Email",
                placeholder: "name@email.com",
                text: $b,
                contentType: .emailAddress,
                keyboardType: .emailAddress
            )
            LumoriaInputField(
                label: "Password",
                placeholder: "Password",
                text: $c,
                isSecure: true,
                state: .error,
                assistiveText: "Password is incorrect"
            )
            LumoriaInputField(
                label: "Username",
                placeholder: "Username",
                text: $d,
                state: .warning,
                assistiveText: "Username is almost taken"
            )
            LumoriaInputField(
                label: "Disabled",
                placeholder: "Placeholder",
                text: $e,
                state: .disabled
            )
            LumoriaInputField(
                label: "Notes",
                placeholder: "Type here…",
                text: $f,
                isRequired: false,
                isMultiline: true,
                assistiveText: "Up to 500 characters"
            )
        }
        .padding(24)
    }
}
