//
//  LumoriaInputField.swift
//  Lumoria App
//
//  Labeled input field matching the Lumoria design system.
//  Supports: Text, Number, Email, Password, Area (multiline), Emoji.
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

// MARK: - Type

/// Visual variant of the field. The `.emoji` case renders a 50×50 square
/// input that holds a single emoji; tapping it opens an emoji picker.
private enum LumoriaInputFieldKind {
    case text
    case emoji(Binding<String?>)
}

// MARK: - View

struct LumoriaInputField: View {
    let label: LocalizedStringKey
    let placeholder: LocalizedStringKey
    @Binding var text: String

    var isRequired: Bool = true
    var isSecure: Bool = false
    var isMultiline: Bool = false
    var state: LumoriaInputFieldState = .default
    var assistiveText: LocalizedStringKey? = nil
    var contentType: UITextContentType? = nil
    var keyboardType: UIKeyboardType = .default

    private var kind: LumoriaInputFieldKind = .text

    @State private var isRevealed = false
    @State private var showEmojiPicker = false
    @FocusState private var isFocused: Bool

    // Nulls contentType under Maestro so iOS autofill / strong-password
    // takeover doesn't intercept keystrokes on SecureField.
    // Accepts the signal via any of: launch args (`-uitest`/`--uitest`),
    // UserDefaults (`-uitest YES`), or env var (`UITEST=1`).
    private var effectiveContentType: UITextContentType? {
        let args = CommandLine.arguments
        let hasArg = args.contains("-uitest") || args.contains("--uitest")
        let inDefaults = UserDefaults.standard.bool(forKey: "uitest")
        let inEnv = ProcessInfo.processInfo.environment["UITEST"] == "1"
        return (hasArg || inDefaults || inEnv) ? nil : contentType
    }

    // MARK: - Inits

    init(
        label: LocalizedStringKey,
        placeholder: LocalizedStringKey,
        text: Binding<String>,
        isRequired: Bool = true,
        isSecure: Bool = false,
        isMultiline: Bool = false,
        state: LumoriaInputFieldState = .default,
        assistiveText: LocalizedStringKey? = nil,
        contentType: UITextContentType? = nil,
        keyboardType: UIKeyboardType = .default
    ) {
        self.label = label
        self.placeholder = placeholder
        self._text = text
        self.isRequired = isRequired
        self.isSecure = isSecure
        self.isMultiline = isMultiline
        self.state = state
        self.assistiveText = assistiveText
        self.contentType = contentType
        self.keyboardType = keyboardType
        self.kind = .text
    }

    /// Emoji variant — a 50×50 square field whose tap opens an emoji picker.
    /// The label sits above, matching the text variant.
    init(
        label: LocalizedStringKey,
        emoji: Binding<String?>,
        isRequired: Bool = false,
        state: LumoriaInputFieldState = .default,
        assistiveText: LocalizedStringKey? = nil
    ) {
        self.label = label
        self.placeholder = ""
        self._text = .constant("")
        self.isRequired = isRequired
        self.state = state
        self.assistiveText = assistiveText
        self.kind = .emoji(emoji)
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            labelRow
            inputContainer
            if let assistive = assistiveText {
                Text(assistive)
                    .font(.caption2)
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
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.Text.primary)
            if isRequired {
                Text(verbatim: "*")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.Feedback.Danger.icon)
            }
        }
        .opacity(state == .disabled ? 0.4 : 1)
        .offset(y: isFocused ? -2 : 0)
        .animation(MotionTokens.impulse, value: isFocused)
    }

    // MARK: - Input

    @ViewBuilder
    private var inputContainer: some View {
        switch kind {
        case .text:
            textContainer
        case .emoji(let binding):
            emojiSquare(binding: binding)
        }
    }

    private var textContainer: some View {
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
                .stroke(borderColor, lineWidth: isFocused ? 2 : 1)
                .scaleEffect(isFocused ? 1.0 : 1.02)
                .animation(MotionTokens.impulse, value: isFocused)
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .sensoryFeedback(.selection, trigger: isFocused)
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
            .font(.body)
            .foregroundStyle(textColor)
            .textContentType(effectiveContentType)
            .focused($isFocused)

            if isSecure {
                revealButton
            }
        }
        .padding(.horizontal, 12)
    }

    private var multilineInput: some View {
        TextField(placeholder, text: $text, axis: .vertical)
            .lineLimit(3...)
            .font(.body)
            .foregroundStyle(textColor)
            .textContentType(effectiveContentType)
            .keyboardType(keyboardType)
            .autocapitalization(.none)
            .autocorrectionDisabled()
            .focused($isFocused)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var revealButton: some View {
        Button {
            isRevealed.toggle()
        } label: {
            Image(systemName: isRevealed ? "eye.slash" : "eye")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.Text.primary)
                .frame(width: 32, height: 32)
                .background(Color.Background.fieldFill)
                .clipShape(Circle())
        }
    }

    // MARK: - Emoji square

    private func emojiSquare(binding: Binding<String?>) -> some View {
        Button {
            showEmojiPicker = true
        } label: {
            Text(binding.wrappedValue?.isEmpty == false ? binding.wrappedValue! : "😃")
                .font(.title2)
                .opacity(binding.wrappedValue?.isEmpty == false ? 1 : 0.35)
                .frame(width: 50, height: 50)
                .background(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(borderColor, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showEmojiPicker) {
            EmojiPickerSheet(emoji: binding) { showEmojiPicker = false }
                .presentationDetents([.medium])
        }
    }

    // MARK: - Derived style

    private var cornerRadius: CGFloat { isMultiline ? 20 : 16 }

    private var backgroundColor: Color {
        switch state {
        case .default, .disabled: return Color.Background.fieldFill
        case .error:              return Color.Feedback.Danger.subtle
        case .warning:            return Color.Feedback.Warning.subtle
        }
    }

    private var borderColor: Color {
        switch state {
        case .default, .disabled: return Color.Border.hairline
        case .error:              return Color.Feedback.Danger.icon
        case .warning:            return Color.Feedback.Warning.icon
        }
    }

    private var textColor: Color {
        switch state {
        case .disabled: return Color.Text.disabled
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

// MARK: - Emoji picker sheet

private struct EmojiPickerSheet: View {
    @Binding var emoji: String?
    let onDone: () -> Void

    @State private var customInput: String = ""
    @FocusState private var customFocused: Bool

    private static let popular: [String] = [
        "✈️", "🌴", "🏖️", "🏔️", "🌅", "🎢",
        "🎵", "🎤", "🎸", "🎟️", "🎭", "🎨",
        "❤️", "⭐️", "✨", "🎉", "🥂", "🎂",
        "🏛️", "🌆", "🗺️", "📍", "📸", "🎁",
    ]

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 8),
        count: 6
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pick an emoji")
                .font(.title2.bold())
                .foregroundStyle(Color.Text.primary)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Self.popular, id: \.self) { e in
                    Button {
                        emoji = e
                        onDone()
                    } label: {
                        Text(e)
                            .font(.title)
                            .frame(width: 48, height: 48)
                            .background(
                                emoji == e
                                    ? Color.black.opacity(0.08)
                                    : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                TextField("Or type your own", text: $customInput)
                    .font(.body)
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(Color.Background.fieldFill)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .focused($customFocused)
                    .onChange(of: customInput) { _, new in
                        if let first = new.first, String(first).isSingleEmoji {
                            emoji = String(first)
                            customInput = ""
                            onDone()
                        }
                    }

                if emoji != nil {
                    Button("Clear") {
                        emoji = nil
                        onDone()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.Text.primary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 16)
        .presentationDragIndicator(.visible)
    }
}

private extension String {
    /// True if the string is a single emoji grapheme.
    var isSingleEmoji: Bool {
        count == 1 && unicodeScalars.contains(where: {
            $0.properties.isEmojiPresentation || $0.properties.isEmoji
        })
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var a = ""
    @Previewable @State var emoji: String? = nil

    return ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            LumoriaInputField(
                label: "Memory title",
                placeholder: "Name your memory",
                text: $a
            )

            HStack(alignment: .top, spacing: 16) {
                LumoriaInputField(
                    label: "Emoji",
                    emoji: $emoji,
                    isRequired: false
                )
                LumoriaInputField(
                    label: "Color",
                    placeholder: "Choose a color",
                    text: .constant("")
                )
            }
        }
        .padding(24)
    }
}
