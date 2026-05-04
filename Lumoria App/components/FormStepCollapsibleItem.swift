//
//  FormStepCollapsibleItem.swift
//  Lumoria App
//
//  Collapsible group used on the new-ticket form step. Each item wraps a
//  cluster of fields that maps to one of the categories already surfaced
//  on `TemplateDetailsSheet` (`TicketTemplateKind.requirements`). The
//  status icon flips to a green checkmark once the cluster's required
//  fields are filled.
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=2095-89008
//

import SwiftUI

struct FormStepCollapsibleItem<Content: View>: View {

    let title: String
    let isComplete: Bool
    @Binding var isExpanded: Bool
    /// When true the leading 44pt slot renders the purple premium
    /// badge instead of the standard circle / checkmark. Used by the
    /// style step to flag color collapsibles that are pro-only.
    var proBadge: Bool = false
    /// When false the leading status slot (circle / checkmark) is
    /// hidden and the title sits flush with the card padding. The
    /// style step uses this — there's nothing to "complete" on a
    /// theme picker, so the empty circle just adds visual noise.
    /// `proBadge` still renders when set, regardless of this flag.
    var showsStatusIcon: Bool = true
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if isExpanded {
                divider
                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, isExpanded ? 16 : 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color("Colors/Opacity/Black/inverse/5"))
        )
        // Lift expanded card above siblings so dropdown overlays inside
        // its content (e.g. LumoriaDropdown's floating list) aren't drawn
        // under the next collapsible. Skip `.clipShape` — it would clip
        // those overlays at the rounded card edge; padding keeps inline
        // content inside the corners on its own.
        .zIndex(isExpanded ? 1 : 0)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: isExpanded)
    }

    // MARK: - Header

    private var header: some View {
        Button {
            isExpanded.toggle()
        } label: {
            HStack(spacing: 0) {
                if showsStatusIcon || proBadge {
                    statusIcon
                        .frame(width: 44, height: 44)
                }

                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.Text.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.down")
                    .font(.body)
                    .foregroundStyle(Color.Text.primary)
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var statusIcon: some View {
        if proBadge {
            // 24pt purple disc with the SF "crown" glyph — matches the
            // premium badge used elsewhere in the funnel chrome.
            ZStack {
                Circle()
                    .fill(Color("Colors/Purple/400"))
                    .frame(width: 24, height: 24)
                Image(systemName: "crown.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
            }
        } else if isComplete {
            Image(systemName: "checkmark.circle.fill")
                .font(.body)
                .foregroundStyle(Color.Feedback.Success.icon)
        } else {
            Image(systemName: "circle")
                .font(.body)
                .foregroundStyle(Color("Colors/Opacity/Black/inverse/50"))
        }
    }

    // MARK: - Divider

    private var divider: some View {
        Rectangle()
            .fill(Color.Border.hairline)
            .frame(height: 1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
    }
}

// MARK: - Preview

#Preview("Collapsible items") {
    struct Wrapper: View {
        @State private var first = false
        @State private var second = true
        @State private var third = false

        var body: some View {
            VStack(spacing: 8) {
                FormStepCollapsibleItem(
                    title: "Airport codes",
                    isComplete: true,
                    isExpanded: $first
                ) {
                    Text("Hidden form fields…")
                        .font(.body)
                        .foregroundStyle(Color.Text.secondary)
                }

                FormStepCollapsibleItem(
                    title: "Date & time of travel",
                    isComplete: false,
                    isExpanded: $second
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Date picker would live here")
                        Text("Time picker would live here")
                    }
                    .font(.body)
                    .foregroundStyle(Color.Text.secondary)
                }

                FormStepCollapsibleItem(
                    title: "Flight details",
                    isComplete: false,
                    isExpanded: $third
                ) {
                    Text("Hidden form fields…")
                        .font(.body)
                        .foregroundStyle(Color.Text.secondary)
                }
            }
            .padding(16)
            .background(Color.Background.default)
        }
    }
    return Wrapper()
}
