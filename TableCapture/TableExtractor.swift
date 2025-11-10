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
        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true

        // Perform text recognition
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([textRequest])
        } catch {
            completion(.failure(error))
            return
        }

        // Get results
        guard let textObservations = textRequest.results as? [VNRecognizedTextObservation], !textObservations.isEmpty else {
            completion(.failure(TableExtractionError.noOutput))
            return
        }

        // Extract and structure the table using improved column detection
        let table = self.buildTableStructure(from: textObservations)

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

    // MARK: - Table Structure Detection

    private struct TextCell {
        let text: String
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
        var column: Int? = nil
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
        
        // Step 1: Detect column boundaries by analyzing X positions
        let columnBoundaries = detectColumnBoundaries(from: cells)
        
        // Step 2: Assign each cell to a column
        for i in 0..<cells.count {
            let columnIndex = findColumn(for: cells[i].x, in: columnBoundaries)
            cells[i] = TextCell(
                text: cells[i].text,
                x: cells[i].x,
                y: cells[i].y,
                width: cells[i].width,
                height: cells[i].height,
                column: columnIndex
            )
        }
        
        // Step 3: Group into rows, merging cells in the same column that are close together
        return buildRowsWithMergedCells(cells: cells, columnCount: columnBoundaries.count)
    }
    
    // Detect where columns start by clustering X positions
    private func detectColumnBoundaries(from cells: [TextCell]) -> [CGFloat] {
        // Collect all X positions
        let xPositions = cells.map { $0.x }.sorted()
        
        guard !xPositions.isEmpty else { return [] }
        
        // Cluster X positions - positions within 5% are same column
        let threshold: CGFloat = 0.05
        var columns: [CGFloat] = [xPositions[0]]
        
        for x in xPositions {
            let lastColumn = columns.last!
            if abs(x - lastColumn) > threshold {
                columns.append(x)
            }
        }
        
        return columns
    }
    
    // Find which column this X position belongs to
    private func findColumn(for x: CGFloat, in boundaries: [CGFloat]) -> Int {
        for (index, boundary) in boundaries.enumerated() {
            if abs(x - boundary) < 0.05 { // 5% threshold
                return index
            }
        }
        // Return closest column
        let distances = boundaries.enumerated().map { (index, boundary) in
            (index, abs(x - boundary))
        }
        return distances.min(by: { $0.1 < $1.1 })?.0 ?? 0
    }
    
    // Build rows while merging cells that belong together (same column, vertically adjacent)
    private func buildRowsWithMergedCells(cells: [TextCell], columnCount: Int) -> [[String]] {
        guard !cells.isEmpty else { return [] }
        
        var rows: [[String]] = []
        var currentRowCells: [Int: String] = [:] // column index -> merged text
        var lastY: CGFloat = cells[0].y
        let rowThreshold: CGFloat = 0.02 // 2% threshold for same row
        
        for cell in cells {
            let yDiff = abs(cell.y - lastY)
            
            // If Y difference is small, it's likely part of the same logical row
            if yDiff < rowThreshold {
                // Merge text in the same column
                if let existingText = currentRowCells[cell.column ?? 0] {
                    currentRowCells[cell.column ?? 0] = existingText + " " + cell.text
                } else {
                    currentRowCells[cell.column ?? 0] = cell.text
                }
            } else {
                // New row - save the previous one
                if !currentRowCells.isEmpty {
                    rows.append(buildRowArray(from: currentRowCells, columnCount: columnCount))
                }
                
                // Start new row
                currentRowCells = [cell.column ?? 0: cell.text]
                lastY = cell.y
            }
        }
        
        // Add the last row
        if !currentRowCells.isEmpty {
            rows.append(buildRowArray(from: currentRowCells, columnCount: columnCount))
        }
        
        return rows
    }
    
    // Convert dictionary of column->text into array, filling gaps with empty strings
    private func buildRowArray(from cellDict: [Int: String], columnCount: Int) -> [String] {
        var row: [String] = []
        for i in 0..<columnCount {
            row.append(cellDict[i] ?? "")
        }
        return row
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
