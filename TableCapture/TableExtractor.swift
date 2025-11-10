//
//  TableExtractor.swift
//  TableCapture
//
//  Protocol-based table extraction system that supports multiple backends
//

import Foundation
import AppKit

/// Output format for extracted tables
enum TableFormat {
    case csv
    case markdown
}

/// Protocol for table extraction backends
protocol TableExtractor {
    /// Extract table from image at the given URL
    /// - Parameters:
    ///   - imageURL: URL to the image file
    ///   - format: Desired output format
    ///   - completion: Callback with extracted table text or error
    func extractTable(from imageURL: URL, format: TableFormat, completion: @escaping (Result<String, Error>) -> Void)
}

/// Errors that can occur during table extraction
enum TableExtractionError: LocalizedError {
    case extractionFailed(String)
    case noOutput

    var errorDescription: String? {
        switch self {
        case .extractionFailed(let message):
            return "Table extraction failed: \(message)"
        case .noOutput:
            return "No table data extracted from image"
        }
    }
}

// MARK: - Apple Vision Extractor

import Vision
import AppKit

/// Apple Vision-based table extractor using native macOS OCR
/// No external dependencies required
class AppleVisionExtractor: TableExtractor {

    func extractTable(from imageURL: URL, format: TableFormat, completion: @escaping (Result<String, Error>) -> Void) {
        // Load image
        guard let image = NSImage(contentsOf: imageURL),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            completion(.failure(TableExtractionError.extractionFailed("Failed to load image")))
            return
        }

        // Create Vision text recognition request
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation], !observations.isEmpty else {
                completion(.failure(TableExtractionError.noOutput))
                return
            }

            // Extract and structure the table
            let table = self.buildTableStructure(from: observations)

            // Format output
            let output: String
            switch format {
            case .csv:
                output = self.formatAsCSV(table)
            case .markdown:
                output = self.formatAsMarkdown(table)
            }

            completion(.success(output))
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        // Perform OCR
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            completion(.failure(error))
        }
    }

    // MARK: - Table Structure Detection

    private struct TextCell {
        let text: String
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
    }

    private func buildTableStructure(from observations: [VNRecognizedTextObservation]) -> [[String]] {
        // Extract text with positions
        var cells: [TextCell] = []

        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }

            let bounds = observation.boundingBox
            cells.append(TextCell(
                text: topCandidate.string,
                x: bounds.origin.x,
                y: bounds.origin.y,
                width: bounds.width,
                height: bounds.height
            ))
        }

        // Sort by Y (top to bottom) - Vision uses bottom-left origin
        cells.sort { $0.y > $1.y }

        // Group cells into rows based on Y coordinate proximity
        var rows: [[TextCell]] = []
        var currentRow: [TextCell] = []
        var lastY: CGFloat?

        let rowThreshold: CGFloat = 0.015  // 1.5% of image height tolerance for same row

        for cell in cells {
            if let prevY = lastY {
                let yDiff = abs(cell.y - prevY)

                if yDiff < rowThreshold {
                    // Same row
                    currentRow.append(cell)
                } else {
                    // New row
                    if !currentRow.isEmpty {
                        rows.append(currentRow)
                    }
                    currentRow = [cell]
                }
            } else {
                // First cell
                currentRow = [cell]
            }

            lastY = cell.y
        }

        // Add last row
        if !currentRow.isEmpty {
            rows.append(currentRow)
        }

        // Sort cells within each row by X coordinate (left to right)
        var table: [[String]] = []
        for row in rows {
            let sortedRow = row.sorted { $0.x < $1.x }
            table.append(sortedRow.map { $0.text })
        }

        return table
    }

    // MARK: - Output Formatting

    private func formatAsCSV(_ table: [[String]]) -> String {
        var lines: [String] = []

        for row in table {
            // Escape cells containing commas or quotes
            let escapedRow = row.map { cell -> String in
                if cell.contains(",") || cell.contains("\"") || cell.contains("\n") {
                    let escaped = cell.replacingOccurrences(of: "\"", with: "\"\"")
                    return "\"\(escaped)\""
                }
                return cell
            }
            lines.append(escapedRow.joined(separator: ","))
        }

        return lines.joined(separator: "\n")
    }

    private func formatAsMarkdown(_ table: [[String]]) -> String {
        guard !table.isEmpty else { return "" }

        var lines: [String] = []

        // Determine column count
        let columnCount = table.map { $0.count }.max() ?? 0

        // Format each row
        for (index, row) in table.enumerated() {
            // Pad row to match column count
            var paddedRow = row
            while paddedRow.count < columnCount {
                paddedRow.append("")
            }

            // Escape pipes in cells
            let escapedRow = paddedRow.map { $0.replacingOccurrences(of: "|", with: "\\|") }
            lines.append("| " + escapedRow.joined(separator: " | ") + " |")

            // Add separator after header row
            if index == 0 {
                let separator = "| " + Array(repeating: "---", count: columnCount).joined(separator: " | ") + " |"
                lines.append(separator)
            }
        }

        return lines.joined(separator: "\n")
    }
}
