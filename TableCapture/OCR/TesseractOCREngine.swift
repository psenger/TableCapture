//
//  TesseractOCREngine.swift
//  TableCapture
//
//  Tesseract OCR engine implementation
//

import Foundation
import AppKit

/// OCR engine using Tesseract for text recognition
class TesseractOCREngine: CellOCREngine {
    private let tesseract: SLTesseract
    var preserveMultilineFormatting: Bool

    var name: String {
        return "Tesseract"
    }

    /// Initialize Tesseract OCR engine
    /// - Parameter preserveMultilineFormatting: If true, preserve newlines in extracted text; if false, join lines with spaces
    init(preserveMultilineFormatting: Bool = false) {
        self.tesseract = SLTesseract()
        self.tesseract.language = "eng"
        self.preserveMultilineFormatting = preserveMultilineFormatting
    }

    func recognizeText(in image: NSImage) -> String? {
        let recognizedText = tesseract.recognize(image)

        guard let text = recognizedText, !text.isEmpty else {
            return nil
        }

        // Handle multi-line formatting
        if preserveMultilineFormatting {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            // Join lines with space
            return text
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }
    }
}
