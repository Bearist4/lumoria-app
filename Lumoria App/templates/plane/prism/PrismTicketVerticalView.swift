//
//  PrismTicketVerticalView.swift
//  Lumoria App
//
//  Vertical boarding-pass card for the "Prism" ticket style.
//  Design: figma.com/design/1vAhPHcA6A3SRsQJkkylIU/Tickets?node-id=3-2509
//

import SwiftUI

struct PrismTicketVerticalView: View {
    let ticket: PrismTicket

    @Environment(\.ticketFillsNotchCutouts) private var fillsNotchCutouts
    @Environment(\.showsLumoriaWatermark) private var showsLumoriaWatermark

    private let aspectRatio: CGFloat = 260 / 455

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let s = w / 260

            let bgMask = Image("prism-bg-vertical").resizable().frame(width: w, height: h)

            ZStack(alignment: .top) {
                // White base inside the mask — keeps notched/cutout
                // regions opaque white instead of transparent.
                Color.white
                    .frame(width: w, height: h)
                    .mask(bgMask)

                // Aurora clipped to the notched ticket shape.
                PrismAurora(imageName: "prism-gradient-vertical")
                    .frame(width: w, height: h)
                    .mask(bgMask)

                // All overlays clipped to the same notched shape
                ZStack(alignment: .top) {
                    Color.clear
                        .frame(width: w, height: h)

                    headerRow(scale: s)
                        .frame(width: w)

                    routeStack(scale: s)
                        .frame(width: w)
                        .offset(y: 80 * s)

                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        footerBlock(scale: s)
                            .frame(width: w, height: 132 * s)
                    }
                }
                .mask(bgMask)
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: 32 * s, style: .continuous))
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    // MARK: - Header

    private func headerRow(scale s: CGFloat) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4 * s) {
                Text(ticket.airline.uppercased())
                    .font(.system(size: 8 * s, weight: .bold))
                    .tracking(1.5 * s)
                    .foregroundStyle(.black)

                Text(ticket.ticketNumber)
                    .font(.system(size: 10 * s, weight: .bold))
                    .tracking(0.5 * s)
                    .foregroundStyle(.black.opacity(0.55))
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 4 * s) {
                Text(ticket.date)
                    .font(.system(size: 10 * s, weight: .bold))
                    .tracking(0.5 * s)
                    .foregroundStyle(.black)

                Text("Boarding pass".uppercased())
                    .font(.system(size: 8 * s, weight: .bold))
                    .tracking(1.5 * s)
                    .foregroundStyle(.black.opacity(0.55))
            }
        }
        .padding(.horizontal, 16 * s)
        .padding(.top, 36 * s)
        .padding(.bottom, 16 * s)
    }

    // MARK: - Route

    private func routeStack(scale s: CGFloat) -> some View {
        VStack(alignment: .center, spacing: 4 * s) {
            // Origin — code runs 13pt past the left edge so the mask
            // clips it, but the airport name keeps 8pt of breathing room
            // from the left so it always stays fully visible.
            airportBlock(
                code: ticket.origin,
                name: ticket.originName,
                align: .leading,
                scale: s
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(verbatim: "↓")
                .font(.system(size: 16 * s, weight: .regular))
                .foregroundStyle(.black.opacity(0.5))

            // Destination — code runs 12pt past the right edge; name
            // keeps 8pt of clearance from the right.
            airportBlock(
                code: ticket.destination,
                name: ticket.destinationName,
                align: .trailing,
                scale: s
            )
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.bottom, 12 * s)
    }

    private func airportBlock(
        code: String,
        name: String,
        align: HorizontalAlignment,
        scale s: CGFloat
    ) -> some View {
        let codeOverhang: CGFloat = align == .leading ? -13 * s : 0
        let codeOverhangTrailing: CGFloat = align == .trailing ? -12 * s : 0
        let nameInset: CGFloat = 8 * s

        return VStack(alignment: align, spacing: 0) {
            Text(code)
                .font(.custom("Georgia-Bold", size: 80 * s))
                .foregroundStyle(Color(red: 10.0/255, green: 10.0/255, blue: 10.0/255).opacity(0.82))
                .lineLimit(1)
                .fixedSize()
                .padding(.leading, codeOverhang)
                .padding(.trailing, codeOverhangTrailing)

            Text(name.uppercased())
                .font(.system(size: 8 * s, weight: .bold))
                .tracking(1.76 * s)
                .foregroundStyle(Color(red: 10.0/255, green: 10.0/255, blue: 10.0/255).opacity(0.45))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.leading, align == .leading ? nameInset : 0)
                .padding(.trailing, align == .trailing ? nameInset : 0)
        }
    }

    // MARK: - Footer block

    private func footerBlock(scale s: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Dark details area — sits above the white watermark strip.
            ZStack {
                Color(hex: "1A1A1A")

                VStack(spacing: 12 * s) {
                    // Top row: Gate | Seat | Boards
                    HStack(spacing: 8 * s) {
                        detailCell(label: "Gate",   value: ticket.gate,         align: .leading,  scale: s)
                        detailCell(label: "Seat",   value: ticket.seat,         align: .center,   scale: s)
                        detailCell(label: "Boards", value: ticket.boardingTime, align: .trailing, scale: s)
                    }

                    // Bottom row: Departs | Terminal (2 cells)
                    HStack(spacing: 8 * s) {
                        detailCell(label: "Departs",  value: ticket.departureTime, align: .leading,  scale: s)
                        detailCell(label: "Terminal", value: ticket.terminal,      align: .trailing, scale: s)
                    }
                }
                .padding(.horizontal, 16 * s)
                .padding(.vertical, 12 * s)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // White watermark strip at the very bottom (masked by ticket shape).
            madeWithStrip(scale: s)
                .frame(height: 40 * s)
        }
    }

    private func detailCell(
        label: String,
        value: String,
        align: HorizontalAlignment,
        scale s: CGFloat
    ) -> some View {
        VStack(alignment: align, spacing: 3 * s) {
            Text(label.uppercased())
                .font(.system(size: 6 * s, weight: .regular))
                .tracking(1.32 * s)
                .foregroundStyle(.white.opacity(0.3))

            Text(value)
                .font(.system(size: 14 * s, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: alignment(for: align))
        .frame(height: 27 * s)
    }

    private func alignment(for h: HorizontalAlignment) -> Alignment {
        switch h {
        case .leading:  return .leading
        case .trailing: return .trailing
        default:        return .center
        }
    }

    // MARK: - Made with strip (bottom)

    @ViewBuilder
    private func madeWithStrip(scale s: CGFloat) -> some View {
        ZStack {
            Color.white
            if showsLumoriaWatermark {
                MadeWithLumoria(
                    style: .white,
                    version: .full,
                    scale: s,
                    fullWidth: true
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 40 * s)
    }
}

// MARK: - Preview

#Preview {
    PrismTicketVerticalView(ticket: PrismTicket(
        airline: "Airline",
        ticketNumber: "Ticket number",
        date: "16 Aug 2026",
        origin: "SIN",
        originName: "Singapore Changi",
        destination: "HND",
        destinationName: "Tokyo Haneda",
        gate: "C34",
        seat: "11A",
        boardingTime: "08:40",
        departureTime: "09:10",
        terminal: "T3"
    ))
    .padding(24)
    .background(Color.Background.default)
}
