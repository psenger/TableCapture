//
//  VisionOCREngine.swift
//  TableCapture
//
//  Apple Vision OCR engine implementation
//

import Foundation
import AppKit
import Vision

/// OCR engine using Apple's Vision framework for text recognition
class VisionOCREngine: CellOCREngine {
    var preserveMultilineFormatting: Bool
    private let recognitionLevel: VNRequestTextRecognitionLevel
    private let usesLanguageCorrection: Bool

    var name: String {
        return "Apple Vision"
    }

    /// Initialize Vision OCR engine
    /// - Parameters:
    ///   - preserveMultilineFormatting: If true, preserve newlines in extracted text; if false, join lines with spaces
    ///   - recognitionLevel: Recognition accuracy level (.fast or .accurate)
    ///   - usesLanguageCorrection: Whether to use language correction for better accuracy
    init(preserveMultilineFormatting: Bool = false,
         recognitionLevel: VNRequestTextRecognitionLevel = .accurate,
         usesLanguageCorrection: Bool = true) {
        self.preserveMultilineFormatting = preserveMultilineFormatting
        self.recognitionLevel = recognitionLevel
        self.usesLanguageCorrection = usesLanguageCorrection
    }

    func recognizeText(in image: NSImage) -> String? {
        // Convert to CGImage for Vision
        guard let cellCGImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        var extractedText: String?
        let semaphore = DispatchSemaphore(value: 0)

        // Create Vision request for this cell
        let request = VNRecognizeTextRequest { request, error in
            defer { semaphore.signal() }

            if error != nil {
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                return
            }

            // Extract all text from this cell and sort by Y position (top to bottom)
            var cellTexts: [(String, CGFloat)] = []
            for observation in observations {
                if let text = observation.topCandidates(1).first?.string {
                    cellTexts.append((text, observation.boundingBox.origin.y))
                }
            }

            // Sort by Y position (top to bottom)
            cellTexts.sort { $0.1 > $1.1 }

            // Join with newline if preserving multi-line formatting, otherwise with space
            let separator = self.preserveMultilineFormatting ? "\n" : " "
            let cellText = cellTexts.map { $0.0 }.joined(separator: separator)

            if !cellText.isEmpty {
                extractedText = cellText
            }
        }

        // Configure request
        request.recognitionLevel = recognitionLevel
        request.usesLanguageCorrection = usesLanguageCorrection
        request.automaticallyDetectsLanguage = true

        // Allow recognition of single characters and short strings
        if #available(macOS 13.0, *) {
            request.minimumTextHeight = 0.0
        }

        let handler = VNImageRequestHandler(cgImage: cellCGImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        // Wait for Vision request to complete
        semaphore.wait()

        return extractedText
    }
}
