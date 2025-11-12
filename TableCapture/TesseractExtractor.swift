//
//  TesseractExtractor.swift
//  TableCapture
//
//  Tesseract OCR-based table extractor for single-character recognition
//  Used as fallback when Apple Vision fails to detect text
//

import Foundation
import AppKit

/// Tesseract OCR-based table extractor
/// Falls back to Tesseract when Vision returns no results (e.g., single letters)
class TesseractExtractor: TableExtractor {

    func extractTable(from imageURL: URL, format: TableFormat, completion: @escaping (Result<String, Error>) -> Void) {
        // Load image
        guard let image = NSImage(contentsOf: imageURL) else {
            completion(.failure(TableExtractionError.extractionFailed("Failed to load image")))
            return
        }

        // Initialize Tesseract
        let tesseract = SLTesseract()
        tesseract.language = "eng"

        // Optional: Configure character whitelist if needed
        // tesseract.charWhitelist = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 "

        // Perform OCR
        guard let recognizedText = tesseract.recognize(image), !recognizedText.isEmpty else {
            completion(.failure(TableExtractionError.noOutput))
            return
        }

        print("🔍 Tesseract OCR result:")
        print(recognizedText)

        // Simple processing - Tesseract returns text with newlines
        // For now, just return the raw text formatted appropriately
        let output: String
        switch format {
        case .csv:
            // Split by lines, treat as rows
            let lines = recognizedText.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            output = lines.joined(separator: "\n")
        case .markdown:
            // Format as single-column markdown table
            let lines = recognizedText.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            if lines.isEmpty {
                output = ""
            } else {
                var md = "| " + lines[0] + " |\n"
                md += "| --- |\n"
                for line in lines.dropFirst() {
                    md += "| " + line + " |\n"
                }
                output = md.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        completion(.success(output))
    }
}
