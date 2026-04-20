//
//  TicketImportService.swift
//  Lumoria App
//
//  Coordinator for ticket-import sources (Apple Wallet `.pkpass` today;
//  PDF and email deferred). Parsers return a typed `ImportResult` that
//  the funnel applies straight onto `FlightFormInput` / `TrainFormInput`.
//

import Foundation

// MARK: - Result

/// Outcome of a successful parse. Carries a prefilled form struct the
/// funnel can swap in as-is — every importer is responsible for
/// matching the selected template's shape.
enum ImportResult {
    case flight(FlightFormInput)
    case train(TrainFormInput)
}

// MARK: - Transit type (pass.json)

/// Transit type declared on a boarding pass. Bus / boat / generic
/// collapse into `.other` — we don't have first-class templates for
/// them and fall back to train-style fields.
enum TransitKind: String {
    case air
    case train
    case other
}

// MARK: - Errors

enum ImportError: Error, LocalizedError {
    case unreadable
    case notBoardingPass
    case kindMismatch(expected: TicketTemplateKind, detected: TransitKind)
    case emptyExtraction

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return String(localized: "We couldn’t read that pass.")
        case .notBoardingPass:
            return String(localized: "This pass isn’t a boarding pass.")
        case .kindMismatch:
            return String(localized: "This pass doesn’t match the selected template.")
        case .emptyExtraction:
            return String(localized: "No details found in this pass.")
        }
    }
}

// MARK: - Coordinator

enum TicketImportService {

    /// Parses an Apple Wallet `.pkpass` into a ready-to-apply
    /// `ImportResult`. The template informs transit-type enforcement:
    /// air templates reject rail passes and vice versa, so the user
    /// lands back on the importer with a clear error.
    static func importPKPass(
        data: Data,
        template: TicketTemplateKind
    ) throws -> ImportResult {
        try PKPassImporter.parse(data: data, template: template)
    }
}
