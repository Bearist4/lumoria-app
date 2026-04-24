//
//  LumoriaRouteDropdown.swift
//  Lumoria App
//
//  Dropdown variant specialised for picking a transit route. The
//  field renders a compressed summary of the currently-picked
//  route (first two `LineHandle`s + "+N" counter when the route
//  has more legs). The expanded list renders each alternative as
//  a two-line row: a `{stops} · {transfers}` meta line on top,
//  then the full chain of `LineHandle`s separated by arrows.
//
//  Design:
//   • Dropdown shell : figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=497-3798
//   • Route variant  : figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=102-2883
//   • Collapsed state: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1877-50409
//

import SwiftUI

/// Height cap for the expanded list before it starts scrolling —
/// roughly four route rows before the list becomes a scroller.
private let lumoriaRouteDropdownListMaxHeight: CGFloat = 420

struct LumoriaRouteDropdown: View {

    let label: LocalizedStringKey
    let placeholder: LocalizedStringKey
    var isRequired: Bool = true
    var assistiveText: LocalizedStringKey? = nil
    var state: LumoriaInputFieldState = .default

    /// All candidate routes to offer. Each inner array is an
    /// ordered list of legs, one per contiguous line segment.
    let routes: [[TransitLeg]]

    /// Index into `routes`. `nil` before the user has picked a
    /// route; the field shows `placeholder` while this is nil.
    @Binding var selectedIndex: Int?

    @State private var isOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            labelRow
            field
                .overlay(alignment: .topLeading) {
                    if isOpen {
                        list
                            .frame(maxWidth: .infinity)
                            .offset(y: 54)
                    }
                }
            if let assistiveText, !isOpen {
                assistive(assistiveText)
            }
        }
        // Raise the whole field above sibling form rows while open
        // so the list draws on top of whatever sits beneath (the
        // Ticket Details section etc.). Same rationale as
        // LumoriaDropdown.
        .zIndex(isOpen ? 1 : 0)
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
                    .foregroundStyle(Color("Colors/Red/400"))
            }
        }
    }

    // MARK: - Field (collapsed)

    private var field: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { isOpen.toggle() }
        } label: {
            HStack(spacing: 8) {
                Group {
                    if let idx = selectedIndex, routes.indices.contains(idx) {
                        compactRoute(routes[idx])
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(placeholder)
                            .foregroundStyle(Color.Text.tertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                    .font(.footnote)
                    .foregroundStyle(Color.Text.secondary)
            }
            .font(.body)
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

    /// Collapsed-state preview — first two line handles + "→ +N"
    /// counter when the route has more legs than fit.
    private func compactRoute(_ route: [TransitLeg]) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(route.prefix(2).enumerated()), id: \.offset) { idx, leg in
                LineHandle(line: leg.line)
                if idx < min(route.count, 2) - 1 {
                    chainArrow
                }
            }
            if route.count > 2 {
                chainArrow
                Text("+\(route.count - 2)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.Text.secondary)
            }
        }
    }

    private var chainArrow: some View {
        Image(systemName: "arrow.right")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.Text.tertiary)
    }

    // MARK: - List (expanded)

    private var list: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(routes.enumerated()), id: \.offset) { idx, route in
                    Button {
                        selectedIndex = idx
                        withAnimation(.easeInOut(duration: 0.15)) { isOpen = false }
                    } label: {
                        row(for: route, isLast: idx == routes.count - 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxHeight: lumoriaRouteDropdownListMaxHeight)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.Background.elevated)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.Border.default, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.top, 4)
    }

    private func row(for route: [TransitLeg], isLast: Bool) -> some View {
        let isSelected = selectedIndex.map { $0 == routes.firstIndex(where: { $0 == route }) } ?? false
        return VStack(alignment: .leading, spacing: 8) {
            // Meta row — stops · transfers with icons.
            HStack(spacing: 12) {
                metaItem(
                    icon: "figure.walk",
                    text: stopsLabel(totalStops(route))
                )
                metaItem(
                    icon: "arrow.triangle.branch",
                    text: transfersLabel(for: route)
                )
                Spacer(minLength: 0)
            }

            // Chain of line handles separated by arrows. Horizontal
            // scroll if it overflows — 5+ transfers exists on some
            // Tokyo / London journeys.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(route.enumerated()), id: \.offset) { idx, leg in
                        LineHandle(line: leg.line)
                        if idx < route.count - 1 {
                            chainArrow
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background(
            isSelected
                ? Color.Background.subtle.clipShape(RoundedRectangle(cornerRadius: 8))
                : nil
        )
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(Color.Background.fieldFill)
                    .frame(height: 1)
            }
        }
    }

    private func metaItem(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(Color.Text.secondary)
            Text(text)
                .font(.caption)
                .foregroundStyle(Color.Text.secondary)
        }
    }

    // MARK: - Derived

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

    private func totalStops(_ route: [TransitLeg]) -> Int {
        route.reduce(0) { $0 + $1.stopsCount }
    }

    private func stopsLabel(_ n: Int) -> String {
        n == 1
            ? String(localized: "1 stop")
            : String(localized: "\(n) stops")
    }

    private func transfersLabel(for route: [TransitLeg]) -> String {
        let transfers = max(0, route.count - 1)
        switch transfers {
        case 0:  return String(localized: "Direct")
        case 1:  return String(localized: "1 transfer")
        default: return String(localized: "\(transfers) transfers")
        }
    }

    // MARK: - Assistive text

    private func assistive(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(Color.Feedback.Neutral.text)
            .lineSpacing(2)
            .padding(.top, 2)
    }
}
