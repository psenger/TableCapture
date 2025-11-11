//
//  TableCaptureTests.swift
//  TableCaptureTests
//
//  Created by Philip A Senger on 10/11/2025.
//

import Testing
import Foundation
import AppKit
@testable import TableCapture

struct TableCaptureTests {

    // MARK: - CSV Formatting Tests

    @Test("CSV escaping with commas")
    @MainActor
    func testCSVEscapingCommas() async throws {
        let viewModel = TableEditorViewModel(image: createTestImage(), autoDetectGrid: false)
        let table = [["Name", "Age"], ["John, Jr.", "25"]]
        let csv = viewModel.formatAsCSV(table)

        #expect(csv.contains("\"John, Jr.\""))
        #expect(csv.contains("Name,Age"))
    }

    @Test("CSV escaping with quotes")
    @MainActor
    func testCSVEscapingQuotes() async throws {
        let viewModel = TableEditorViewModel(image: createTestImage(), autoDetectGrid: false)
        let table = [["Product", "Description"], ["Widget", "A \"super\" item"]]
        let csv = viewModel.formatAsCSV(table)

        #expect(csv.contains("\"A \"\"super\"\" item\""))
    }

    @Test("CSV handles empty cells")
    @MainActor
    func testCSVEmptyCells() async throws {
        let viewModel = TableEditorViewModel(image: createTestImage(), autoDetectGrid: false)
        let table = [["A", "B", "C"], ["1", "", "3"]]
        let csv = viewModel.formatAsCSV(table)

        #expect(csv.contains("1,,3"))
    }

    // MARK: - Markdown Formatting Tests

    @Test("Markdown table structure")
    @MainActor
    func testMarkdownTableStructure() async throws {
        let viewModel = TableEditorViewModel(image: createTestImage(), autoDetectGrid: false)
        let table = [["Name", "Age"], ["John", "25"], ["Jane", "30"]]
        let markdown = viewModel.formatAsMarkdown(table)

        #expect(markdown.contains("| Name | Age |"))
        #expect(markdown.contains("| --- | --- |"))
        #expect(markdown.contains("| John | 25 |"))
        #expect(markdown.contains("| Jane | 30 |"))
    }

    @Test("Markdown escapes pipe characters")
    @MainActor
    func testMarkdownEscapesPipes() async throws {
        let viewModel = TableEditorViewModel(image: createTestImage(), autoDetectGrid: false)
        let table = [["Command", "Description"], ["ls | grep", "Pipe example"]]
        let markdown = viewModel.formatAsMarkdown(table)

        #expect(markdown.contains("ls \\| grep"))
    }

    @Test("Markdown handles uneven row lengths")
    @MainActor
    func testMarkdownUnevenRows() async throws {
        let viewModel = TableEditorViewModel(image: createTestImage(), autoDetectGrid: false)
        let table = [["A", "B", "C"], ["1", "2"]]  // Second row is shorter
        let markdown = viewModel.formatAsMarkdown(table)

        #expect(markdown.contains("| 1 | 2 |  |"))  // Empty cell padded
    }

    // MARK: - Grid Line Management Tests

    @Test("Add column creates line in center")
    @MainActor
    func testAddColumn() async throws {
        let viewModel = TableEditorViewModel(image: createTestImage(), autoDetectGrid: false)
        viewModel.verticalLines.removeAll()

        viewModel.addColumn()

        #expect(viewModel.verticalLines.count == 1)
        #expect(viewModel.verticalLines[0] == 0.5)
    }

    @Test("Add row creates line in center")
    @MainActor
    func testAddRow() async throws {
        let viewModel = TableEditorViewModel(image: createTestImage(), autoDetectGrid: false)
        viewModel.horizontalLines.removeAll()

        viewModel.addRow()

        #expect(viewModel.horizontalLines.count == 1)
        #expect(viewModel.horizontalLines[0] == 0.5)
    }

    @Test("Remove selected vertical line")
    @MainActor
    func testRemoveSelectedVerticalLine() async throws {
        let viewModel = TableEditorViewModel(image: createTestImage(), autoDetectGrid: false)
        viewModel.verticalLines = [0.3, 0.5, 0.7]
        viewModel.selectedLine = GridLine.vertical(1)

        viewModel.removeSelectedLine()

        #expect(viewModel.verticalLines.count == 2)
        #expect(!viewModel.verticalLines.contains(0.5))
        #expect(viewModel.selectedLine == nil)
    }

    @Test("Remove selected horizontal line")
    @MainActor
    func testRemoveSelectedHorizontalLine() async throws {
        let viewModel = TableEditorViewModel(image: createTestImage(), autoDetectGrid: false)
        viewModel.horizontalLines = [0.3, 0.5, 0.7]
        viewModel.selectedLine = GridLine.horizontal(1)

        viewModel.removeSelectedLine()

        #expect(viewModel.horizontalLines.count == 2)
        #expect(!viewModel.horizontalLines.contains(0.5))
        #expect(viewModel.selectedLine == nil)
    }

    @Test("Clear all lines removes everything")
    @MainActor
    func testClearAllLines() async throws {
        let viewModel = TableEditorViewModel(image: createTestImage(), autoDetectGrid: false)
        viewModel.verticalLines = [0.3, 0.5, 0.7]
        viewModel.horizontalLines = [0.2, 0.8]
        viewModel.selectedLine = GridLine.vertical(0)

        viewModel.clearAllLines()

        #expect(viewModel.verticalLines.isEmpty)
        #expect(viewModel.horizontalLines.isEmpty)
        #expect(viewModel.selectedLine == nil)
    }

    // MARK: - TableFormat Tests

    @Test("TableFormat CSV case")
    @MainActor
    func testTableFormatCSV() async throws {
        let format = TableFormat.csv
        #expect(format == .csv)
    }

    @Test("TableFormat Markdown case")
    @MainActor
    func testTableFormatMarkdown() async throws {
        let format = TableFormat.markdown
        #expect(format == .markdown)
    }

    // MARK: - Helper Functions

    @MainActor
    private func createTestImage() -> NSImage {
        // Create a simple 100x100 white image for testing
        let size = NSSize(width: 100, height: 100)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
    }
}

// MARK: - TableEditorViewModel Test Extensions

extension TableEditorViewModel {
    // Expose private formatting methods for testing
    @MainActor
    func formatAsCSV(_ table: [[String]]) -> String {
        var lines: [String] = []
        for row in table {
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

    @MainActor
    func formatAsMarkdown(_ table: [[String]]) -> String {
        guard !table.isEmpty else { return "" }
        var lines: [String] = []
        let columnCount = table.map { $0.count }.max() ?? 0

        for (index, row) in table.enumerated() {
            var paddedRow = row
            while paddedRow.count < columnCount {
                paddedRow.append("")
            }

            let escapedRow = paddedRow.map { $0.replacingOccurrences(of: "|", with: "\\|") }
            lines.append("| " + escapedRow.joined(separator: " | ") + " |")

            if index == 0 {
                let separator = "| " + Array(repeating: "---", count: columnCount).joined(separator: " | ") + " |"
                lines.append(separator)
            }
        }

        return lines.joined(separator: "\n")
    }
}
