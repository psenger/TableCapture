//
//  MultiLineSingleCellTests.swift
//  TableCaptureTests
//
//  Tests for multi-line single-cell OCR
//

import Testing
import Foundation
import AppKit
@testable import TableCapture

// MARK: - Multi-Line Single-Cell Tests

struct MultiLineSingleCellTests {

    // Multi-line single-cell test (baseline OCR with line breaks)
    // Note: OCR will merge lines with a space since we can't determine line breaks from spatial positioning alone
    static let simpleHelloWorld = TableTestCase(
        imageName: "simple-hello-world",
        verticalLines: [],           // No grid lines - just one cell
        horizontalLines: [],         // No grid lines - just one cell
        expectedCSV: "\"hello world\"",  // Lines merged with space
        expectedMarkdown: """
        | hello world |
        | --- |
        """
    )

    @Test("Multi-line single cell - CSV extraction")
    func testSimpleHelloWorldCSV() async throws {
        let result = try await runOCRTest(testCase: Self.simpleHelloWorld, format: .csv, testName: "MultiLineSingleCell")

        let normalizedResult = result.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedExpected = Self.simpleHelloWorld.expectedCSV.trimmingCharacters(in: .whitespacesAndNewlines)

        #expect(normalizedResult == normalizedExpected,
                "CSV output doesn't match expected.\nGot:\n\(result)\n\nExpected:\n\(Self.simpleHelloWorld.expectedCSV)")
    }

    @Test("Multi-line single cell - Markdown extraction")
    func testSimpleHelloWorldMarkdown() async throws {
        let result = try await runOCRTest(testCase: Self.simpleHelloWorld, format: .markdown, testName: "MultiLineSingleCell")

        let normalizedResult = result.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedExpected = Self.simpleHelloWorld.expectedMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)

        #expect(normalizedResult == normalizedExpected,
                "Markdown output doesn't match expected.\nGot:\n\(result)\n\nExpected:\n\(Self.simpleHelloWorld.expectedMarkdown)")
    }

    @Test("Multi-line single cell - Debug output")
    @MainActor
    func debugSimpleHelloWorld() async throws {
        let image = try loadTestImage(named: Self.simpleHelloWorld.imageName)
        let viewModel = TableEditorViewModel(image: image, autoDetectGrid: false, testName: "MultiLineSingleCell")

        viewModel.verticalLines = Self.simpleHelloWorld.verticalLines
        viewModel.horizontalLines = Self.simpleHelloWorld.horizontalLines

        let csvResult = try await withCheckedThrowingContinuation { continuation in
            viewModel.extractTable(format: .csv) { result in
                continuation.resume(with: result)
            }
        }

        print("""

        ========================================
        MULTI-LINE HELLO WORLD OCR EXTRACTION
        ========================================
        Image: \(Self.simpleHelloWorld.imageName)
        Grid: Single cell (no dividers)
        Content: Two lines of text

        CSV Output:
        \(csvResult)

        Expected:
        \(Self.simpleHelloWorld.expectedCSV)
        ========================================

        """)
    }
}
