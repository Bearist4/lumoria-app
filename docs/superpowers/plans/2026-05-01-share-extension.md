# Share Extension (Plane + Concert) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `LumoriaShareImport` Share Extension that accepts shared screenshots, text, and URLs from any app, runs on-device OCR + deterministic regex/keyword classification, and pre-fills the new-ticket funnel for plane and concert categories.

**Architecture:** Same hand-off model as the existing `LumoriaPKPassImport` extension — the extension writes a parsed payload into the App Group container (`group.bearista.Lumoria-App/pending-share.json`) and the main app drains it on `scenePhase == .active`. Classification + extraction run on-device with `VNRecognizeTextRequest`, regex tables, and `NSDataDetector` — no LLM, no network. The funnel opens at the `category` step pre-locked to the detected category, the user picks a template, and `ImportStep` swaps in the pre-extracted form input instead of running the file picker.

**Cross-target type discipline:** Shared classifier/extractor code uses **primitive types only** (`String?` category, plain structs with strings/dates) — never `TicketCategory`, `FlightFormInput`, or `EventFormInput`. A main-app-only `ShareImportTranslator` converts primitive fields into the real form-input types when the funnel applies the result. This keeps the extension target free of SwiftUI, MapKit, and Combine dependencies that `NewTicketFunnel.swift` would otherwise drag in.

**Tech Stack:** Swift / SwiftUI, UIKit (extension UI), Vision (OCR), NaturalLanguage (NLTagger), Foundation (`NSDataDetector`, regex), App Groups, custom URL scheme `lumoria://import/share`.

**Companion memory:** `feedback_no_llm.md` — no paid LLM APIs; on-device only.

**Status as of 2026-05-01:** Planning. Worktree: `.claude/worktrees/share-extension`, branch `feature/share-extension`.

---

## User-driven configuration

Adding a new app extension target requires Xcode UI clicks that an agent cannot perform. Do these before Task 13.

- [ ] **Xcode → File → New → Target → Share Extension**
  - Product Name: `LumoriaShareImport`
  - Bundle Identifier (auto-generated): `bearista.Lumoria-App.LumoriaShareImport`
  - Language: Swift
  - Embed in Application: `Lumoria App`
  - When asked about activating the scheme: choose **Don't Activate**.
- [ ] **Xcode → LumoriaShareImport target → Signing & Capabilities → "+" → App Groups** → check `group.bearista.Lumoria-App`.
- [ ] **Delete the boilerplate `ShareViewController.swift`** Xcode generated under `LumoriaShareImport/`. Task 16 writes a replacement.
- [ ] **Delete the boilerplate `MainInterface.storyboard`** Xcode generated.
- [ ] **Xcode → LumoriaShareImport → Info.plist** → confirm `NSExtensionMainStoryboard` is removed and `NSExtensionPrincipalClass` is added (Task 14 documents the full Info.plist contents).
- [ ] **Xcode → LumoriaShareImport → Build Phases → Link Binary With Libraries** → add `Vision.framework` and `NaturalLanguage.framework`.
- [ ] **Xcode → Lumoria App target → Build Phases → Embed App Extensions** → confirm `LumoriaShareImport.appex` is listed.

---

## File Structure

**New (shared logic — added to BOTH `Lumoria App` AND `LumoriaShareImport` target membership; primitive types only, no app-type refs):**
- `Lumoria App/services/import/SharePayload.swift` — value types: `SharePayload`, `ShareClassification`, `SharePlaneFields`, `ShareConcertFields`, `ShareImportResult`. `category` is `String?` (`"plane"` / `"concert"`).
- `Lumoria App/services/import/ShareCategoryClassifier.swift` — keyword + regex + domain scorecard returning `ShareClassification`.
- `Lumoria App/services/import/SharePlaneExtractor.swift` — regex + `NSDataDetector` extraction → `SharePlaneFields`.
- `Lumoria App/services/import/ShareConcertExtractor.swift` — regex + `NLTagger` extraction → `ShareConcertFields`.
- `Lumoria App/services/import/SharePayloadHandoff.swift` — JSON encode/decode + App Group file I/O.

**New (extension target only):**
- `LumoriaShareImport/ShareViewController.swift` — UIKit shell.
- `LumoriaShareImport/Info.plist` — `NSExtensionAttributes` declaring accepted UTI types.
- `LumoriaShareImport/LumoriaShareImport.entitlements` — App Group entitlement.
- `LumoriaShareImport/SharePayloadOCR.swift` — async wrapper around `VNRecognizeTextRequest`. UIKit-dependent, so kept in the extension target rather than shared.

**New (main app target only — references real form-input types):**
- `Lumoria App/services/import/ShareImportTranslator.swift` — converts `ShareCategoryClassifier`'s string category into `TicketCategory`; copies `SharePlaneFields` into `FlightFormInput` and `ShareConcertFields` into `EventFormInput`.
- `Lumoria App/services/import/ShareImportCoordinator.swift` — `@Published var pending: ShareImportResult?` mirror of `WalletImportCoordinator`.

**New (test target — `Lumoria AppTests`):**
- `Lumoria AppTests/ShareCategoryClassifierTests.swift`
- `Lumoria AppTests/SharePlaneExtractorTests.swift`
- `Lumoria AppTests/ShareConcertExtractorTests.swift`
- `Lumoria AppTests/SharePayloadHandoffTests.swift`
- `Lumoria AppTests/ShareImportTranslatorTests.swift`

**Modified:**
- `Lumoria App/Lumoria_AppApp.swift` — add `drainPendingShareImport()`; inject `ShareImportCoordinator`; route `lumoria://import/share` and `https://getlumoria.app/import/share`.
- `Lumoria App/views/tickets/new/NewTicketFunnel.swift` — add `case share` to `ImportSource`; add `pendingShareImport: ShareImportResult?`; add `applyShareImport(_:)` (uses `ShareImportTranslator` internally).
- `Lumoria App/views/tickets/new/ImportStep.swift` — branch on `funnel.importSource`.
- `Lumoria App/views/tickets/AllTicketsView.swift` — observe `ShareImportCoordinator`; present funnel with preset category.
- `Lumoria App.xcodeproj/project.pbxproj` — auto-edited by Xcode for new target + file membership.

---

## Task 1: Define share payload value types (primitive-only)

**Files:**
- Create: `Lumoria App/services/import/SharePayload.swift`

- [ ] **Step 1: Write the value types**

```swift
//
//  SharePayload.swift
//  Lumoria App
//
//  Value types passed between the share extension and the main app.
//  Primitive types only — no `TicketCategory`, no `FlightFormInput`,
//  no `EventFormInput`. The main-app `ShareImportTranslator` converts
//  these into the funnel's real form-input types. Keeping the
//  extension target free of those types means it doesn't have to
//  link SwiftUI/MapKit/Combine just to compile.
//

import Foundation

/// Raw text the share extension extracted from a shared item before
/// running classification. `image` carries the source PNG bytes when
/// present so the main app can attach it to the ticket later.
struct SharePayload: Codable, Equatable {
    var text: String
    var image: Data?
    var sourceURL: URL?
}

/// Classification outcome for a payload. `category` is nil when no
/// scorecard cleared the threshold; the funnel falls back to the
/// category picker in that case.
///
/// `category` is a `String?` (`"plane"` or `"concert"`) — not
/// `TicketCategory` — to keep this file linkable into the extension
/// target without dragging in `NewTicketFunnel.swift`.
struct ShareClassification: Codable, Equatable {
    var category: String?
    var confidence: Double
    var signals: [String]
}

/// Plane-shaped fields extracted from text. Mirrors the subset of
/// `FlightFormInput` we can reasonably populate from OCR'd text.
/// Strings default to "" so the translator can do a straight copy.
struct SharePlaneFields: Codable, Equatable {
    var airline: String = ""
    var flightNumber: String = ""
    var originCode: String = ""
    var destinationCode: String = ""
    var gate: String = ""
    var seat: String = ""
    var terminal: String = ""
    var departureDate: Date?
}

/// Concert-shaped fields extracted from text. Mirrors the subset of
/// `EventFormInput` we can reasonably populate.
struct ShareConcertFields: Codable, Equatable {
    var artist: String = ""
    var tourName: String = ""
    var venue: String = ""
    var ticketNumber: String = ""
    var date: Date?
    var doorsTime: Date?
    var showTime: Date?
}

/// What the extension hands off to the main app. JSON-only contract.
/// One of `flight` / `event` is populated when classification
/// succeeded; both nil means the funnel will open at the category
/// picker with `payload.text` available for the user.
struct ShareImportResult: Codable, Equatable {
    var classification: ShareClassification
    var flight: SharePlaneFields?
    var event: ShareConcertFields?
    var payload: SharePayload
}
```

- [ ] **Step 2: Add file to both target memberships in Xcode**

Open `Lumoria App.xcodeproj` → select `SharePayload.swift` → File Inspector → Target Membership → check **both** `Lumoria App` AND `LumoriaShareImport`.

(If the extension target hasn't been created yet — it's created in the User-driven configuration steps before Task 13 — leave the membership as `Lumoria App` only and revisit when the target exists. The build will pass either way.)

- [ ] **Step 3: Build to verify**

Run: `xcodebuild -project "Lumoria App.xcodeproj" -scheme "Lumoria App" -destination "generic/platform=iOS Simulator" build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED (or pre-existing unrelated warnings).

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/services/import/SharePayload.swift" "Lumoria App.xcodeproj/project.pbxproj"
git commit -m "feat(share): primitive-typed share payload contract"
```

---

## Task 2: Plane + concert classifier — failing tests

**Files:**
- Create: `Lumoria AppTests/ShareCategoryClassifierTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
//
//  ShareCategoryClassifierTests.swift
//  Lumoria AppTests
//

import XCTest
@testable import Lumoria_App

final class ShareCategoryClassifierTests: XCTestCase {

    // MARK: - Plane

    func testClassifiesUnitedConfirmationAsPlane() {
        let text = """
        Your United flight is confirmed.
        Confirmation: ABC123
        UA 1471 — SFO → JFK
        Departing Tue, May 14, 6:30 AM
        Boarding pass attached.
        From: receipts@united.com
        """
        let result = ShareCategoryClassifier.classify(text: text)
        XCTAssertEqual(result.category, "plane")
        XCTAssertGreaterThanOrEqual(result.confidence, 0.7)
    }

    func testClassifiesAirFranceAsPlane() {
        let text = """
        Votre carte d'embarquement
        Vol AF 1280 Paris CDG → Amsterdam AMS
        Départ 12 juin 14:25
        Porte K42 Siège 18A
        """
        let result = ShareCategoryClassifier.classify(text: text)
        XCTAssertEqual(result.category, "plane")
    }

    func testClassifiesGenericIATATextAsPlane() {
        let text = "BA 286 LHR-SFO Gate 23 Seat 14C departure 11:45"
        let result = ShareCategoryClassifier.classify(text: text)
        XCTAssertEqual(result.category, "plane")
    }

    // MARK: - Concert

    func testClassifiesTicketmasterAsConcert() {
        let text = """
        Your Ticketmaster order is confirmed.
        Taylor Swift — The Eras Tour
        Stade de France, Saint-Denis
        June 7, 2026 · Doors 6:00 PM
        Section 134, Row 22, Seat 14
        Order #: 18-12345/PAR
        From: customer_service@ticketmaster.fr
        """
        let result = ShareCategoryClassifier.classify(text: text)
        XCTAssertEqual(result.category, "concert")
        XCTAssertGreaterThanOrEqual(result.confidence, 0.7)
    }

    func testClassifiesAXSConcertAsConcert() {
        let text = """
        AXS — Order confirmation
        The Cure · Live at the O2 Arena
        Doors open 7:00 PM
        Section 101, Row F, Seat 22
        """
        let result = ShareCategoryClassifier.classify(text: text)
        XCTAssertEqual(result.category, "concert")
    }

    // MARK: - Negative

    func testReturnsNilCategoryForUnrelatedText() {
        let text = """
        Hi team,
        Quick reminder that the design review is at 3pm today.
        Thanks!
        """
        let result = ShareCategoryClassifier.classify(text: text)
        XCTAssertNil(result.category)
        XCTAssertLessThan(result.confidence, 0.7)
    }

    func testReturnsNilForEmptyText() {
        let result = ShareCategoryClassifier.classify(text: "")
        XCTAssertNil(result.category)
        XCTAssertEqual(result.confidence, 0.0)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `xcodebuild -project "Lumoria App.xcodeproj" -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:Lumoria_AppTests/ShareCategoryClassifierTests 2>&1 | tail -30`
Expected: Compile failure: "cannot find 'ShareCategoryClassifier' in scope".

---

## Task 3: Classifier — implementation

**Files:**
- Create: `Lumoria App/services/import/ShareCategoryClassifier.swift`

- [ ] **Step 1: Write the classifier**

```swift
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
            "doors open", "doors:", "general admission", "section",
            "showtime", "show time", "tour", "live at", "concert",
            "porte ", "section ", "rangée", "siège",
        ],
        domains: [
            "@ticketmaster.", "@ticketmaster.fr", "@ticketmaster.de",
            "@axs.", "@dice.fm", "@seetickets.", "@songkick.",
            "@livenation.", "@eventim.", "@fnacspectacles.",
        ],
        regexes: [
            (try! NSRegularExpression(
                pattern: #"(?i)Sec(?:tion)?\s?\w+.*Row\s?\w+.*Seat\s?\w+"#
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
```

- [ ] **Step 2: Add file to both target memberships in Xcode**

Same as Task 1 Step 2.

- [ ] **Step 3: Run tests — expect 6 passes**

Run: `xcodebuild -project "Lumoria App.xcodeproj" -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:Lumoria_AppTests/ShareCategoryClassifierTests 2>&1 | tail -30`
Expected: 6 passed, 0 failed.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/services/import/ShareCategoryClassifier.swift" \
        "Lumoria AppTests/ShareCategoryClassifierTests.swift" \
        "Lumoria App.xcodeproj/project.pbxproj"
git commit -m "feat(share): deterministic plane+concert classifier"
```

---

## Task 4: Plane extractor — failing tests

**Files:**
- Create: `Lumoria AppTests/SharePlaneExtractorTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
//
//  SharePlaneExtractorTests.swift
//  Lumoria AppTests
//

import XCTest
@testable import Lumoria_App

final class SharePlaneExtractorTests: XCTestCase {

    func testExtractsUnitedFields() {
        let text = """
        Your United flight is confirmed.
        Confirmation: ABC123
        UA 1471 — SFO → JFK
        Departing Tue, May 14, 6:30 AM
        Gate B22 · Seat 14C · Terminal 3
        """
        let result = SharePlaneExtractor.extract(text: text)
        XCTAssertEqual(result.flightNumber, "UA 1471")
        XCTAssertEqual(result.originCode, "SFO")
        XCTAssertEqual(result.destinationCode, "JFK")
        XCTAssertEqual(result.gate, "B22")
        XCTAssertEqual(result.seat, "14C")
        XCTAssertEqual(result.terminal, "3")
    }

    func testExtractsAirFranceFields() {
        let text = """
        Air France
        AF 1280 CDG → AMS
        12 juin 14:25
        Porte K42 Siège 18A
        """
        let result = SharePlaneExtractor.extract(text: text)
        XCTAssertEqual(result.flightNumber, "AF 1280")
        XCTAssertEqual(result.originCode, "CDG")
        XCTAssertEqual(result.destinationCode, "AMS")
        XCTAssertEqual(result.gate, "K42")
        XCTAssertEqual(result.seat, "18A")
    }

    func testExtractsBareIATAPairWithDash() {
        let text = "BA 286 LHR-SFO Gate 23 Seat 14C"
        let result = SharePlaneExtractor.extract(text: text)
        XCTAssertEqual(result.flightNumber, "BA 286")
        XCTAssertEqual(result.originCode, "LHR")
        XCTAssertEqual(result.destinationCode, "SFO")
        XCTAssertEqual(result.gate, "23")
        XCTAssertEqual(result.seat, "14C")
    }

    func testReturnsEmptyWhenNothingMatches() {
        let result = SharePlaneExtractor.extract(text: "Hello world")
        XCTAssertEqual(result.flightNumber, "")
        XCTAssertEqual(result.originCode, "")
        XCTAssertEqual(result.destinationCode, "")
    }
}
```

- [ ] **Step 2: Run to verify failure**

Expected: "cannot find 'SharePlaneExtractor'".

---

## Task 5: Plane extractor — implementation

**Files:**
- Create: `Lumoria App/services/import/SharePlaneExtractor.swift`

- [ ] **Step 1: Write the extractor**

```swift
//
//  SharePlaneExtractor.swift
//  Lumoria App
//
//  Pulls SharePlaneFields out of arbitrary plane-confirmation text
//  using regex tables and NSDataDetector. Output struct is Codable
//  primitives only — the main-app translator copies it into a
//  `FlightFormInput` after the funnel applies the result.
//

import Foundation

enum SharePlaneExtractor {

    static func extract(text: String) -> SharePlaneFields {
        var fields = SharePlaneFields()

        if let flight = matchFirst(text, pattern: flightNumberPattern) {
            fields.flightNumber = normalizeFlight(flight)
        }
        if let pair = matchPair(text, pattern: iataPairPattern) {
            fields.originCode = pair.0
            fields.destinationCode = pair.1
        }
        fields.gate = matchCapture(text, pattern: gatePattern) ?? ""
        fields.seat = matchCapture(text, pattern: seatPattern) ?? ""
        fields.terminal = matchCapture(text, pattern: terminalPattern) ?? ""
        if let date = firstDate(in: text) {
            fields.departureDate = date
        }
        return fields
    }

    // MARK: - Patterns

    private static let flightNumberPattern = try! NSRegularExpression(
        pattern: #"\b([A-Z]{2,3})\s?(\d{1,4}[A-Z]?)\b"#
    )

    private static let iataPairPattern = try! NSRegularExpression(
        pattern: #"\b([A-Z]{3})\s*(?:[→\-—]|to)\s*([A-Z]{3})\b"#
    )

    private static let gatePattern = try! NSRegularExpression(
        pattern: #"(?i)(?:Gate|Porte)[:\s]+([A-Z]?\d+[A-Z]?)"#
    )

    private static let seatPattern = try! NSRegularExpression(
        pattern: #"(?i)(?:Seat|Siège|Si.ge)[:\s]+(\d{1,3}[A-Z]?)"#
    )

    private static let terminalPattern = try! NSRegularExpression(
        pattern: #"(?i)Terminal[:\s]+([A-Z0-9]+)"#
    )

    // MARK: - Date

    private static let dateDetector: NSDataDetector? = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.date.rawValue
    )

    private static func firstDate(in text: String) -> Date? {
        let range = NSRange(text.startIndex..., in: text)
        guard let detector = dateDetector,
              let match = detector.firstMatch(in: text, range: range) else {
            return nil
        }
        return match.date
    }

    // MARK: - Regex helpers

    private static func matchFirst(_ text: String, pattern: NSRegularExpression) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = pattern.firstMatch(in: text, range: range),
              let r = Range(match.range, in: text) else { return nil }
        return String(text[r])
    }

    private static func matchCapture(_ text: String, pattern: NSRegularExpression) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = pattern.firstMatch(in: text, range: range),
              match.numberOfRanges >= 2,
              let r = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }

    private static func matchPair(_ text: String, pattern: NSRegularExpression) -> (String, String)? {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = pattern.firstMatch(in: text, range: range),
              match.numberOfRanges >= 3,
              let a = Range(match.range(at: 1), in: text),
              let b = Range(match.range(at: 2), in: text) else { return nil }
        return (String(text[a]), String(text[b]))
    }

    /// Inserts a space between carrier code and digits when missing.
    /// "AF1280" → "AF 1280", "UA 1471" → "UA 1471".
    private static func normalizeFlight(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.contains(" ") { return trimmed }
        let chars = Array(trimmed)
        guard let firstDigit = chars.firstIndex(where: { $0.isNumber }),
              firstDigit > 0 else { return trimmed }
        let prefix = String(chars[..<firstDigit])
        let suffix = String(chars[firstDigit...])
        return "\(prefix) \(suffix)"
    }
}
```

- [ ] **Step 2: Add file to both target memberships in Xcode**

Same as Task 1 Step 2.

- [ ] **Step 3: Run tests — expect 4 passes**

Run: `xcodebuild ... test -only-testing:Lumoria_AppTests/SharePlaneExtractorTests 2>&1 | tail -30`
Expected: 4 passed.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/services/import/SharePlaneExtractor.swift" \
        "Lumoria AppTests/SharePlaneExtractorTests.swift" \
        "Lumoria App.xcodeproj/project.pbxproj"
git commit -m "feat(share): plane field extractor"
```

---

## Task 6: Concert extractor — failing tests

**Files:**
- Create: `Lumoria AppTests/ShareConcertExtractorTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
//
//  ShareConcertExtractorTests.swift
//  Lumoria AppTests
//

import XCTest
@testable import Lumoria_App

final class ShareConcertExtractorTests: XCTestCase {

    func testExtractsTaylorSwiftEras() {
        let text = """
        Your Ticketmaster order is confirmed.
        Taylor Swift — The Eras Tour
        Stade de France, Saint-Denis
        June 7, 2026 · Doors 6:00 PM · Show 7:30 PM
        Section 134, Row 22, Seat 14
        Order #: 18-12345/PAR
        """
        let result = ShareConcertExtractor.extract(text: text)
        XCTAssertEqual(result.artist, "Taylor Swift")
        XCTAssertEqual(result.tourName, "The Eras Tour")
        XCTAssertTrue(result.venue.contains("Stade de France"))
        XCTAssertEqual(result.ticketNumber, "18-12345/PAR")
    }

    func testExtractsCureAtO2() {
        let text = """
        AXS — Order confirmation
        The Cure · Live at the O2 Arena
        Doors open 7:00 PM
        Section 101, Row F, Seat 22
        Order #ABC987
        """
        let result = ShareConcertExtractor.extract(text: text)
        XCTAssertEqual(result.artist, "The Cure")
        XCTAssertTrue(result.venue.contains("O2 Arena"))
        XCTAssertEqual(result.ticketNumber, "ABC987")
    }

    func testReturnsEmptyForUnrelatedText() {
        let result = ShareConcertExtractor.extract(text: "Hello world")
        XCTAssertEqual(result.artist, "")
        XCTAssertEqual(result.venue, "")
    }
}
```

- [ ] **Step 2: Run to verify failure**

Expected: "cannot find 'ShareConcertExtractor'".

---

## Task 7: Concert extractor — implementation

**Files:**
- Create: `Lumoria App/services/import/ShareConcertExtractor.swift`

- [ ] **Step 1: Write the extractor**

```swift
//
//  ShareConcertExtractor.swift
//  Lumoria App
//
//  Pulls ShareConcertFields out of concert-confirmation text using
//  regex + NLTagger for proper-noun extraction. Header-style layouts
//  ("Artist — Tour Name") cover most ticketing vendor templates.
//

import Foundation
import NaturalLanguage

enum ShareConcertExtractor {

    static func extract(text: String) -> ShareConcertFields {
        var fields = ShareConcertFields()

        if let header = headerLine(in: text) {
            let parts = splitHeader(header)
            fields.artist = parts.artist
            fields.tourName = parts.tour
        }

        if let venue = matchCapture(text, pattern: venuePattern) {
            fields.venue = venue.trimmingCharacters(in: .whitespaces)
        } else if let venue = nlVenueGuess(text) {
            fields.venue = venue
        }

        if let order = matchCapture(text, pattern: orderNumberPattern) {
            fields.ticketNumber = order.trimmingCharacters(in: .whitespaces)
        }

        if let date = firstDate(in: text) {
            fields.date = date
            fields.showTime = date
        }
        if let doors = matchCapture(text, pattern: doorsPattern),
           let date = fields.date,
           let doorsDate = combineTime(doors, with: date) {
            fields.doorsTime = doorsDate
        }

        return fields
    }

    // MARK: - Header

    private static func headerLine(in text: String) -> String? {
        let lines = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        for line in lines {
            let lower = line.lowercased()
            if lower.contains("ticketmaster") && lower.contains("confirm") { continue }
            if lower.contains("axs") && lower.contains("confirm") { continue }
            if lower.contains("order") && lower.contains("confirm") { continue }
            if lower.hasPrefix("your ") { continue }
            return line
        }
        return nil
    }

    private static func splitHeader(_ header: String) -> (artist: String, tour: String) {
        for sep in [" — ", " – ", " - ", " · "] {
            if let range = header.range(of: sep) {
                let artist = String(header[..<range.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
                let tour = String(header[range.upperBound...])
                    .trimmingCharacters(in: .whitespaces)
                if tour.lowercased().hasPrefix("live at ") {
                    return (artist, "")
                }
                return (artist, tour)
            }
        }
        return (header, "")
    }

    // MARK: - Venue

    private static let venuePattern = try! NSRegularExpression(
        pattern: #"(?i)(?:Live at(?: the)?|at)\s+([^,\n]+?)(?:,|\n|$)"#
    )

    private static func nlVenueGuess(_ text: String) -> String? {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        let options: NLTagger.Options = [
            .omitWhitespace, .omitPunctuation, .joinNames,
        ]
        var longest: String = ""
        let range = text.startIndex..<text.endIndex
        tagger.enumerateTags(
            in: range,
            unit: .word,
            scheme: .nameType,
            options: options
        ) { tag, tokenRange in
            if tag == .placeName {
                let phrase = String(text[tokenRange])
                if phrase.count > longest.count { longest = phrase }
            }
            return true
        }
        return longest.isEmpty ? nil : longest
    }

    // MARK: - Order number

    private static let orderNumberPattern = try! NSRegularExpression(
        pattern: #"(?i)Order\s*#?:?\s*([A-Z0-9][A-Z0-9\-/]+)"#
    )

    // MARK: - Doors / show

    private static let doorsPattern = try! NSRegularExpression(
        pattern: #"(?i)Doors?\s*(?:open\s*at\s*)?:?\s*(\d{1,2}[:.]?\d{0,2}\s*(?:AM|PM)?)"#
    )

    private static func combineTime(_ raw: String, with anchor: Date) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let formatters: [DateFormatter] = ["h:mm a", "HH:mm", "h a"].map { fmt in
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = fmt
            return f
        }
        for f in formatters {
            if let parsed = f.date(from: trimmed) {
                let cal = Calendar.current
                let timeParts = cal.dateComponents([.hour, .minute], from: parsed)
                var anchorParts = cal.dateComponents([.year, .month, .day], from: anchor)
                anchorParts.hour = timeParts.hour
                anchorParts.minute = timeParts.minute ?? 0
                return cal.date(from: anchorParts)
            }
        }
        return nil
    }

    // MARK: - Date

    private static let dateDetector: NSDataDetector? = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.date.rawValue
    )

    private static func firstDate(in text: String) -> Date? {
        let range = NSRange(text.startIndex..., in: text)
        guard let detector = dateDetector,
              let match = detector.firstMatch(in: text, range: range) else {
            return nil
        }
        return match.date
    }

    // MARK: - Regex helper

    private static func matchCapture(_ text: String, pattern: NSRegularExpression) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = pattern.firstMatch(in: text, range: range),
              match.numberOfRanges >= 2,
              let r = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }
}
```

- [ ] **Step 2: Add file to both target memberships in Xcode**

- [ ] **Step 3: Run tests — expect 3 passes**

Run: `xcodebuild ... test -only-testing:Lumoria_AppTests/ShareConcertExtractorTests 2>&1 | tail -30`
Expected: 3 passed.

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/services/import/ShareConcertExtractor.swift" \
        "Lumoria AppTests/ShareConcertExtractorTests.swift" \
        "Lumoria App.xcodeproj/project.pbxproj"
git commit -m "feat(share): concert field extractor"
```

---

## Task 8: Handoff JSON — failing test

**Files:**
- Create: `Lumoria AppTests/SharePayloadHandoffTests.swift`

- [ ] **Step 1: Write failing test**

```swift
//
//  SharePayloadHandoffTests.swift
//  Lumoria AppTests
//

import XCTest
@testable import Lumoria_App

final class SharePayloadHandoffTests: XCTestCase {

    func testRoundTripJSON() throws {
        let payload = SharePayload(
            text: "UA 1471 SFO → JFK",
            image: Data("png-bytes".utf8),
            sourceURL: URL(string: "https://example.com")
        )
        var flight = SharePlaneFields()
        flight.flightNumber = "UA 1471"
        flight.originCode = "SFO"
        flight.destinationCode = "JFK"

        let result = ShareImportResult(
            classification: ShareClassification(
                category: "plane", confidence: 0.85, signals: ["regex:iata-pair"]
            ),
            flight: flight,
            event: nil,
            payload: payload
        )

        let data = try SharePayloadHandoff.encode(result)
        let decoded = try SharePayloadHandoff.decode(data)
        XCTAssertEqual(decoded, result)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Expected: "cannot find 'SharePayloadHandoff'".

---

## Task 9: Handoff JSON — implementation

**Files:**
- Create: `Lumoria App/services/import/SharePayloadHandoff.swift`

- [ ] **Step 1: Write the handoff helper**

```swift
//
//  SharePayloadHandoff.swift
//  Lumoria App
//
//  JSON encode/decode + App Group file I/O for the share extension's
//  pending-share.json sentinel. Mirrors the App Group pattern used by
//  PKPassImporter for boarding passes.
//

import Foundation

enum SharePayloadHandoff {

    static let appGroupId = "group.bearista.Lumoria-App"
    static let pendingFilename = "pending-share.json"

    // MARK: - Encode / decode

    static func encode(_ result: ShareImportResult) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(result)
    }

    static func decode(_ data: Data) throws -> ShareImportResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ShareImportResult.self, from: data)
    }

    // MARK: - App Group I/O

    static func writePending(_ result: ShareImportResult) throws -> URL {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            throw HandoffError.appGroupUnavailable
        }
        let url = container.appendingPathComponent(pendingFilename)
        let data = try encode(result)
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Reads + deletes the pending file in one shot. Returns nil when
    /// nothing is queued.
    static func drainPending() -> ShareImportResult? {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            return nil
        }
        let url = container.appendingPathComponent(pendingFilename)
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else { return nil }
        try? FileManager.default.removeItem(at: url)
        return try? decode(data)
    }

    enum HandoffError: Error {
        case appGroupUnavailable
    }
}
```

- [ ] **Step 2: Add file to both target memberships in Xcode**

- [ ] **Step 3: Run test — expect 1 pass**

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/services/import/SharePayloadHandoff.swift" \
        "Lumoria AppTests/SharePayloadHandoffTests.swift" \
        "Lumoria App.xcodeproj/project.pbxproj"
git commit -m "feat(share): app-group handoff helper"
```

---

## Task 10: Translator — failing tests

**Files:**
- Create: `Lumoria AppTests/ShareImportTranslatorTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
//
//  ShareImportTranslatorTests.swift
//  Lumoria AppTests
//

import XCTest
@testable import Lumoria_App

final class ShareImportTranslatorTests: XCTestCase {

    func testTranslatesPlaneCategoryString() {
        XCTAssertEqual(ShareImportTranslator.category(from: "plane"), .plane)
        XCTAssertEqual(ShareImportTranslator.category(from: "concert"), .concert)
        XCTAssertNil(ShareImportTranslator.category(from: nil))
        XCTAssertNil(ShareImportTranslator.category(from: "unknown"))
    }

    func testTranslatesPlaneFields() {
        var fields = SharePlaneFields()
        fields.flightNumber = "UA 1471"
        fields.originCode = "SFO"
        fields.destinationCode = "JFK"
        fields.gate = "B22"
        fields.seat = "14C"
        fields.terminal = "3"
        let date = Date(timeIntervalSince1970: 1_715_677_800) // 2026-05-14 06:30
        fields.departureDate = date

        let input = ShareImportTranslator.flightInput(from: fields)
        XCTAssertEqual(input.flightNumber, "UA 1471")
        XCTAssertEqual(input.originCode, "SFO")
        XCTAssertEqual(input.destinationCode, "JFK")
        XCTAssertEqual(input.gate, "B22")
        XCTAssertEqual(input.seat, "14C")
        XCTAssertEqual(input.terminal, "3")
        XCTAssertEqual(input.departureDate, date)
        XCTAssertEqual(input.departureTime, date)
    }

    func testTranslatesConcertFields() {
        var fields = ShareConcertFields()
        fields.artist = "Taylor Swift"
        fields.tourName = "The Eras Tour"
        fields.venue = "Stade de France"
        fields.ticketNumber = "18-12345/PAR"
        let date = Date(timeIntervalSince1970: 1_717_761_600) // 2026-06-07
        fields.date = date
        fields.showTime = date

        let input = ShareImportTranslator.eventInput(from: fields)
        XCTAssertEqual(input.artist, "Taylor Swift")
        XCTAssertEqual(input.tourName, "The Eras Tour")
        XCTAssertEqual(input.venue, "Stade de France")
        XCTAssertEqual(input.ticketNumber, "18-12345/PAR")
        XCTAssertEqual(input.date, date)
        XCTAssertEqual(input.showTime, date)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Expected: "cannot find 'ShareImportTranslator'".

---

## Task 11: Translator — implementation

**Files:**
- Create: `Lumoria App/services/import/ShareImportTranslator.swift`

- [ ] **Step 1: Write the translator**

```swift
//
//  ShareImportTranslator.swift
//  Lumoria App
//
//  Converts the share extension's primitive-typed payload into the
//  funnel's real form-input types. Lives in the main app target only;
//  the extension target never references TicketCategory or
//  FlightFormInput / EventFormInput.
//

import Foundation

enum ShareImportTranslator {

    static func category(from raw: String?) -> TicketCategory? {
        guard let raw else { return nil }
        return TicketCategory(rawValue: raw)
    }

    static func flightInput(from fields: SharePlaneFields) -> FlightFormInput {
        var input = FlightFormInput()
        input.airline = fields.airline
        input.flightNumber = fields.flightNumber
        input.originCode = fields.originCode
        input.destinationCode = fields.destinationCode
        input.gate = fields.gate
        input.seat = fields.seat
        input.terminal = fields.terminal
        if let date = fields.departureDate {
            input.departureDate = date
            input.departureTime = date
        }
        return input
    }

    static func eventInput(from fields: ShareConcertFields) -> EventFormInput {
        var input = EventFormInput()
        input.artist = fields.artist
        input.tourName = fields.tourName
        input.venue = fields.venue
        input.ticketNumber = fields.ticketNumber
        if let date = fields.date {
            input.date = date
        }
        if let doors = fields.doorsTime {
            input.doorsTime = doors
        }
        if let show = fields.showTime {
            input.showTime = show
        }
        return input
    }
}
```

- [ ] **Step 2: Add file to main app target only**

(No extension target membership.)

- [ ] **Step 3: Run tests — expect 3 passes**

- [ ] **Step 4: Commit**

```bash
git add "Lumoria App/services/import/ShareImportTranslator.swift" \
        "Lumoria AppTests/ShareImportTranslatorTests.swift" \
        "Lumoria App.xcodeproj/project.pbxproj"
git commit -m "feat(share): translator from primitive fields to form inputs"
```

---

## Task 12: ShareImportCoordinator + funnel plumbing

**Files:**
- Create: `Lumoria App/services/import/ShareImportCoordinator.swift`
- Modify: `Lumoria App/views/tickets/new/NewTicketFunnel.swift`

- [ ] **Step 1: Write the coordinator**

```swift
//
//  ShareImportCoordinator.swift
//  Lumoria App
//

import Combine
import Foundation

@MainActor
final class ShareImportCoordinator: ObservableObject {

    @Published var pending: ShareImportResult?

    func enqueue(_ result: ShareImportResult) {
        pending = result
    }

    func consume() -> ShareImportResult? {
        guard let result = pending else { return nil }
        pending = nil
        return result
    }
}
```

Add file to **main app target only**.

- [ ] **Step 2: Add `.share` case to `ImportSource`**

In `NewTicketFunnel.swift`, find the existing `enum ImportSource` (around line 134–138):

```swift
enum ImportSource: String, CaseIterable, Hashable {
    case wallet
}
```

Replace with:

```swift
enum ImportSource: String, CaseIterable, Hashable {
    case wallet
    case share
}
```

- [ ] **Step 3: Add `pendingShareImport` field**

Find the `@Published var pendingPassData: Data?` declaration (search the file). Immediately below it, add:

```swift
    /// Parsed share-extension payload pre-loaded into the funnel.
    /// Consumed once by ImportStep, then cleared.
    @Published var pendingShareImport: ShareImportResult?
```

- [ ] **Step 4: Add `applyShareImport(_:)` method**

Below the existing `applyImported(_ result: ImportResult)` method (around line 909), add:

```swift
    /// Apply a parsed share-extension payload to the appropriate form
    /// input and advance to `.form`. Translates primitive fields into
    /// `FlightFormInput` / `EventFormInput` via `ShareImportTranslator`.
    func applyShareImport(_ result: ShareImportResult) {
        if let flightFields = result.flight {
            form = ShareImportTranslator.flightInput(from: flightFields)
        }
        if let eventFields = result.event {
            eventForm = ShareImportTranslator.eventInput(from: eventFields)
        }
        importFailureBanner = false
        step = .form
    }
```

- [ ] **Step 5: Reset `pendingShareImport` in the funnel's reset path**

Find the existing reset block clearing `form = FlightFormInput()` etc (around line 1427–1429). At the end of the block, add:

```swift
        pendingShareImport = nil
```

- [ ] **Step 6: Build to verify**

Run: `xcodebuild -project "Lumoria App.xcodeproj" -scheme "Lumoria App" -destination "generic/platform=iOS Simulator" build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED.

- [ ] **Step 7: Commit**

```bash
git add "Lumoria App/services/import/ShareImportCoordinator.swift" \
        "Lumoria App/views/tickets/new/NewTicketFunnel.swift" \
        "Lumoria App.xcodeproj/project.pbxproj"
git commit -m "feat(share): coordinator + funnel plumbing"
```

---

## Task 13: ImportStep — branch on source

**Files:**
- Modify: `Lumoria App/views/tickets/new/ImportStep.swift`

- [ ] **Step 1: Update body to branch on `funnel.importSource`**

Replace the entire `body` property with:

```swift
    var body: some View {
        Group {
            switch funnel.importSource {
            case .share:
                shareImportBody
            case .wallet, .none:
                walletImportBody
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fileImporter(
            isPresented: $isPicking,
            allowedContentTypes: [pkPassType],
            allowsMultipleSelection: false
        ) { result in
            handlePickResult(result)
        }
        .onAppear {
            if funnel.importSource == .wallet, let data = funnel.pendingPassData {
                funnel.pendingPassData = nil
                parse(data: data)
            }
            if funnel.importSource == .share, let result = funnel.pendingShareImport {
                funnel.pendingShareImport = nil
                funnel.applyShareImport(result)
            }
        }
    }

    @ViewBuilder
    private var walletImportBody: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)
            illustration
            VStack(spacing: 8) {
                Text(isParsing ? "Reading pass…" : "Drop in a boarding pass")
                    .font(.title3.bold())
                    .foregroundStyle(Color.Text.primary)
                Text("Pick a `.pkpass` from Files and we'll prefill every field we can read.")
                    .font(.subheadline)
                    .foregroundStyle(Color.Text.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            if let errorMessage {
                errorBanner(errorMessage)
            }
            Spacer(minLength: 0)
            VStack(spacing: 12) {
                Button {
                    isPicking = true
                } label: {
                    if isParsing {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Reading pass…")
                        }
                    } else {
                        Text("Choose a file")
                    }
                }
                .lumoriaButtonStyle(.primary, size: .large)
                .disabled(isParsing)

                Button("Fill manually") {
                    funnel.importSource = nil
                    funnel.importFailureBanner = false
                    funnel.pendingPassData = nil
                    funnel.step = .form
                }
                .lumoriaButtonStyle(.tertiary, size: .large)
                .disabled(isParsing)
            }
        }
    }

    @ViewBuilder
    private var shareImportBody: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Pre-filling your ticket…")
                .font(.subheadline)
                .foregroundStyle(Color.Text.secondary)
        }
    }
```

- [ ] **Step 2: Build to verify**

Expected: BUILD SUCCEEDED. (If `funnel.importSource = nil` doesn't compile, the existing field is non-optional. In that case, search for `@Published var importSource:` in `NewTicketFunnel.swift` and confirm it's optional. If not, change "Fill manually" to whatever the existing wallet path uses to clear it.)

- [ ] **Step 3: Commit**

```bash
git add "Lumoria App/views/tickets/new/ImportStep.swift"
git commit -m "feat(share): branch ImportStep on import source"
```

---

## Task 14: Wire up the share extension target

**Prerequisite:** "User-driven configuration" steps at the top of this plan must be complete.

**Files:**
- Verify: `LumoriaShareImport/LumoriaShareImport.entitlements`
- Modify: `LumoriaShareImport/Info.plist`

- [ ] **Step 1: Verify entitlements**

Open the entitlements file and confirm contents (mirror `LumoriaPKPassImport.entitlements`):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.bearista.Lumoria-App</string>
    </array>
</dict>
</plist>
```

If different, write this content into the file.

- [ ] **Step 2: Replace Info.plist contents**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleDisplayName</key>
    <string>Lumoria</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionAttributes</key>
        <dict>
            <key>NSExtensionActivationRule</key>
            <dict>
                <key>NSExtensionActivationSupportsImageWithMaxCount</key>
                <integer>1</integer>
                <key>NSExtensionActivationSupportsText</key>
                <true/>
                <key>NSExtensionActivationSupportsWebURLWithMaxCount</key>
                <integer>1</integer>
            </dict>
        </dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.share-services</string>
        <key>NSExtensionPrincipalClass</key>
        <string>$(PRODUCT_MODULE_NAME).ShareViewController</string>
    </dict>
</dict>
</plist>
```

- [ ] **Step 3: Build extension target**

Run: `xcodebuild -project "Lumoria App.xcodeproj" -scheme "LumoriaShareImport" -destination "generic/platform=iOS Simulator" build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED (will fail on missing ShareViewController until Task 16 — verify Info.plist parses).

- [ ] **Step 4: Commit**

```bash
git add "LumoriaShareImport/Info.plist" "LumoriaShareImport/LumoriaShareImport.entitlements"
git commit -m "feat(share): activation Info.plist + entitlements"
```

---

## Task 15: Extension OCR helper

**Files:**
- Create: `LumoriaShareImport/SharePayloadOCR.swift`

- [ ] **Step 1: Write the OCR helper**

```swift
//
//  SharePayloadOCR.swift
//  LumoriaShareImport
//
//  Async wrapper around VNRecognizeTextRequest. Lives in the
//  extension target only because it imports UIKit (UIImage) — the
//  main app does not need it.
//

import Foundation
import Vision
import UIKit

enum SharePayloadOCR {

    /// Recognizes text in `image` and returns the recognized strings
    /// joined by newlines. Empty string when nothing is recognized.
    static func recognize(image: UIImage) async -> String {
        guard let cgImage = image.cgImage else { return "" }
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { req, _ in
                let observations = (req.results as? [VNRecognizedTextObservation]) ?? []
                let lines = observations.compactMap {
                    $0.topCandidates(1).first?.string
                }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = [
                "en-US", "fr-FR", "de-DE", "es-ES", "it-IT", "pt-BR",
                "nl-NL", "ja-JP", "zh-Hans",
            ]
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: "")
            }
        }
    }
}
```

- [ ] **Step 2: Confirm extension target membership only**

- [ ] **Step 3: Build extension target**

Run: `xcodebuild -project "Lumoria App.xcodeproj" -scheme "LumoriaShareImport" -destination "generic/platform=iOS Simulator" build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add "LumoriaShareImport/SharePayloadOCR.swift" "Lumoria App.xcodeproj/project.pbxproj"
git commit -m "feat(share): Vision OCR wrapper in extension target"
```

---

## Task 16: ShareViewController — UI shell + processing

**Files:**
- Create: `LumoriaShareImport/ShareViewController.swift`

- [ ] **Step 1: Write the controller**

```swift
//
//  ShareViewController.swift
//  LumoriaShareImport
//
//  Silent share-sheet handler that runs OCR + classification on the
//  shared payload (image/text/URL), writes the parsed result into
//  the App Group, and prompts the user to open Lumoria.
//

import UIKit
import os.log

private let extensionLog = OSLog(
    subsystem: "bearista.Lumoria-App.LumoriaShareImport",
    category: "import"
)

final class ShareViewController: UIViewController {

    private var didProcess = false

    private let statusLabel = UILabel()
    private let subtitleLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        statusLabel.text = "Reading…"
        statusLabel.textColor = .label
        statusLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.text = " "
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.font = .systemFont(ofSize: 15, weight: .regular)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(statusLabel)
        view.addSubview(subtitleLabel)
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -16),
            subtitleLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
        ])

        os_log("ShareViewController loaded", log: extensionLog, type: .default)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didProcess else { return }
        didProcess = true
        Task { await process() }
    }

    private func showSavedState(_ subtitle: String) {
        statusLabel.text = "Ready"
        subtitleLabel.text = subtitle
    }

    private func showErrorState(_ message: String) {
        statusLabel.text = "Couldn't read"
        subtitleLabel.text = message
    }

    private func finishAfterDelay(_ seconds: TimeInterval = 1.6) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    // MARK: - Processing

    private func process() async {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = item.attachments, !attachments.isEmpty else {
            os_log("no attachments", log: extensionLog, type: .default)
            showErrorState("Nothing to read.")
            finishAfterDelay()
            return
        }

        let payload = await loadPayload(from: attachments)
        guard !payload.text.isEmpty else {
            os_log("empty payload after extraction", log: extensionLog, type: .default)
            showErrorState("We couldn't find any ticket details.")
            finishAfterDelay()
            return
        }

        let classification = ShareCategoryClassifier.classify(text: payload.text)
        os_log(
            "classified: category=%{public}@ confidence=%.2f signals=%{public}@",
            log: extensionLog, type: .default,
            classification.category ?? "nil",
            classification.confidence,
            classification.signals.joined(separator: ",")
        )

        var flight: SharePlaneFields?
        var event: ShareConcertFields?
        switch classification.category {
        case "plane":
            flight = SharePlaneExtractor.extract(text: payload.text)
        case "concert":
            event = ShareConcertExtractor.extract(text: payload.text)
        default:
            break
        }

        let result = ShareImportResult(
            classification: classification,
            flight: flight,
            event: event,
            payload: payload
        )

        do {
            _ = try SharePayloadHandoff.writePending(result)
            os_log("wrote pending share JSON", log: extensionLog, type: .default)
            let subtitle: String
            switch classification.category {
            case "plane":   subtitle = "Open Lumoria to finish your plane ticket."
            case "concert": subtitle = "Open Lumoria to finish your concert ticket."
            default:        subtitle = "Open Lumoria to pick a category."
            }
            showSavedState(subtitle)
            finishAfterDelay(1.6)
        } catch {
            os_log("write failed: %{public}@", log: extensionLog, type: .error,
                   String(describing: error))
            showErrorState("Couldn't stage your ticket for import.")
            finishAfterDelay()
        }
    }

    // MARK: - Payload extraction

    private func loadPayload(from providers: [NSItemProvider]) async -> SharePayload {
        var combinedText = ""
        var imageData: Data?
        var sourceURL: URL?

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.image") {
                if let image = await loadImage(from: provider) {
                    let recognized = await SharePayloadOCR.recognize(image: image)
                    combinedText.appendLine(recognized)
                    if let png = image.pngData() {
                        imageData = png
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier("public.plain-text") ||
                      provider.hasItemConformingToTypeIdentifier("public.text") {
                if let text = await loadText(from: provider) {
                    combinedText.appendLine(text)
                }
            } else if provider.hasItemConformingToTypeIdentifier("public.url") {
                if let url = await loadURL(from: provider) {
                    sourceURL = url
                    combinedText.appendLine(url.absoluteString)
                }
            }
        }

        return SharePayload(
            text: combinedText.trimmingCharacters(in: .whitespacesAndNewlines),
            image: imageData,
            sourceURL: sourceURL
        )
    }

    private func loadImage(from provider: NSItemProvider) async -> UIImage? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: "public.image", options: nil) { item, _ in
                if let url = item as? URL,
                   let data = try? Data(contentsOf: url),
                   let image = UIImage(data: data) {
                    continuation.resume(returning: image)
                } else if let image = item as? UIImage {
                    continuation.resume(returning: image)
                } else if let data = item as? Data,
                          let image = UIImage(data: data) {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func loadText(from provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { item, _ in
                continuation.resume(returning: item as? String)
            }
        }
    }

    private func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: "public.url", options: nil) { item, _ in
                continuation.resume(returning: item as? URL)
            }
        }
    }
}

private extension String {
    mutating func appendLine(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !isEmpty { append("\n") }
        append(trimmed)
    }
}
```

- [ ] **Step 2: Confirm extension target membership only**

- [ ] **Step 3: Build extension target**

Run: `xcodebuild -project "Lumoria App.xcodeproj" -scheme "LumoriaShareImport" -destination "generic/platform=iOS Simulator" build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add "LumoriaShareImport/ShareViewController.swift" "Lumoria App.xcodeproj/project.pbxproj"
git commit -m "feat(share): ShareViewController — extract+classify+handoff"
```

---

## Task 17: Drain handler in main app

**Files:**
- Modify: `Lumoria App/Lumoria_AppApp.swift`

- [ ] **Step 1: Inject the new coordinator**

Find `@StateObject private var walletImport = WalletImportCoordinator()` (around line 28). Below it, add:

```swift
    @StateObject private var shareImport = ShareImportCoordinator()
```

- [ ] **Step 2: Inject into the environment**

Find the `.environmentObject(walletImport)` chain in `body`'s `ContentView` modifiers (around line 95). Below it, add:

```swift
                        .environmentObject(shareImport)
```

- [ ] **Step 3: Add a drain method**

Below the existing `drainPendingWalletImport()` method (around line 161–182), add:

```swift
    /// Mirror of `drainPendingWalletImport` for the share extension's
    /// pending-share.json sentinel.
    private func drainPendingShareImport() {
        guard let result = SharePayloadHandoff.drainPending() else {
            return
        }
        NSLog("[Lumoria] drain: enqueued share import (category=%@, conf=%.2f)",
              result.classification.category ?? "nil",
              result.classification.confidence)
        shareImport.enqueue(result)
    }
```

- [ ] **Step 4: Call drain from `.active`**

Find the `.onChange(of: scenePhase, initial: true)` block (around line 143–151). In the `case .active:` branch, after `drainPendingWalletImport()`, add:

```swift
                    drainPendingShareImport()
```

- [ ] **Step 5: Add URL scheme route (belt-and-braces)**

In `handleIncomingURL(_:)` (around line 201), after the existing `isImportUniversal`/`isImportCustom` block for pkpass (around line 244), add:

```swift
        let isShareUniversal = url.scheme?.lowercased() == "https"
            && normalizedHost == "getlumoria.app"
            && url.path.lowercased() == "/import/share"
        let isShareCustom = url.scheme == "lumoria"
            && url.host == "import"
            && url.path == "/share"
        if isShareUniversal || isShareCustom {
            drainPendingShareImport()
            return
        }
```

- [ ] **Step 6: Build to verify**

Expected: BUILD SUCCEEDED.

- [ ] **Step 7: Commit**

```bash
git add "Lumoria App/Lumoria_AppApp.swift"
git commit -m "feat(share): drain pending share imports on .active"
```

---

## Task 18: AllTicketsView — present funnel for share import

**Files:**
- Modify: `Lumoria App/views/tickets/AllTicketsView.swift`

- [ ] **Step 1: Read the existing wallet trigger**

Run: `grep -n "walletImport\|WalletImportCoordinator\|pendingPassData" "Lumoria App/views/tickets/AllTicketsView.swift"`
Note: the variable names of the funnel-presentation state, what view modifier observes `walletImport.pending`, and how it sets `funnel.importSource = .wallet`.

- [ ] **Step 2: Add an `@EnvironmentObject` for ShareImportCoordinator**

Near `@EnvironmentObject private var walletImport: WalletImportCoordinator`, add:

```swift
    @EnvironmentObject private var shareImport: ShareImportCoordinator
```

- [ ] **Step 3: Add an `onChange(of: shareImport.pending)` handler**

Mirror the existing wallet pattern. The handler should:
- Consume the result via `shareImport.consume()`.
- Build a fresh `NewTicketFunnel`.
- Set `importSource = .share`, `pendingShareImport = result`.
- Translate `result.classification.category` (String?) → `TicketCategory?` via `ShareImportTranslator.category(from:)`.
- If category present → set `funnel.category = ...` and `funnel.step = .template`.
- If category nil → leave category and `step = .category`.
- Trigger funnel presentation using whatever pattern the wallet path uses.

```swift
        .onChange(of: shareImport.pending) { _, newValue in
            guard let result = shareImport.consume() else { return }
            let f = NewTicketFunnel()
            f.importSource = .share
            f.pendingShareImport = result
            if let category = ShareImportTranslator.category(from: result.classification.category) {
                f.category = category
                f.step = .template
            } else {
                f.step = .category
            }
            // TODO: replace with the actual presentation trigger used
            // by the wallet path discovered in Step 1.
            funnelToPresent = f
            isFunnelPresented = true
        }
```

- [ ] **Step 4: Build to verify**

Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add "Lumoria App/views/tickets/AllTicketsView.swift"
git commit -m "feat(share): present funnel when share import lands"
```

---

## Task 19: Run full test suite

- [ ] **Step 1: Run all tests**

Run: `xcodebuild -project "Lumoria App.xcodeproj" -scheme "Lumoria App" -destination "platform=iOS Simulator,name=iPhone 17 Pro" test 2>&1 | tail -40`
Expected: All tests passed.

- [ ] **Step 2: Fix any failures and repeat**

---

## Task 20: End-to-end smoke test on simulator

Manual.

- [ ] **Step 1: Run main app on simulator**

Xcode → `Lumoria App` scheme → iPhone 17 Pro → Run (⌘R).

- [ ] **Step 2: Stage a sample plane image**

Drag a confirmation email screenshot into Photos (or paste this text into a `.txt` file in Files):

```
Your United flight is confirmed.
UA 1471 — SFO → JFK
Departing Tue, May 14, 6:30 AM
Gate B22 · Seat 14C · Terminal 3
```

- [ ] **Step 3: Share → Lumoria**

In Photos / Files: tap Share → "Lumoria" (you may need to scroll horizontally and "More…" → enable Lumoria).

Expected: extension shows "Reading…" → "Ready · Open Lumoria to finish your plane ticket." → auto-dismisses.

- [ ] **Step 4: Open Lumoria**

Funnel auto-presents with category = Plane, on Template step. Pick a template → Form pre-filled with flight number, IATA codes, gate, seat.

- [ ] **Step 5: Repeat with concert text**

```
Your Ticketmaster order is confirmed.
Taylor Swift — The Eras Tour
Stade de France, Saint-Denis
June 7, 2026 · Doors 6:00 PM · Show 7:30 PM
Section 134, Row 22, Seat 14
Order #: 18-12345/PAR
```

Expected: funnel with Concert category, pre-fills artist/tour/venue/order.

- [ ] **Step 6: Test the unclassified path**

Share unrelated text. Expected: extension says "Open Lumoria to pick a category." → Lumoria opens funnel at Category step.

- [ ] **Step 7: Add changelog entry**

Per project memory `feedback_changelog_mdx.md`, add `lumoria/src/content/changelog/2026-05-01-share-extension.mdx` with JS-export frontmatter.

```bash
git add lumoria/src/content/changelog/2026-05-01-share-extension.mdx
git commit -m "docs(changelog): share extension shipped"
```

---

## Open follow-ups (post-v1)

- Movie / restaurant / train / public-transit categories
- URL fetch with `<title>` and meta tags
- Multi-ticket detection
- Telemetry — log classifier signals + confidence + final user category choice (opt-in)

---

## Self-review notes

- **Cross-target safety:** All shared files (`SharePayload`, `ShareCategoryClassifier`, `SharePlaneExtractor`, `ShareConcertExtractor`, `SharePayloadHandoff`) use primitive types only. Nothing in those files references `TicketCategory`, `FlightFormInput`, `EventFormInput`, `Airline`, or `TicketLocation`. The extension target compiles without linking `NewTicketFunnel.swift`. The translator (`ShareImportTranslator`) lives in the main app target only.
- **Spec coverage:** v1 (plane + concert) covered by Tasks 2–7 + 11. Hand-off in Tasks 8–9. Coordinator + funnel in Task 12. ImportStep branching in Task 13. Extension target in Tasks 14–16. Main app pickup in Tasks 17–18. Verification in Tasks 19–20.
- **Type consistency:** `ShareImportResult.flight` is `SharePlaneFields?` everywhere. `classification.category` is `String?` in the wire format and translated to `TicketCategory?` only in main app code.
- **No LLM:** classifier + extractors use regex, keyword tables, `NSDataDetector`, `NLTagger`. Extension uses `VNRecognizeTextRequest`. No Foundation Models, no cloud.
