//
//  LumoriaDateField.swift
//  Lumoria App
//
//  Labeled, nullable date input matching LumoriaInputField's visual style.
//  Tapping the field opens a compact system DatePicker in a popover-style
//  sheet; a "Clear" action lets the user reset an already-picked date.
//

import SwiftUI

struct LumoriaDateField: View {
    let label: LocalizedStringKey
    let placeholder: LocalizedStringKey
    @Binding var date: Date?

    var isRequired: Bool = false
    var state: LumoriaInputFieldState = .default
    var assistiveText: LocalizedStringKey? = nil
    /// Which `DatePicker` slots are surfaced. Defaults to `.date` so
    /// existing callers stay backwards-compatible; pass `.hourAndMinute`
    /// to repurpose the field as a time picker (placeholder + glyph
    /// swap to a clock).
    var displayedComponents: DatePicker.Components = .date

    @State private var showPicker = false
    @State private var draft: Date = Date()
    @FocusState private var isFocused: Bool

    init(
        label: LocalizedStringKey,
        placeholder: LocalizedStringKey = "Select a date",
        date: Binding<Date?>,
        isRequired: Bool = false,
        state: LumoriaInputFieldState = .default,
        assistiveText: LocalizedStringKey? = nil,
        displayedComponents: DatePicker.Components = .date
    ) {
        self.label = label
        self.placeholder = placeholder
        self._date = date
        self.isRequired = isRequired
        self.state = state
        self.assistiveText = assistiveText
        self.displayedComponents = displayedComponents
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            labelRow
            fieldChip
            if let assistive = assistiveText {
                Text(assistive)
                    .font(.caption2)
                    .foregroundStyle(assistiveTextColor)
                    .lineSpacing(2)
            }
        }
        .disabled(state == .disabled)
        .sheet(isPresented: $showPicker) {
            pickerSheet
                // Time picker (wheel) is short and well-served by a
                // fixed half-screen detent; the graphical calendar
                // needs more room and a resize affordance — `.medium`
                // / `.large` lets the user expand and respects the
                // home-indicator safe area natively, which the
                // earlier fixed `.height(420)` did not.
                .presentationDetents(
                    displayedComponents == .hourAndMinute
                        ? [.height(360)]
                        : [.medium, .large]
                )
                .presentationDragIndicator(.visible)
        }
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
    }

    // MARK: - Field chip

    private var fieldChip: some View {
        Button {
            draft = date ?? Date()
            showPicker = true
        } label: {
            HStack(spacing: 8) {
                Group {
                    if let text = displayText {
                        Text(text)
                    } else {
                        Text(placeholder)
                    }
                }
                .font(.body)
                .foregroundStyle(textColor)
                Spacer(minLength: 0)
                Image(systemName: glyph)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.Text.secondary)
            }
            .padding(.horizontal, 12)
            .frame(height: 50)
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Picker sheet

    private var pickerSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(label)
                .font(.title2.bold())
                .foregroundStyle(Color.Text.primary)

            // Style swap can't happen via a runtime ternary — `wheel`
            // and `graphical` are distinct generic types — so branch
            // the DatePicker itself. Wrapped in a ScrollView for the
            // graphical case so an extra-tall calendar (e.g. month
            // with 6 visible weeks) can scroll instead of pushing
            // the action row off the bottom of a `.medium` detent.
            Group {
                if displayedComponents == .hourAndMinute {
                    DatePicker("", selection: $draft, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                } else {
                    ScrollView {
                        DatePicker("", selection: $draft, displayedComponents: displayedComponents)
                            .datePickerStyle(.graphical)
                    }
                }
            }
            .labelsHidden()

            // `safeAreaInset` would also work, but the action row is
            // simple enough that pinning it via Spacer keeps the
            // sheet's layout legible. The outer .bottom padding +
            // SwiftUI's automatic sheet safe-area inset keeps the
            // buttons above the home indicator at any detent.
            actionRow
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 16)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var actionRow: some View {
        HStack {
            if date != nil {
                Button(role: .destructive) {
                    date = nil
                    showPicker = false
                } label: {
                    Text("Clear")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.Feedback.Danger.text)
                .font(.body.weight(.semibold))
            }

            Spacer(minLength: 0)

            Button {
                date = draft
                showPicker = false
            } label: {
                Text("Done")
            }
            .lumoriaButtonStyle(.primary, size: .medium)
        }
    }

    // MARK: - Derived

    private var displayText: String? {
        guard let d = date else { return nil }
        let f = DateFormatter()
        if displayedComponents == .hourAndMinute {
            f.dateFormat = "HH:mm"
        } else {
            f.dateFormat = "d MMMM yyyy"
        }
        return f.string(from: d)
    }

    /// Glyph paired with the field. Calendar icon for date pickers,
    /// clock for time pickers — keeps the affordance obvious without
    /// the user having to read the label.
    private var glyph: String {
        displayedComponents == .hourAndMinute ? "clock" : "calendar"
    }

    private var textColor: Color {
        if state == .disabled { return Color.Text.disabled }
        return date == nil ? Color.Text.tertiary : Color.Text.primary
    }

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

    private var assistiveTextColor: Color {
        switch state {
        case .error:   return Color.InputField.AssistiveText.danger
        case .warning: return Color.InputField.AssistiveText.warning
        default:       return Color.InputField.AssistiveText.default
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var start: Date? = nil
    @Previewable @State var end: Date? = Date()

    return VStack(alignment: .leading, spacing: 20) {
        HStack(spacing: 16) {
            LumoriaDateField(label: "Start date", date: $start)
            LumoriaDateField(label: "End date",   date: $end)
        }

        LumoriaDateField(
            label: "Start date",
            date: $start,
            state: .warning,
            assistiveText: "Unsaved edit."
        )
    }
    .padding(24)
}

