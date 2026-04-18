//
//  MarketingSeeder.swift
//  Lumoria App
//
//  Debug-only helper for the marketing account. Tags the current user
//  with `is_marketing=true` so Amplitude dashboards can filter screenshot
//  traffic out, wipes their tickets + memories, and seeds a curated set
//  that covers every template — ready for App Store captures.
//
//  Exposed from Settings only under `#if DEBUG`, never shipped to prod.
//

#if DEBUG

import Foundation

@MainActor
enum MarketingSeeder {

    struct SeedResult {
        let ticketCount: Int
        let memoryCount: Int
    }

    static func seed(
        ticketsStore: TicketsStore,
        memoriesStore: MemoriesStore
    ) async -> SeedResult {
        // Flag the user as marketing before any create event fires, so the
        // seed-generated `Ticket Created` / `Memory Created` events all
        // carry `is_marketing=true` in user properties.
        Analytics.updateUserProperties(["is_marketing": true])

        // Wipe existing state one-by-one via the store so RLS is respected
        // and cached lists stay in sync.
        for ticket in ticketsStore.tickets {
            await ticketsStore.delete(ticket)
        }
        for memory in memoriesStore.memories {
            await memoriesStore.delete(memory)
        }

        // Seed tickets across all 8 templates.
        var created: [Ticket] = []
        for fixture in ticketFixtures() {
            if let ticket = await ticketsStore.create(
                payload: fixture.payload,
                orientation: fixture.orientation,
                memoryIds: [],
                originLocation: fixture.origin,
                destinationLocation: fixture.destination,
                styleId: nil
            ) {
                created.append(ticket)
            }
        }

        // Seed memories + attach curated groupings.
        for group in memoryFixtures() {
            guard let memory = await memoriesStore.create(
                name: group.name,
                colorFamily: group.colorFamily,
                emoji: group.emoji
            ) else { continue }

            for ticket in created where group.templateKinds.contains(ticket.kind) {
                await ticketsStore.toggleMembership(
                    ticketId: ticket.id,
                    memoryId: memory.id
                )
            }
        }

        return SeedResult(
            ticketCount: ticketsStore.tickets.count,
            memoryCount: memoriesStore.memories.count
        )
    }

    // MARK: - Ticket fixtures

    private struct TicketFixture {
        let payload: TicketPayload
        let orientation: TicketOrientation
        let origin: TicketLocation?
        let destination: TicketLocation?
    }

    private static func ticketFixtures() -> [TicketFixture] {
        // Airports
        let cdg = TicketLocation(name: "Charles de Gaulle", subtitle: "CDG",
                                  city: "Paris", country: "France", countryCode: "FR",
                                  lat: 49.0097, lng: 2.5479, kind: .airport)
        let lax = TicketLocation(name: "Los Angeles International", subtitle: "LAX",
                                  city: "Los Angeles", country: "United States", countryCode: "US",
                                  lat: 33.9416, lng: -118.4085, kind: .airport)
        let nrt = TicketLocation(name: "Narita International", subtitle: "NRT",
                                  city: "Tokyo", country: "Japan", countryCode: "JP",
                                  lat: 35.7720, lng: 140.3929, kind: .airport)
        let jfk = TicketLocation(name: "John F. Kennedy International", subtitle: "JFK",
                                  city: "New York", country: "United States", countryCode: "US",
                                  lat: 40.6413, lng: -73.7781, kind: .airport)
        let hkg = TicketLocation(name: "Hong Kong International", subtitle: "HKG",
                                  city: "Hong Kong", country: "Hong Kong", countryCode: "HK",
                                  lat: 22.3080, lng: 113.9185, kind: .airport)
        let lhr = TicketLocation(name: "London Heathrow", subtitle: "LHR",
                                  city: "London", country: "United Kingdom", countryCode: "GB",
                                  lat: 51.4700, lng: -0.4543, kind: .airport)
        let vie = TicketLocation(name: "Vienna International", subtitle: "VIE",
                                  city: "Vienna", country: "Austria", countryCode: "AT",
                                  lat: 48.1103, lng: 16.5697, kind: .airport)
        let sin = TicketLocation(name: "Singapore Changi", subtitle: "SIN",
                                  city: "Singapore", country: "Singapore", countryCode: "SG",
                                  lat: 1.3644, lng: 103.9915, kind: .airport)
        let hnd = TicketLocation(name: "Tokyo Haneda", subtitle: "HND",
                                  city: "Tokyo", country: "Japan", countryCode: "JP",
                                  lat: 35.5494, lng: 139.7798, kind: .airport)

        // Stations
        let tokyoStn = TicketLocation(name: "Tokyo Station", subtitle: nil,
                                       city: "Tokyo", country: "Japan", countryCode: "JP",
                                       lat: 35.6812, lng: 139.7671, kind: .station)
        let osakaStn = TicketLocation(name: "Shin-Osaka", subtitle: nil,
                                       city: "Osaka", country: "Japan", countryCode: "JP",
                                       lat: 34.7331, lng: 135.5002, kind: .station)
        let veniceStn = TicketLocation(name: "Venezia Santa Lucia", subtitle: nil,
                                        city: "Venice", country: "Italy", countryCode: "IT",
                                        lat: 45.4417, lng: 12.3211, kind: .station)
        let parisLyon = TicketLocation(name: "Gare de Lyon", subtitle: nil,
                                        city: "Paris", country: "France", countryCode: "FR",
                                        lat: 48.8448, lng: 2.3743, kind: .station)
        let viennaHbf = TicketLocation(name: "Wien Hauptbahnhof", subtitle: nil,
                                        city: "Vienna", country: "Austria", countryCode: "AT",
                                        lat: 48.1858, lng: 16.3764, kind: .station)
        let parisEst = TicketLocation(name: "Gare de l’Est", subtitle: nil,
                                       city: "Paris", country: "France", countryCode: "FR",
                                       lat: 48.8760, lng: 2.3590, kind: .station)

        return [
            // 1. Afterglow — CDG → LAX
            TicketFixture(
                payload: .afterglow(AfterglowTicket(
                    airline: "Air France", flightNumber: "AF 066",
                    origin: "CDG", originCity: "Paris Charles de Gaulle",
                    destination: "LAX", destinationCity: "Los Angeles",
                    date: "3 May 2026", gate: "F32", seat: "1A",
                    boardingTime: "10:40"
                )),
                orientation: .horizontal,
                origin: cdg, destination: lax
            ),
            // 2. Studio — NRT → JFK
            TicketFixture(
                payload: .studio(StudioTicket(
                    airline: "Japan Airlines", flightNumber: "JL 006",
                    cabinClass: "Business",
                    origin: "NRT", originName: "Narita International", originLocation: "Tokyo, Japan",
                    destination: "JFK", destinationName: "John F. Kennedy", destinationLocation: "New York, United States",
                    date: "8 Jun 2026", gate: "74", seat: "1K", departureTime: "11:05"
                )),
                orientation: .horizontal,
                origin: nrt, destination: jfk
            ),
            // 3. Heritage vertical — HKG → LHR
            TicketFixture(
                payload: .heritage(HeritageTicket(
                    airline: "Cathay Pacific", ticketNumber: "CX 251 · Airbus A350-1000",
                    cabinClass: "Business", cabinDetail: "The Pier",
                    origin: "HKG", originName: "Hong Kong International", originLocation: "Hong Kong",
                    destination: "LHR", destinationName: "London Heathrow", destinationLocation: "London, United Kingdom",
                    flightDuration: "13h 20m · Non-stop",
                    gate: "42", seat: "11A", boardingTime: "22:10", departureTime: "22:55",
                    date: "4 Sep", fullDate: "4 Sep 2026"
                )),
                orientation: .vertical,
                origin: hkg, destination: lhr
            ),
            // 4. Terminal — CDG → VIE
            TicketFixture(
                payload: .terminal(TerminalTicket(
                    airline: "Austrian Airlines", ticketNumber: "OS 416",
                    cabinClass: "Business",
                    origin: "CDG", originName: "Charles De Gaulle", originLocation: "Paris, France",
                    destination: "VIE", destinationName: "Vienna International", destinationLocation: "Vienna, Austria",
                    gate: "42", seat: "11A", boardingTime: "06:40", departureTime: "07:25",
                    date: "14 Sep", fullDate: "14 Sep 2026"
                )),
                orientation: .horizontal,
                origin: cdg, destination: vie
            ),
            // 5. Prism vertical — SIN → HND
            TicketFixture(
                payload: .prism(PrismTicket(
                    airline: "Singapore Airlines", ticketNumber: "SQ 012",
                    date: "16 Aug 2026",
                    origin: "SIN", originName: "Singapore Changi",
                    destination: "HND", destinationName: "Tokyo Haneda",
                    gate: "C34", seat: "11A", boardingTime: "08:40", departureTime: "09:10",
                    terminal: "T3"
                )),
                orientation: .vertical,
                origin: sin, destination: hnd
            ),
            // 6. Express — Tokyo → Osaka (Shinkansen)
            TicketFixture(
                payload: .express(ExpressTicket(
                    trainType: "Shinkansen", trainNumber: "Hikari 503",
                    cabinClass: "Green",
                    originCity: "Tokyo", originCityKanji: "東京",
                    destinationCity: "Osaka", destinationCityKanji: "大阪",
                    date: "14.03.2026",
                    departureTime: "06:33", arrivalTime: "09:10",
                    car: "7", seat: "14A", ticketNumber: "0000020394"
                )),
                orientation: .horizontal,
                origin: tokyoStn, destination: osakaStn
            ),
            // 7. Orient vertical — Venice → Paris
            TicketFixture(
                payload: .orient(OrientTicket(
                    company: "Venice Simplon Orient Express",
                    cabinClass: "Grand Suite",
                    originCity: "Venice", originStation: "Santa Lucia",
                    destinationCity: "Paris", destinationStation: "Gare de Lyon",
                    passenger: "Mlle. Dubois",
                    ticketNumber: "0093-2026-04-06",
                    date: "6 Apr 2026",
                    departureTime: "19:10",
                    carriage: "7", seat: "A"
                )),
                orientation: .vertical,
                origin: veniceStn, destination: parisLyon
            ),
            // 8. Night — Vienna → Paris
            TicketFixture(
                payload: .night(NightTicket(
                    company: "ÖBB Nightjet",
                    trainType: "EN", trainCode: "NJ 40469",
                    originCity: "Vienna", originStation: "Hauptbahnhof",
                    destinationCity: "Paris", destinationStation: "Gare de l’Est",
                    passenger: "Benjamin",
                    car: "32", berth: "Lower",
                    date: "14 Mar 2026 · 19:55",
                    ticketNumber: "NJ-2026-03-14-0032"
                )),
                orientation: .horizontal,
                origin: viennaHbf, destination: parisEst
            ),
        ]
    }

    // MARK: - Memory fixtures

    private struct MemoryFixture {
        let name: String
        let colorFamily: String
        let emoji: String?
        let templateKinds: Set<TicketTemplateKind>
    }

    private static func memoryFixtures() -> [MemoryFixture] {
        [
            MemoryFixture(
                name: "Japan 2026",
                colorFamily: "Yellow",
                emoji: "🗾",
                templateKinds: [.express, .studio, .prism]
            ),
            MemoryFixture(
                name: "Europe by rail",
                colorFamily: "Teal",
                emoji: "🚄",
                templateKinds: [.orient, .night]
            ),
            MemoryFixture(
                name: "Long-haul nights",
                colorFamily: "Purple",
                emoji: "✈️",
                templateKinds: [.afterglow, .heritage]
            ),
        ]
    }
}

#endif
