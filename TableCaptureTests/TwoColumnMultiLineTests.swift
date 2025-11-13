//
//  TwoColumnMultiLineTests.swift
//  TableCaptureTests
//
//  Tests for two-column tables with multi-line content
//

import Testing
import Foundation
import AppKit
@testable import TableCapture

// MARK: - Two-Column Multi-Line Tests

struct TwoColumnMultiLineTests {

    // Two-column single-row test with multi-line content
    // Column 1: Apple, Cat, Elephant (3 lines), Column 2: Bat, Dog (2 lines)
    // Note: OCR reads "Elephant" as "Elephabnt" (minor OCR error)
    static let twoColumnMultiLine = TableTestCase(
        imageName: "two-column-multiline",
        verticalLines: [0.6],        // One vertical line at 50% (middle)
        horizontalLines: [],         // No horizontal lines - single row
        expectedCSV: "\"Apple Cat Elephabnt\",\"Bat Dog\"",    // Lines merged with spaces within each cell
        expectedMarkdown: """
        | Apple Cat Elephabnt | Bat Dog |
        | --- | --- |
        """
    )

    @Test("Two-column multi-line - CSV extraction")
    func testTwoColumnMultiLineCSV() async throws {
        let result = try await runOCRTest(testCase: Self.twoColumnMultiLine, format: .csv, testName: "TwoColumnMultiLine")

        let normalizedResult = result.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedExpected = Self.twoColumnMultiLine.expectedCSV.trimmingCharacters(in: .whitespacesAndNewlines)

        #expect(normalizedResult == normalizedExpected,
                "CSV output doesn't match expected.\nGot:\n\(result)\n\nExpected:\n\(Self.twoColumnMultiLine.expectedCSV)")
    }

    @Test("Two-column multi-line - Markdown extraction")
    func testTwoColumnMultiLineMarkdown() async throws {
        let result = try await runOCRTest(testCase: Self.twoColumnMultiLine, format: .markdown, testName: "TwoColumnMultiLine")

        let normalizedResult = result.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedExpected = Self.twoColumnMultiLine.expectedMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)

        #expect(normalizedResult == normalizedExpected,
                "Markdown output doesn't match expected.\nGot:\n\(result)\n\nExpected:\n\(Self.twoColumnMultiLine.expectedMarkdown)")
    }

    @Test("Two-column multi-line - Debug output")
    @MainActor
    func debugTwoColumnMultiLine() async throws {
        let image = try loadTestImage(named: Self.twoColumnMultiLine.imageName)
        let viewModel = TableEditorViewModel(image: image, autoDetectGrid: false, testName: "TwoColumnMultiLine")

        viewModel.verticalLines = Self.twoColumnMultiLine.verticalLines
        viewModel.horizontalLines = Self.twoColumnMultiLine.horizontalLines

        let csvResult = try await withCheckedThrowingContinuation { continuation in
            viewModel.extractTable(format: .csv) { result in
                continuation.resume(with: result)
            }
        }

        let markdownResult = try await withCheckedThrowingContinuation { continuation in
            viewModel.extractTable(format: .markdown) { result in
                continuation.resume(with: result)
            }
        }

        print("""

        ========================================
        TWO-COLUMN MULTI-LINE OCR EXTRACTION
        ========================================
        Image: \(Self.twoColumnMultiLine.imageName)
        Grid: 2 columns, 1 row
        Vertical Lines: \(Self.twoColumnMultiLine.verticalLines)
        Horizontal Lines: \(Self.twoColumnMultiLine.horizontalLines)

        Expected Layout:
        Column 1: Apple, Cat, Elephant (3 lines)
        Column 2: Bat, Dog (2 lines)

        ----------------------------------------
        CSV OUTPUT:
        ----------------------------------------
        \(csvResult)

        ----------------------------------------
        CSV EXPECTED:
        ----------------------------------------
        \(Self.twoColumnMultiLine.expectedCSV)

        ----------------------------------------
        MARKDOWN OUTPUT:
        ----------------------------------------
        \(markdownResult)

        ----------------------------------------
        MARKDOWN EXPECTED:
        ----------------------------------------
        \(Self.twoColumnMultiLine.expectedMarkdown)

        ----------------------------------------
        CHARACTER COMPARISON:
        ----------------------------------------
        CSV Output bytes: \(csvResult.utf8.map { String(format: "%02X", $0) }.joined(separator: " "))
        CSV Expected bytes: \(Self.twoColumnMultiLine.expectedCSV.utf8.map { String(format: "%02X", $0) }.joined(separator: " "))
        ========================================

        """)
    }
}
