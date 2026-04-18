//
//  PrismTicketView.swift
//  Lumoria App
//
//  Horizontal boarding-pass card for the "Prism" ticket style.
//  Design: figma.com/design/1vAhPHcA6A3SRsQJkkylIU/Tickets?node-id=2-2353
//

import SwiftUI

// MARK: - Model

struct PrismTicket: Codable, Hashable {
    var airline: String             // "Airline"
    var ticketNumber: String        // "Ticket number"
    var date: String                // "16 Aug 2026"
    var origin: String              // "SIN"
    var originName: String          // "Singapore Changi"
    var destination: String         // "HND"
    var destinationName: String     // "Tokyo Haneda"
    var gate: String                // "C34"
    var seat: String                // "11A"
    var boardingTime: String        // "08:40"
    var departureTime: String       // "09:10"
    var terminal: String            // "T3"
}

// MARK: - Aurora gradient

struct PrismAurora: View {
    var imageName: String = "prism-gradient"

    var body: some View {
        Image(imageName)
            .resizable()
    }
}

// MARK: - View

struct PrismTicketView: View {
    let ticket: PrismTicket

    @Environment(\.showsLumoriaWatermark) private var showsLumoriaWatermark
    @Environment(\.ticketFillsNotchCutouts) private var fillsNotchCutouts

    private let aspectRatio: CGFloat = 455 / 260

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let s = w / 455

            let bgMask = Image("prism-bg").resizable().frame(width: w, height: h)

            ZStack(alignment: .topLeading) {
                // Aurora clipped to the notched ticket shape — notches
                // stay transparent so the parent surface shows through.
                PrismAurora()
                    .frame(width: w, height: h)
                    .mask(bgMask)

                // All overlays clipped to the same notched shape
                ZStack(alignment: .topLeading) {
                    Color.clear
                        .frame(width: w, height: h)

                    headerRow(scale: s)
                        .frame(width: w)

                    routeRow(scale: s)
                        .frame(width: w, height: 131 * s)
                        .offset(y: 58 * s)

                    footerBar(scale: s)
                        .frame(width: w, height: 49 * s)
                        .offset(y: 211 * s)
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
        .padding(.horizontal, 24 * s)
        .padding(.vertical, 16 * s)
    }

    // MARK: - Route

    private func routeRow(scale s: CGFloat) -> some View {
        HStack(spacing: 16 * s) {
            airportBlock(
                code: ticket.origin,
                name: ticket.originName,
                align: .trailing,
                scale: s
            )

            Text(verbatim: "→")
                .font(.system(size: 16 * s, weight: .regular))
                .foregroundStyle(.black.opacity(0.5))

            airportBlock(
                code: ticket.destination,
                name: ticket.destinationName,
                align: .leading,
                scale: s
            )
        }
        .padding(.horizontal, 28 * s)
    }

    private func airportBlock(
        code: String,
        name: String,
        align: HorizontalAlignment,
        scale s: CGFloat
    ) -> some View {
        VStack(alignment: align, spacing: 0) {
            Text(code)
                .font(.custom("Georgia-Bold", size: 80 * s))
                .foregroundStyle(Color(red: 10.0/255, green: 10.0/255, blue: 10.0/255).opacity(0.82))
                .lineLimit(1)
                .fixedSize()

            Text(name.uppercased())
                .font(.system(size: 8 * s, weight: .bold))
                .tracking(1.76 * s)
                .foregroundStyle(Color(red: 10.0/255, green: 10.0/255, blue: 10.0/255).opacity(0.45))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(width: 175 * s, alignment: align == .leading ? .leading : .trailing)
    }

    // MARK: - Footer

    private func footerBar(scale s: CGFloat) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 0) {
                detailCell(label: "Gate",     value: ticket.gate,          showDivider: false, scale: s)
                detailCell(label: "Seat",     value: ticket.seat,          showDivider: true,  scale: s)
                detailCell(label: "Boards",   value: ticket.boardingTime,  showDivider: true,  scale: s)
                detailCell(label: "Departs",  value: ticket.departureTime, showDivider: true,  scale: s)
                detailCell(label: "Terminal", value: ticket.terminal,      showDivider: true,  scale: s)
            }
            .frame(width: 324 * s)

            Spacer(minLength: 0)

            madeWithBadge(scale: s)
        }
        .padding(.horizontal, 16 * s)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "1A1A1A"))
    }

    private func detailCell(
        label: String,
        value: String,
        showDivider: Bool,
        scale s: CGFloat
    ) -> some View {
        HStack(spacing: 0) {
            if showDivider {
                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 1)
                    .frame(height: 27 * s)
            }

            VStack(spacing: 3 * s) {
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
            .frame(maxWidth: .infinity)
            .frame(height: 27 * s)
        }
    }

    @ViewBuilder
    private func madeWithBadge(scale s: CGFloat) -> some View {
        if showsLumoriaWatermark {
            // 6.78pt local font ÷ 17pt component font = ~0.4 scale factor.
            MadeWithLumoria(style: .white, version: .small, scale: 0.4 * s)
        }
    }
}

// MARK: - Preview

#Preview {
    PrismTicketView(ticket: PrismTicket(
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
