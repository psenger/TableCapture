//
//  SingleLetterTests.swift
//  TableCaptureTests
//
//  Tests for single-letter recognition (challenging for OCR)
//

import Testing
import Foundation
import AppKit
@testable import TableCapture

// MARK: - Single Letter Tests

struct SingleLetterTests {

    // Two-column single-row test with SINGLE LETTERS
    // Column 1: A, C, E (3 lines), Column 2: B, D (2 lines)
    static let singleLetters = TableTestCase(
        imageName: "single-letters",
        verticalLines: [],        // One vertical line at 50% (middle)
        horizontalLines: [],         // No horizontal lines - single row
        expectedCSV: "\"Z\"",    // Single letters merged with spaces
        expectedMarkdown: """
        | Z |
        | --- |
        """
    )

    @Test("Single letters - CSV extraction")
    func testSingleLettersCSV() async throws {
        let result = try await runOCRTest(testCase: Self.singleLetters, format: .csv, testName: "SingleLetters")

        let normalizedResult = result.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedExpected = Self.singleLetters.expectedCSV.trimmingCharacters(in: .whitespacesAndNewlines)

        print("Got: '\(normalizedResult)'")
        print("Expected: '\(normalizedExpected)'")

        #expect(normalizedResult == normalizedExpected,
                "CSV output doesn't match expected.\nGot:\n\(result)\n\nExpected:\n\(Self.singleLetters.expectedCSV)")
    }

    @Test("Single letters - Debug output")
    @MainActor
    func debugSingleLetters() async throws {
        let image = try loadTestImage(named: Self.singleLetters.imageName)
        let viewModel = TableEditorViewModel(image: image, autoDetectGrid: false, testName: "SingleLetters")

        viewModel.verticalLines = Self.singleLetters.verticalLines
        viewModel.horizontalLines = Self.singleLetters.horizontalLines

        let csvResult = try await withCheckedThrowingContinuation { continuation in
            viewModel.extractTable(format: .csv) { result in
                continuation.resume(with: result)
            }
        }

        print("""

        ========================================
        SINGLE LETTERS OCR EXTRACTION
        ========================================
        Image: \(Self.singleLetters.imageName)
        Grid: 2 columns, 1 row
        Expected: A C E (left), B D (right)

        CSV Output:
        \(csvResult)

        Expected:
        \(Self.singleLetters.expectedCSV)
        ========================================

        """)
    }
}
