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
    var inputIdentifier: String? = nil

    private var kind: LumoriaInputFieldKind = .text

    @State private var isRevealed = false
    @FocusState private var isFocused: Bool

    // Under Maestro, swap SecureField → TextField and null contentType so
    // iOS autofill / strong-password takeover doesn't intercept keystrokes
    // (otherwise only the first character lands in the field).
    // Accepts the signal via any of: launch args (`-uitest`/`--uitest`),
    // UserDefaults (`-uitest YES`), or env var (`UITEST=1`).
    private static var isUITest: Bool {
        let args = CommandLine.arguments
        let hasArg = args.contains("-uitest") || args.contains("--uitest")
        let inDefaults = UserDefaults.standard.bool(forKey: "uitest")
        let inEnv = ProcessInfo.processInfo.environment["UITEST"] == "1"
        return hasArg || inDefaults || inEnv
    }

    private var effectiveContentType: UITextContentType? {
        Self.isUITest ? nil : contentType
    }

    private var effectiveIsSecure: Bool {
        Self.isUITest ? false : isSecure
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
        keyboardType: UIKeyboardType = .default,
        inputIdentifier: String? = nil
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
        self.inputIdentifier = inputIdentifier
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
                if effectiveIsSecure && !isRevealed {
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
            .accessibilityIdentifier(inputIdentifier ?? "")

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
        EmojiSquareField(
            binding: binding,
            backgroundColor: backgroundColor,
            borderColor: borderColor,
            cornerRadius: cornerRadius
        )
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
        default:        return Color.Text.primary
        }
    }

    private var assistiveTextColor: Color {
        switch state {
        case .error:   return Color.InputField.AssistiveText.danger
        case .warning: return Color.InputField.AssistiveText.warning
        default:       return Color.InputField.AssistiveText.default
        }
    }
}

// MARK: - Emoji square (private)

/// Routes presentation through the root `MemoryEmojiPresenter` env-object
/// so the `.floatingBottomSheet` overlay attaches to the TabView frame,
/// not this 50×50 button. Scoped to its own struct so non-emoji
/// `LumoriaInputField` callers (auth screens, ticket forms) don't need
/// the presenter in their environment.
private struct EmojiSquareField: View {
    let binding: Binding<String?>
    let backgroundColor: Color
    let borderColor: Color
    let cornerRadius: CGFloat

    @EnvironmentObject private var emojiPresenter: MemoryEmojiPresenter

    var body: some View {
        Button {
            emojiPresenter.present(
                initialEmoji: binding.wrappedValue,
                onCommit: { binding.wrappedValue = $0 }
            )
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
    }
}

// MARK: - Emoji picker sheet

struct EmojiPickerSheet: View {
    let initialEmoji: String?
    let onCommit: (String?) -> Void
    let onDismiss: () -> Void

    @State private var selection: String?
    @State private var customInput: String = ""
    @FocusState private var customFocused: Bool

    init(
        initialEmoji: String?,
        onCommit: @escaping (String?) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.initialEmoji = initialEmoji
        self.onCommit = onCommit
        self.onDismiss = onDismiss
        _selection = State(initialValue: initialEmoji)
    }

    private static let popular: [String] = [
        "✈️", "🌴", "🏖️", "🏔️", "🌅",
        "🎢", "🎵", "🎤", "🎸", "🎟️",
        "🎭", "🎨", "❤️", "⭐️", "✨",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top) {
                Text("Emoji")
                    .font(.title2.bold())
                    .foregroundStyle(Color.Text.primary)
                Spacer(minLength: 0)
                LumoriaIconButton(systemImage: "xmark", size: .medium) {
                    onDismiss()
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Pick an emoji")
                    .font(.headline)
                    .foregroundStyle(Color.Text.secondary)

                emojiGrid
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Custom emoji")
                    .font(.headline)
                    .foregroundStyle(Color.Text.secondary)

                TextField(
                    "",
                    text: $customInput,
                    prompt: Text("Type your emoji here")
                        .foregroundColor(Color.Text.tertiary)
                )
                .font(.callout)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.InputField.Background.hover)
                )
                .focused($customFocused)
                .onChange(of: customInput) { _, new in
                    // Trim to the first grapheme and keep it visible so the
                    // user can see what they picked. Earlier impl cleared
                    // the field, leaving it apparently empty after a keypress.
                    guard let first = new.first, String(first).isSingleEmoji else { return }
                    let trimmed = String(first)
                    selection = trimmed
                    if customInput != trimmed {
                        customInput = trimmed
                    }
                }
            }

            Button("Done") {
                onCommit(selection)
                onDismiss()
            }
            .buttonStyle(LumoriaButtonStyle(hierarchy: .primary, size: .large))
        }
        .padding(24)
    }

    /// Eager `Grid` (not LazyVGrid) so every emoji cell is laid out
    /// before the floating bottom sheet starts its slide-in transition.
    /// Mirrors `MemoryColorPickerSheet.colorGrid`.
    @ViewBuilder
    private var emojiGrid: some View {
        let rows = Self.popular.emojiChunked(into: 5)
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(row, id: \.self) { e in
                        emojiCell(e)
                    }
                    if row.count < 5 {
                        ForEach(0..<(5 - row.count), id: \.self) { _ in
                            Color.clear.frame(height: 64)
                        }
                    }
                }
            }
        }
    }

    private func emojiCell(_ e: String) -> some View {
        Button {
            selection = e
            customInput = ""
        } label: {
            Text(e)
                .font(.system(size: 24))
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.InputField.Background.hover)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            selection == e ? Color.Text.primary : Color.clear,
                            lineWidth: 2
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

private extension Array where Element == String {
    func emojiChunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
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
    .environmentObject(MemoryEmojiPresenter())
}
