//
//  TwoColumnSingleLetterTests.swift
//  TableCaptureTests
//
//  Tests for two-column tables with single letters (challenging for OCR)
//

import Testing
import Foundation
import AppKit
@testable import TableCapture

// MARK: - Two-Column Single Letter Tests

struct TwoColumnSingleLetterTests {

    // Two-column single-row test with SINGLE LETTERS
    // Column 1: A, C, E (3 lines), Column 2: B, D (2 lines)
    static let twoColumnLetters = TableTestCase(
        imageName: "two-column-multiline-letters",
        verticalLines: [0.5],        // One vertical line at 50% (middle)
        horizontalLines: [],         // No horizontal lines - single row
        expectedCSV: "A C E,B D",    // Single letters merged with spaces
        expectedMarkdown: """
        | A C E | B D |
        | --- | --- |
        """
    )

    @Test("Two-column single letters - CSV extraction")
    func testTwoColumnLettersCSV() async throws {
        let result = try await runOCRTest(testCase: Self.twoColumnLetters, format: .csv)

        let normalizedResult = result.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedExpected = Self.twoColumnLetters.expectedCSV.trimmingCharacters(in: .whitespacesAndNewlines)

        print("Got: '\(normalizedResult)'")
        print("Expected: '\(normalizedExpected)'")

        #expect(normalizedResult == normalizedExpected,
                "CSV output doesn't match expected.\nGot:\n\(result)\n\nExpected:\n\(Self.twoColumnLetters.expectedCSV)")
    }

    @Test("Two-column single letters - Markdown extraction")
    func testTwoColumnLettersMarkdown() async throws {
        let result = try await runOCRTest(testCase: Self.twoColumnLetters, format: .markdown)

        let normalizedResult = result.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedExpected = Self.twoColumnLetters.expectedMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)

        #expect(normalizedResult == normalizedExpected,
                "Markdown output doesn't match expected.\nGot:\n\(result)\n\nExpected:\n\(Self.twoColumnLetters.expectedMarkdown)")
    }

    @Test("Two-column single letters - Debug output")
    @MainActor
    func debugTwoColumnLetters() async throws {
        let image = try loadTestImage(named: Self.twoColumnLetters.imageName)
        let viewModel = TableEditorViewModel(image: image, autoDetectGrid: false)

        viewModel.verticalLines = Self.twoColumnLetters.verticalLines
        viewModel.horizontalLines = Self.twoColumnLetters.horizontalLines

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
        TWO-COLUMN SINGLE LETTERS OCR EXTRACTION
        ========================================
        Image: \(Self.twoColumnLetters.imageName)
        Grid: 2 columns, 1 row
        Vertical Lines: \(Self.twoColumnLetters.verticalLines)
        Horizontal Lines: \(Self.twoColumnLetters.horizontalLines)

        Expected Layout:
        Column 1: A, C, E (3 lines)
        Column 2: B, D (2 lines)

        ----------------------------------------
        CSV OUTPUT:
        ----------------------------------------
        \(csvResult)

        ----------------------------------------
        CSV EXPECTED:
        ----------------------------------------
        \(Self.twoColumnLetters.expectedCSV)

        ----------------------------------------
        MARKDOWN OUTPUT:
        ----------------------------------------
        \(markdownResult)

        ----------------------------------------
        MARKDOWN EXPECTED:
        ----------------------------------------
        \(Self.twoColumnLetters.expectedMarkdown)

        ----------------------------------------
        CHARACTER COMPARISON:
        ----------------------------------------
        CSV Output bytes: \(csvResult.utf8.map { String(format: "%02X", $0) }.joined(separator: " "))
        CSV Expected bytes: \(Self.twoColumnLetters.expectedCSV.utf8.map { String(format: "%02X", $0) }.joined(separator: " "))
        ========================================

        """)
    }
}
