//
//  LumoriaAirlineField.swift
//  Lumoria App
//
//  Labeled search field that autocompletes against `AirlineDatabase`.
//  Suggestions surface once the user has typed `AirlineDatabase.queryMinimumLength`
//  characters. Picking an airline sets both the `selected` binding (so
//  downstream UI can use the IATA carrier code) and the `text` binding
//  (so the airline's display name stays in the input).
//

import SwiftUI

struct LumoriaAirlineField: View {
    var label: LocalizedStringKey = "Airline"
    var placeholder: LocalizedStringKey = "Search an airline"
    var isRequired: Bool = true
    var assistiveText: LocalizedStringKey? = nil

    @Binding var text: String
    @Binding var selected: Airline?

    @State private var suggestions: [Airline] = []
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            labelRow
            inputField
            if isFocused && !suggestions.isEmpty {
                suggestionsList
            } else if let assistiveText, selected == nil {
                Text(assistiveText)
                    .font(.caption2)
                    .foregroundStyle(Color.Feedback.Neutral.text)
                    .lineSpacing(2)
                    .padding(.top, 2)
            }
        }
    }

    // MARK: Label

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
    }

    // MARK: Input

    private var inputField: some View {
        HStack(spacing: 8) {
            leadingAffordance

            TextField(placeholder, text: $text)
                .focused($isFocused)
                .font(.body)
                .foregroundStyle(Color.Text.primary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .submitLabel(.search)
                .onChange(of: text) { _, new in
                    // Typing invalidates any previous pick unless the text
                    // still matches the selected airline's name.
                    if let sel = selected, new != sel.name {
                        selected = nil
                    }
                    suggestions = AirlineDatabase.search(new)
                }

            if !text.isEmpty {
                Button {
                    text = ""
                    selected = nil
                    suggestions = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(Color.Text.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 50)
        .background(Color.Background.fieldFill)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.Border.hairline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    /// Country flag emoji once the user picks an airline, otherwise a
    /// neutral airplane glyph — matches `LumoriaAirportField`.
    @ViewBuilder
    private var leadingAffordance: some View {
        if let flag = selected?.flagEmoji {
            Text(flag)
                .font(.title3)
        } else {
            Image(systemName: "airplane")
                .font(.subheadline)
                .foregroundStyle(Color.Text.tertiary)
        }
    }

    // MARK: Suggestions

    private var suggestionsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(suggestions.enumerated()), id: \.element.id) { idx, airline in
                Button {
                    pick(airline)
                } label: {
                    HStack(alignment: .center, spacing: 12) {
                        Text(airline.flagEmoji ?? "✈️")
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(airline.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.Text.primary)
                            Text("\(airline.iata) · \(airline.country)")
                                .font(.footnote)
                                .foregroundStyle(Color.Text.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .bottom) {
                        if idx != suggestions.count - 1 {
                            Rectangle()
                                .fill(Color.Background.fieldFill)
                                .frame(height: 1)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.Background.elevated)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.Border.default, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.top, 4)
    }

    // MARK: Picking

    private func pick(_ airline: Airline) {
        selected = airline
        text = airline.name
        suggestions = []
        isFocused = false
    }
}

// MARK: - Preview

#Preview {
    struct Host: View {
        @State var text: String = ""
        @State var picked: Airline? = nil
        var body: some View {
            VStack(alignment: .leading, spacing: 24) {
                LumoriaAirlineField(
                    assistiveText: "Search by name or IATA code (3+ letters).",
                    text: $text,
                    selected: $picked
                )
                if let picked {
                    Text(verbatim: "Picked: \(picked.iata) · \(picked.name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(24)
        }
    }
    return Host()
}
