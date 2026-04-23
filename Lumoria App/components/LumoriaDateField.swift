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

    @State private var showPicker = false
    @State private var draft: Date = Date()
    @FocusState private var isFocused: Bool

    init(
        label: LocalizedStringKey,
        placeholder: LocalizedStringKey = "Select a date",
        date: Binding<Date?>,
        isRequired: Bool = false,
        state: LumoriaInputFieldState = .default,
        assistiveText: LocalizedStringKey? = nil
    ) {
        self.label = label
        self.placeholder = placeholder
        self._date = date
        self.isRequired = isRequired
        self.state = state
        self.assistiveText = assistiveText
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
                .presentationDetents([.height(420)])
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
                Image(systemName: "calendar")
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

            DatePicker(
                "",
                selection: $draft,
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .labelsHidden()

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
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }

    // MARK: - Derived

    private var displayText: String? {
        guard let d = date else { return nil }
        let f = DateFormatter()
        f.dateFormat = "d MMMM yyyy"
        return f.string(from: d)
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
        case .error:   return Color(hex: "AC001A")
        case .warning: return Color(hex: "8A4500")
        default:       return Color(hex: "525252")
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

