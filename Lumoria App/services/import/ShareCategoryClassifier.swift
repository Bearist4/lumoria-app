//
//  ShareCategoryClassifier.swift
//  Lumoria App
//
//  Deterministic category classifier for shared text. Returns a
//  primitive `String?` category (`"plane"` / `"concert"`) so this
//  file can link into the share extension target without depending
//  on `TicketCategory`. Main-app callers go through
//  `ShareImportTranslator.category(from:)` to convert.
//

import Foundation

enum ShareCategoryClassifier {

    /// Threshold a category must clear (normalized score 0–1) to be
    /// considered a confident match.
    static let confidenceThreshold: Double = 0.7

    static func classify(text: String) -> ShareClassification {
        guard !text.isEmpty else {
            return ShareClassification(category: nil, confidence: 0, signals: [])
        }
        let normalized = text.lowercased()

        var best: (category: String, score: Int, signals: [String])? = nil
        for (category, scorecard) in scorecards {
            let result = score(
                normalized: normalized,
                original: text,
                scorecard: scorecard
            )
            if result.score > (best?.score ?? 0) {
                best = (category, result.score, result.signals)
            }
        }

        guard let best else {
            return ShareClassification(category: nil, confidence: 0, signals: [])
        }
        // 10 = empirical "very confident" ceiling.
        let normalizedScore = min(Double(best.score) / 10.0, 1.0)
        let category: String? = normalizedScore >= confidenceThreshold ? best.category : nil
        return ShareClassification(
            category: category,
            confidence: normalizedScore,
            signals: best.signals
        )
    }

    // MARK: - Scoring

    private struct Scorecard {
        let keywords: [String]
        let domains: [String]
        let regexes: [(NSRegularExpression, String)]
    }

    private static let scorecards: [(String, Scorecard)] = [
        ("plane", planeScorecard),
        ("concert", concertScorecard),
    ]

    private static let planeScorecard: Scorecard = Scorecard(
        keywords: [
            "boarding pass", "boarding-pass", "flight", "gate", "departure",
            "departing", "carte d'embarquement", "vol ", "siège", "porte",
        ],
        domains: [
            "@united.", "@delta.", "@aa.com", "@americanairlines.",
            "@lufthansa.", "@airfrance.", "@klm.", "@britishairways.",
            "@ba.com", "@iberia.", "@easyjet.", "@ryanair.", "@swiss.",
            "@emirates.", "@qatarairways.", "@turkishairlines.",
        ],
        regexes: [
            (try! NSRegularExpression(
                pattern: #"\b[A-Z]{3}\s*(?:[→\-]|to)\s*[A-Z]{3}\b"#
            ), "iata-pair"),
            (try! NSRegularExpression(
                pattern: #"\b[A-Z]{2,3}\s?\d{1,4}\b"#
            ), "flight-number"),
        ]
    )

    private static let concertScorecard: Scorecard = Scorecard(
        keywords: [
            // English structure / event signals
            "doors open", "doors:", "general admission", "section",
            "showtime", "show time", "tour", "live at", "concert",
            "venue", "promoter", "promotion", "seats category",
            // French
            "porte ", "rangée", "siège",
            // German structure / venue signals
            "konzert", "stehplatz", "sitzplatz", "halle", "stadthalle",
            "einlass", "bestellung", "bestellbestätigung", "deine bestellung",
            "song contest",
            // Vendor names without `@` prefix — emails OCR'd from
            // screenshots rarely contain the from-address line, so a
            // bare vendor name in the body or subject is often the
            // strongest signal we get.
            "ticketmaster", "axs", "dice.fm", "oeticket", "eventim",
            "songkick", "livenation", "see tickets", "seetickets",
            "fnac spectacles",
        ],
        domains: [
            "@ticketmaster.", "@ticketmaster.fr", "@ticketmaster.de",
            "@axs.", "@dice.fm", "@seetickets.", "@songkick.",
            "@livenation.", "@eventim.", "@fnacspectacles.",
            "@oeticket.",
        ],
        regexes: [
            // Allow Section / Sektion / Bereich / Area to anchor the
            // section-row-seat pattern. Austrian/German venues tend to
            // use "Area" or "Bereich" instead of "Section".
            (try! NSRegularExpression(
                pattern: #"(?i)(?:Sec(?:tion)?|Sektion|Bereich|Area)\s?\w+.*Row\s?\w+.*Seat\s?\w+"#
            ), "section-row-seat"),
            (try! NSRegularExpression(
                pattern: #"(?i)Doors?\s*(?:open\s*at\s*)?\d{1,2}[:.]?\d{0,2}\s*(?:AM|PM)?"#
            ), "doors-time"),
        ]
    )

    private struct ScoreResult {
        let score: Int
        let signals: [String]
    }

    private static func score(
        normalized: String,
        original: String,
        scorecard: Scorecard
    ) -> ScoreResult {
        var total = 0
        var signals: [String] = []

        for keyword in scorecard.keywords {
            if normalized.contains(keyword) {
                total += 2
                signals.append("kw:\(keyword)")
            }
        }
        for domain in scorecard.domains {
            if normalized.contains(domain) {
                total += 3
                signals.append("domain:\(domain)")
            }
        }
        let range = NSRange(original.startIndex..., in: original)
        for (regex, name) in scorecard.regexes {
            if regex.firstMatch(in: original, range: range) != nil {
                total += 3
                signals.append("regex:\(name)")
            }
        }
        return ScoreResult(score: total, signals: signals)
    }
}
