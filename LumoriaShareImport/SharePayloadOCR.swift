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
