//
//  SimpleSingleCellTests.swift
//  TableCaptureTests
//
//  Tests for simple single-cell OCR (baseline tests)
//

import Testing
import Foundation
import AppKit
@testable import TableCapture

// MARK: - Simple Single-Cell Tests

struct SimpleSingleCellTests {

    // Simple single-cell test (baseline OCR test)
    static let simpleHello = TableTestCase(
        imageName: "simple-hello",
        verticalLines: [],           // No grid lines - just one cell
        horizontalLines: [],         // No grid lines - just one cell
        expectedCSV: "Hello",
        expectedMarkdown: """
        | Hello |
        | --- |
        """
    )

    @Test("Simple single cell - CSV extraction")
    func testSimpleHelloCSV() async throws {
        print("\n🧪 Testing simple-hello through production code path...")
        let result = try await runOCRTest(testCase: Self.simpleHello, format: .csv)
        print("Result from production path: '\(result)'")

        let normalizedResult = result.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedExpected = Self.simpleHello.expectedCSV.trimmingCharacters(in: .whitespacesAndNewlines)

        #expect(normalizedResult == normalizedExpected,
                "CSV output doesn't match expected.\nGot:\n\(result)\n\nExpected:\n\(Self.simpleHello.expectedCSV)")
    }

    @Test("Simple single cell - Markdown extraction")
    func testSimpleHelloMarkdown() async throws {
        let result = try await runOCRTest(testCase: Self.simpleHello, format: .markdown)

        let normalizedResult = result.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedExpected = Self.simpleHello.expectedMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)

        #expect(normalizedResult == normalizedExpected,
                "Markdown output doesn't match expected.\nGot:\n\(result)\n\nExpected:\n\(Self.simpleHello.expectedMarkdown)")
    }

    @Test("Simple single cell - Debug output")
    @MainActor
    func debugSimpleHello() async throws {
        let image = try loadTestImage(named: Self.simpleHello.imageName)
        let viewModel = TableEditorViewModel(image: image, autoDetectGrid: false)

        viewModel.verticalLines = Self.simpleHello.verticalLines
        viewModel.horizontalLines = Self.simpleHello.horizontalLines

        let csvResult = try await withCheckedThrowingContinuation { continuation in
            viewModel.extractTable(format: .csv) { result in
                continuation.resume(with: result)
            }
        }

        print("""

        ========================================
        SIMPLE HELLO OCR EXTRACTION (BASELINE)
        ========================================
        Image: \(Self.simpleHello.imageName)
        Grid: Single cell (no dividers)

        CSV Output:
        \(csvResult)

        Expected:
        \(Self.simpleHello.expectedCSV)
        ========================================

        """)
    }
}
