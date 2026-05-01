//
//  PKPassImporter.swift
//  Lumoria App
//
//  Parses Apple Wallet `.pkpass` archives into Lumoria form inputs.
//  Uses PKPass + an inline pass.json reader: PassKit's public surface
//  doesn't expose structured field collections or transitType, so we
//  unzip pass.json ourselves and walk the field arrays.
//

import Compression
import Foundation
import PassKit

enum PKPassImporter {

    // MARK: - Entry point

    /// Parses `.pkpass` archive `data` and projects it onto the form
    /// matching `template`. Throws when the file isn't a pass, isn't
    /// a boarding pass, or transit-type doesn't match the selected
    /// template category.
    static func parse(
        data: Data,
        template: TicketTemplateKind
    ) throws -> ImportResult {
        NSLog("[PKPassImporter] parse start — %ld bytes, template=%@",
              data.count, template.rawValue)

        // PKPass validates the archive's signature and structure.
        // If this init throws the file isn't a valid pass at all.
        let pass: PKPass
        do {
            pass = try PKPass(data: data)
        } catch {
            NSLog("[PKPassImporter] PKPass init failed: %@", error as NSError)
            throw ImportError.unreadable
        }

        #if DEBUG
        NSLog("[PKPassImporter] PKPass: org=%@ serial=%@ relevantDate=%@ desc=%@",
              pass.organizationName, pass.serialNumber,
              String(describing: pass.relevantDate),
              pass.localizedDescription)
        #endif

        // Pull pass.json out of the ZIP — PassKit doesn't expose the
        // structured field arrays publicly, so we parse the JSON blob
        // ourselves to access transitType and every field.
        guard let json = try? PassJSONReader.passJSON(in: data) else {
            NSLog("[PKPassImporter] pass.json extraction failed")
            throw ImportError.unreadable
        }

        #if DEBUG
        if let pretty = try? JSONSerialization.data(
            withJSONObject: json, options: [.prettyPrinted, .sortedKeys]
        ), let s = String(data: pretty, encoding: .utf8) {
            NSLog("[PKPassImporter] pass.json:\n%@", s)
        }
        #endif

        guard let boardingPass = json["boardingPass"] as? [String: Any] else {
            NSLog("[PKPassImporter] no boardingPass key in pass.json")
            throw ImportError.notBoardingPass
        }

        let transit = TransitKind(rawString: boardingPass["transitType"] as? String)
        let expectedKind = transitKind(for: template)
        NSLog("[PKPassImporter] transitType=%@ expected=%@",
              transit.rawValue, expectedKind.rawValue)

        // Rail templates accept rail/other; air templates accept air only.
        let compatible = (expectedKind == .air && transit == .air)
                      || (expectedKind == .train && transit != .air)
        guard compatible else {
            NSLog("[PKPassImporter] transit-type mismatch (detected=%@ expected=%@)",
                  transit.rawValue, expectedKind.rawValue)
            throw ImportError.kindMismatch(expected: template, detected: transit)
        }

        let fields = Self.collectFields(from: boardingPass)
        #if DEBUG
        for (key, field) in fields {
            NSLog("[PKPassImporter] field: key=%@ label=%@ value=%@",
                  key, field.label ?? "<nil>", field.value)
        }
        #endif

        switch expectedKind {
        case .air:
            let input = buildFlight(pass: pass, json: json, fields: fields)
            #if DEBUG
            NSLog("""
                [PKPassImporter] flight → airline=%@ flightNumber=%@ \
                originCode=%@ originName=%@ destCode=%@ destName=%@ \
                gate=%@ seat=%@ terminal=%@ departureDate=%@
                """,
                input.airline, input.flightNumber,
                input.originCode, input.originName,
                input.destinationCode, input.destinationName,
                input.gate, input.seat, input.terminal,
                String(describing: input.departureDate))
            #endif
            return .flight(input)
        case .train, .other:
            let input = buildTrain(pass: pass, json: json, fields: fields)
            #if DEBUG
            NSLog("""
                [PKPassImporter] train → company=%@ trainType=%@ trainNumber=%@ \
                originCity=%@ destCity=%@ car=%@ seat=%@ date=%@
                """,
                input.company, input.trainType, input.trainNumber,
                input.originCity, input.destinationCity,
                input.car, input.seat,
                String(describing: input.date))
            #endif
            return .train(input)
        }
    }

    // MARK: - Transit mapping

    private static func transitKind(for template: TicketTemplateKind) -> TransitKind {
        switch template {
        case .afterglow, .studio, .terminal, .heritage, .prism: return .air
        case .express, .orient, .night, .post, .glow:           return .train
        // Concert templates have no PKPass wallet flow, but the switch
        // must be exhaustive. Treat them as `.other` — the caller's
        // compatibility gate (`expectedKind == .train && transit != .air`)
        // would let an "other" pass slip through, so callers should
        // avoid invoking the importer for concert templates. In
        // practice the wallet entry point never routes here.
        case .concert:                                              return .other
        // Eurovision tickets are created via the in-app form (no
        // PKPass), so the same `.other` bypass applies — the wallet
        // entry point never routes here.
        case .eurovision:                                           return .other
        // Public-transport passes (signal / sign / infoscreen) aren't
        // in the PKPass wallet ecosystem either; same `.other` bypass
        // applies.
        case .underground, .sign, .infoscreen, .grid:               return .other
        }
    }

    // MARK: - Field collection

    /// Flattens every field array on the boarding pass (header / primary
    /// / secondary / auxiliary / back) into a single dictionary keyed by
    /// the field's `key`. pass.json guarantees keys are unique within a
    /// pass, so the last-write-wins semantics here are safe.
    private static func collectFields(from bp: [String: Any]) -> [String: PassField] {
        var out: [String: PassField] = [:]
        for section in ["headerFields", "primaryFields",
                        "secondaryFields", "auxiliaryFields", "backFields"] {
            guard let arr = bp[section] as? [[String: Any]] else { continue }
            for dict in arr {
                guard let key = dict["key"] as? String else { continue }
                out[key] = PassField(
                    key: key,
                    label: dict["label"] as? String,
                    value: stringValue(dict["value"])
                )
            }
        }
        return out
    }

    /// Matches a field against `aliases` in priority order. Tries the
    /// field's `key` first, then its `label` (with a trailing `_label`
    /// suffix stripped — SNCF and a few other carriers use generic
    /// keys like `p1`/`p2` and put the semantic tag in the label,
    /// e.g. `label: "origin_label"`). Alias order wins so narrow
    /// aliases beat broad ones regardless of dict ordering.
    private static func lookup(
        _ fields: [String: PassField],
        aliases: [String]
    ) -> PassField? {
        let keyed = Dictionary(
            fields.map { (normalize($0.key), $0.value) },
            uniquingKeysWith: { first, _ in first }
        )
        let normalizedAliases = aliases.map { normalize($0) }
        for alias in normalizedAliases {
            if let field = keyed[alias] { return field }
        }
        for alias in normalizedAliases {
            for field in fields.values {
                guard let label = field.label else { continue }
                if normalizeLabel(label) == alias { return field }
            }
        }
        return nil
    }

    /// Lowercases and strips every non-alphanumeric character. This
    /// collapses "Flight No.", "flight_number", "flight-number", and
    /// "FlightNumber" into the same token so alias matching doesn't
    /// need to carry every punctuation variant.
    private static func normalize(_ s: String) -> String {
        s.unicodeScalars.reduce(into: "") { out, scalar in
            if CharacterSet.alphanumerics.contains(scalar) {
                out.append(Character(scalar).lowercased())
            }
        }
    }

    /// Normalizes a pass field `label`. SNCF passes tag fields with
    /// a localization key like `origin_label`; strip that suffix so
    /// aliases compare cleanly.
    private static func normalizeLabel(_ s: String) -> String {
        var out = normalize(s)
        if out.hasSuffix("label") { out = String(out.dropLast("label".count)) }
        return out
    }

    private static func stringValue(_ raw: Any?) -> String {
        if let s = raw as? String { return s }
        if let n = raw as? NSNumber { return n.stringValue }
        return ""
    }

    // MARK: - Flight mapping

    private static func buildFlight(
        pass: PKPass,
        json: [String: Any],
        fields: [String: PassField]
    ) -> FlightFormInput {
        var input = FlightFormInput()

        let organization = pass.organizationName
        input.airline = organization
        if let airline = matchAirline(organization) {
            input.selectedAirline = airline
        }

        // Flight number: prefer a dedicated field, fall back to the
        // pass `description` which many carriers format as "XX 1234".
        if let flight = lookup(fields, aliases: [
            "flightNumber", "flight-number", "flight", "flightno",
            "flightNo", "flight-no", "number",
        ])?.value, !flight.isEmpty {
            input.flightNumber = flight
            input.flightNumberDigits = digitsStripping(
                airlineIATA: input.selectedAirline?.iata, from: flight
            )
        } else if let guess = flightNumber(inDescription: pass.localizedDescription) {
            input.flightNumber = guess
            input.flightNumberDigits = digitsStripping(
                airlineIATA: input.selectedAirline?.iata, from: guess
            )
        }

        // Origin / destination — codes first, city labels second.
        // `departure` / `arrival` are excluded — carriers sometimes use
        // those keys for HH:mm times, which would mis-assign a time
        // string as the airport code.
        let originField = lookup(fields, aliases: [
            "origin", "from", "originAirportCode", "depart-iata",
            "departAirport", "fromAirport", "originAirport",
        ])
        let destField = lookup(fields, aliases: [
            "destination", "to", "destinationAirportCode", "arrive-iata",
            "arriveAirport", "toAirport", "destinationAirport",
        ])

        if let code = iataCode(in: originField) {
            input.originCode = code
            input.originName = originField?.label ?? ""
            if let airport = airport(forIATA: code) {
                if input.originName.isEmpty { input.originName = airport.name }
                input.originLocation = "\(airport.city), \(airport.country)"
                input.originAirport = ticketLocation(from: airport)
            }
        }
        if let code = iataCode(in: destField) {
            input.destinationCode = code
            input.destinationName = destField?.label ?? ""
            if let airport = airport(forIATA: code) {
                if input.destinationName.isEmpty { input.destinationName = airport.name }
                input.destinationLocation = "\(airport.city), \(airport.country)"
                input.destinationAirport = ticketLocation(from: airport)
            }
        }

        input.gate = lookup(fields, aliases: [
            "gate", "gateNumber", "gate-number", "depart-gate", "departureGate",
        ])?.value ?? ""
        input.seat = lookup(fields, aliases: [
            "seat", "seatNumber", "seat-number",
        ])?.value ?? ""
        input.terminal = lookup(fields, aliases: [
            "terminal", "depart-terminal", "departureTerminal", "terminalNumber",
        ])?.value ?? ""

        // Dates / times. relevantDate is the canonical Apple field;
        // some airlines also duplicate it into a string field.
        let departure = pass.relevantDate
            ?? parseDate(lookup(fields, aliases: [
                "departure-time", "departureTime",
            ])?.value)
        if let departure {
            input.departureDate = departure
            input.departureTime = departure
        }

        return input
    }

    // MARK: - Train mapping

    private static func buildTrain(
        pass: PKPass,
        json: [String: Any],
        fields: [String: PassField]
    ) -> TrainFormInput {
        var input = TrainFormInput()

        let org = pass.organizationName
        input.company = org
        // `product` is intentionally excluded — carriers often stuff
        // ticket class + reservation status in there (e.g. "Reservierung
        // Comfort Class"), which belongs in cabinClass, not trainType.
        input.trainType = lookup(fields, aliases: [
            "trainType", "train-type", "service", "category",
        ])?.value ?? ""
        input.trainNumber = lookup(fields, aliases: [
            "trainNumber", "train-number", "trainNo", "train",
        ])?.value ?? extractTrainNumber(from: pass.localizedDescription)

        // `departure` / `arrival` are excluded here — some carriers use
        // those keys for HH:mm times rather than stations, so matching
        // on them mis-assigned "Abfahrt" (German "Departure") as city.
        let originField = lookup(fields, aliases: [
            "origin", "from", "originStation", "fromStation",
            "originCity", "fromCity",
        ])
        let destField = lookup(fields, aliases: [
            "destination", "to", "destinationStation", "toStation",
            "destinationCity", "toCity",
        ])

        // Value is the place name on every carrier we've seen; label
        // is the localized caption ("Von" / "From" / "Départ" / …).
        input.originCity = originField?.value ?? ""
        input.originStation = originField?.value ?? ""
        input.destinationCity = destField?.value ?? ""
        input.destinationStation = destField?.value ?? ""

        // Express-only kanji suggestions when the Latin city is in our
        // translator's table. Safe for non-Japanese routes — unknown
        // cities return nil and leave the slot empty for the user.
        input.originCityKanji = CityNameTranslator.kanji(for: input.originCity) ?? ""
        input.destinationCityKanji = CityNameTranslator.kanji(for: input.destinationCity) ?? ""

        input.cabinClass = lookup(fields, aliases: [
            "cabinClass", "class", "fareClass", "comfort", "product",
        ])?.value ?? ""

        input.car = lookup(fields, aliases: [
            "car", "coach", "voiture", "wagen", "wagon",
            "carriage", "carNumber", "wagenNummer", "wagonNumber",
        ])?.value ?? ""
        input.seat = lookup(fields, aliases: [
            "seat", "seatNumber", "seat-number", "sitz", "sitzNummer",
            "place",
        ])?.value ?? ""
        input.ticketNumber = pass.serialNumber

        let departure = pass.relevantDate
            ?? parseDate(lookup(fields, aliases: [
                "departure-time", "departureTime", "departure",
            ])?.value)
        if let departure {
            input.date = departure
            input.departureTime = departure
            // Arrival comes in two flavors across carriers: a full
            // ISO-8601 timestamp (SNCF "2025-02-10T13:28+01:00") or a
            // bare HH:mm clock (Westbahn "16:44"). Try ISO first, fall
            // back to combining HH:mm with the departure day.
            if let arrivalStr = lookup(fields, aliases: [
                "arrival-time", "arrivalTime", "arrival", "ankunft",
            ])?.value {
                if let iso = parseDate(arrivalStr) {
                    input.arrivalTime = iso
                } else if let clock = combineDate(
                    departure, withTimeString: arrivalStr
                ) {
                    input.arrivalTime = clock
                }
            }
        }

        // SNCF-style passes tag their train info with a generic key
        // (`a2`) and stash the train type in `label` ("TGV INOUI") and
        // the number in `value` ("N° 8868"). Scan for the `N° \d+`
        // pattern as a last resort so we still populate both fields.
        if input.trainNumber.isEmpty || input.trainType.isEmpty {
            for field in fields.values {
                guard let match = trainNoHeuristic.firstMatch(
                    in: field.value,
                    range: NSRange(field.value.startIndex..., in: field.value)
                ),
                    let numRange = Range(match.range(at: 1), in: field.value)
                else { continue }
                if input.trainNumber.isEmpty {
                    input.trainNumber = String(field.value[numRange])
                }
                if input.trainType.isEmpty,
                   let label = field.label,
                   !label.isEmpty,
                   !label.lowercased().hasSuffix("_label") {
                    input.trainType = label
                }
                break
            }
        }

        return input
    }

    /// `N° 8868`, `No. 8868`, `# 1234` → captures the digits. SNCF,
    /// Deutsche Bahn, and Trenitalia all ship train numbers with one
    /// of these prefixes.
    private static let trainNoHeuristic = try! NSRegularExpression(
        pattern: #"(?:N°|No\.?|#|Nr\.?)\s*(\d{2,5})"#,
        options: [.caseInsensitive]
    )

    // MARK: - Helpers

    /// Parses `HH:mm` (or `H:mm`) into a wall-clock Date on the same
    /// calendar day as `anchor`. Returns nil for anything else.
    private static func combineDate(_ anchor: Date, withTimeString s: String) -> Date? {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0..<24).contains(hour),
              (0..<60).contains(minute) else { return nil }
        var comps = Calendar.current.dateComponents(
            [.year, .month, .day],
            from: anchor
        )
        comps.hour = hour
        comps.minute = minute
        return Calendar.current.date(from: comps)
    }

    private static func extractDigits(_ s: String) -> String {
        String(s.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) })
    }

    /// Pulls the numeric portion of a flight designator while respecting
    /// carrier codes that themselves contain a digit (IATA codes like
    /// `V7`, `6E`, `B6`). When the carrier is known and the value
    /// starts with its IATA, strip that prefix before collecting
    /// digits — otherwise "V72271" would yield "72271" instead of "2271".
    private static func digitsStripping(
        airlineIATA: String?,
        from flight: String
    ) -> String {
        let trimmed = flight.trimmingCharacters(in: .whitespaces)
        if let iata = airlineIATA, !iata.isEmpty,
           trimmed.uppercased().hasPrefix(iata.uppercased()) {
            let stripped = trimmed.dropFirst(iata.count)
            return extractDigits(String(stripped))
        }
        return extractDigits(trimmed)
    }

    private static let flightNumberRegex = try! NSRegularExpression(
        pattern: #"\b([A-Z]{2,3})\s?(\d{1,4}[A-Z]?)\b"#
    )

    private static func flightNumber(inDescription desc: String) -> String? {
        let range = NSRange(desc.startIndex..., in: desc)
        guard let match = flightNumberRegex.firstMatch(in: desc, range: range),
              let full = Range(match.range, in: desc) else { return nil }
        return String(desc[full])
    }

    private static func extractTrainNumber(from desc: String) -> String {
        flightNumber(inDescription: desc) ?? ""
    }

    /// Pulls the first 3-letter IATA-looking token out of a field's
    /// value or label. Falls back to an empty string.
    private static func iataCode(in field: PassField?) -> String? {
        guard let field else { return nil }
        if let code = firstIATAToken(in: field.value) { return code }
        if let label = field.label, let code = firstIATAToken(in: label) { return code }
        return nil
    }

    private static let iataRegex = try! NSRegularExpression(
        pattern: #"\b([A-Z]{3})\b"#
    )

    private static func firstIATAToken(in s: String) -> String? {
        let range = NSRange(s.startIndex..., in: s)
        guard let match = iataRegex.firstMatch(in: s, range: range),
              let captured = Range(match.range(at: 1), in: s) else { return nil }
        let token = String(s[captured])
        return token
    }

    private static func airport(forIATA iata: String) -> Airport? {
        AirportDatabase.seed.first { $0.iata == iata.uppercased() }
    }

    private static func ticketLocation(from airport: Airport) -> TicketLocation {
        TicketLocation(
            name: airport.name,
            subtitle: airport.iata,
            city: airport.city,
            country: airport.country,
            countryCode: airport.countryCode,
            lat: airport.lat,
            lng: airport.lng,
            kind: .airport
        )
    }

    private static func matchAirline(_ org: String) -> Airline? {
        let lower = org.lowercased()
        return AirlineDatabase.seed.first { airline in
            lower.contains(airline.name.lowercased())
        }
    }

    private static let isoFormatters: [ISO8601DateFormatter] = {
        let a = ISO8601DateFormatter()
        let b = ISO8601DateFormatter()
        b.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return [a, b]
    }()

    /// Fallback formatters for carriers that skip seconds in the
    /// timestamp (SNCF: `2025-02-10T13:28+01:00`). `en_US_POSIX` keeps
    /// parsing stable across user locales.
    private static let lenientFormatters: [DateFormatter] = {
        let patterns = [
            "yyyy-MM-dd'T'HH:mmXXXXX",
            "yyyy-MM-dd'T'HH:mmZ",
            "yyyy-MM-dd'T'HH:mm",
            "yyyy-MM-dd HH:mm",
        ]
        return patterns.map { pattern in
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = pattern
            return f
        }
    }()

    private static func parseDate(_ s: String?) -> Date? {
        guard let s, !s.isEmpty else { return nil }
        for f in isoFormatters {
            if let d = f.date(from: s) { return d }
        }
        for f in lenientFormatters {
            if let d = f.date(from: s) { return d }
        }
        return nil
    }
}

// MARK: - Pass field

private struct PassField {
    let key: String
    let label: String?
    let value: String
}

// MARK: - Transit mapping from pass.json string

private extension TransitKind {
    init(rawString: String?) {
        switch rawString {
        case "PKTransitTypeAir":     self = .air
        case "PKTransitTypeTrain":   self = .train
        case "PKTransitTypeBus",
             "PKTransitTypeBoat",
             "PKTransitTypeGeneric",
             .none:
            self = .other
        default:
            self = .other
        }
    }
}

// MARK: - Minimal pass.json reader
//
// Reads pass.json straight out of a .pkpass archive. PassKit doesn't
// expose the structured field arrays publicly (localizedValue is the
// only accessor and it requires knowing every issuer-defined key up
// front), so we extract the JSON ourselves. We only need a single
// entry by name — no need for a full ZIP library.

private enum PassJSONReader {

    static func passJSON(in archive: Data) throws -> [String: Any] {
        guard let blob = try extract(fileName: "pass.json", from: archive) else {
            throw ImportError.unreadable
        }
        guard let obj = try JSONSerialization.jsonObject(with: blob) as? [String: Any] else {
            throw ImportError.unreadable
        }
        return obj
    }

    // MARK: - Zip central-directory walk

    private static func extract(fileName: String, from data: Data) throws -> Data? {
        guard let eocd = findEOCD(in: data) else { return nil }
        // End-Of-Central-Directory record: signature(4) + thisDisk(2) +
        // cdDisk(2) + entriesOnThisDisk(2) + totalEntries(2) + cdSize(4) +
        // cdOffset(4) + commentLen(2). The central directory offset we
        // need sits 16 bytes into the record.
        let cdOffset = Int(data.readUInt32LE(at: eocd + 16))
        let cdSize   = Int(data.readUInt32LE(at: eocd + 12))
        guard cdOffset + cdSize <= data.count else { return nil }

        var cursor = cdOffset
        while cursor + 46 <= cdOffset + cdSize {
            let sig = data.readUInt32LE(at: cursor)
            guard sig == 0x02014b50 else { break }

            let method     = Int(data.readUInt16LE(at: cursor + 10))
            let compSize   = Int(data.readUInt32LE(at: cursor + 20))
            let uncompSize = Int(data.readUInt32LE(at: cursor + 24))
            let nameLen    = Int(data.readUInt16LE(at: cursor + 28))
            let extraLen   = Int(data.readUInt16LE(at: cursor + 30))
            let commentLen = Int(data.readUInt16LE(at: cursor + 32))
            let lfhOffset  = Int(data.readUInt32LE(at: cursor + 42))

            let nameStart = cursor + 46
            let nameEnd   = nameStart + nameLen
            guard nameEnd <= data.count else { return nil }
            let name = String(
                data: data.subdata(in: nameStart..<nameEnd),
                encoding: .utf8
            ) ?? ""

            if name == fileName {
                return try readEntry(
                    data: data,
                    lfhOffset: lfhOffset,
                    method: method,
                    compSize: compSize,
                    uncompSize: uncompSize
                )
            }
            cursor = nameEnd + extraLen + commentLen
        }
        return nil
    }

    private static func readEntry(
        data: Data,
        lfhOffset: Int,
        method: Int,
        compSize: Int,
        uncompSize: Int
    ) throws -> Data? {
        // Local file header: sig(4) + version(2) + flags(2) + method(2)
        // + modTime(2) + modDate(2) + crc(4) + compSize(4) + uncompSize(4)
        // + nameLen(2) + extraLen(2).
        guard lfhOffset + 30 <= data.count else { return nil }
        let sig = data.readUInt32LE(at: lfhOffset)
        guard sig == 0x04034b50 else { return nil }

        let nameLen  = Int(data.readUInt16LE(at: lfhOffset + 26))
        let extraLen = Int(data.readUInt16LE(at: lfhOffset + 28))
        let dataStart = lfhOffset + 30 + nameLen + extraLen
        let dataEnd   = dataStart + compSize
        guard dataEnd <= data.count else { return nil }

        let bytes = data.subdata(in: dataStart..<dataEnd)
        switch method {
        case 0: return bytes
        case 8: return inflate(bytes, uncompressedSize: uncompSize)
        default: return nil
        }
    }

    /// ZIP method 8 stores raw DEFLATE (no zlib wrapper, no gzip
    /// wrapper). `COMPRESSION_ZLIB` in Apple's Compression framework
    /// decodes exactly that.
    private static func inflate(_ data: Data, uncompressedSize: Int) -> Data? {
        let capacity = max(uncompressedSize, data.count * 4, 4_096)
        return data.withUnsafeBytes { rawIn -> Data? in
            guard let base = rawIn.baseAddress else { return nil }
            let src = base.assumingMemoryBound(to: UInt8.self)
            let dst = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
            defer { dst.deallocate() }
            let decoded = compression_decode_buffer(
                dst, capacity,
                src, data.count,
                nil, COMPRESSION_ZLIB
            )
            guard decoded > 0 else { return nil }
            return Data(bytes: dst, count: decoded)
        }
    }

    /// Scans the last 64KB + 22 bytes of the archive for the End-Of-
    /// Central-Directory signature. ZIP specs allow a trailing comment
    /// up to 65535 bytes, so we walk backward through the plausible
    /// range.
    private static func findEOCD(in data: Data) -> Int? {
        let minRecord = 22
        guard data.count >= minRecord else { return nil }
        let maxComment = 65_535
        let start = max(0, data.count - minRecord - maxComment)
        let end = data.count - minRecord
        var i = end
        while i >= start {
            if data.readUInt32LE(at: i) == 0x06054b50 {
                return i
            }
            i -= 1
        }
        return nil
    }
}

// MARK: - Data LE readers
//
// Use `withUnsafeBytes` so reads are always 0-indexed, regardless of
// whether `self` is the backing Data or a slice with a non-zero
// startIndex.

private extension Data {

    func readUInt16LE(at offset: Int) -> UInt16 {
        withUnsafeBytes { buf -> UInt16 in
            guard offset + 2 <= buf.count else { return 0 }
            return UInt16(buf[offset]) | (UInt16(buf[offset + 1]) << 8)
        }
    }

    func readUInt32LE(at offset: Int) -> UInt32 {
        withUnsafeBytes { buf -> UInt32 in
            guard offset + 4 <= buf.count else { return 0 }
            return UInt32(buf[offset])
                | (UInt32(buf[offset + 1]) << 8)
                | (UInt32(buf[offset + 2]) << 16)
                | (UInt32(buf[offset + 3]) << 24)
        }
    }
}
