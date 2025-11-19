//
//  OCRTestHelpers.swift
//  TableCaptureTests
//
//  Shared helpers and test case structure for OCR tests
//

import Testing
import Foundation
import AppKit
@testable import TableCapture

// MARK: - Test Data Structure

struct TableTestCase {
    let imageName: String
    let verticalLines: [CGFloat]      // Column dividers (0.0 to 1.0)
    let horizontalLines: [CGFloat]    // Row dividers (0.0 to 1.0)
    let expectedCSV: String
    let expectedMarkdown: String

    init(imageName: String,
         verticalLines: [CGFloat],
         horizontalLines: [CGFloat],
         expectedCSV: String,
         expectedMarkdown: String) {
        self.imageName = imageName
        self.verticalLines = verticalLines
        self.horizontalLines = horizontalLines
        self.expectedCSV = expectedCSV
        self.expectedMarkdown = expectedMarkdown
    }
}

// MARK: - Helper Functions

/// Load a test image from the Resources bundle
func loadTestImage(named: String) throws -> NSImage {
    let bundle = Bundle(for: BundleMarker.self)

    // Try multiple extensions
    let extensions = ["png", "jpg", "jpeg"]
    for ext in extensions {
        if let url = bundle.url(forResource: named, withExtension: ext),
           let image = NSImage(contentsOf: url) {
            return image
        }
    }

    // If not found, throw an error with helpful message
    throw TestError.missingTestImage("""
        Could not find test image: \(named)

        To add test images:
        1. Take a screenshot of a table
        2. Save it as '\(named).png'
        3. Add it to TableCaptureTests/Resources/ folder
        4. In Xcode: Select the file → File Inspector → Target Membership → Check 'TableCaptureTests'
        """)
}

/// Run a complete OCR test with the given test case
@MainActor
func runOCRTest(testCase: TableTestCase, format: TableFormat, testName: String? = nil) async throws -> String {
    let image = try loadTestImage(named: testCase.imageName)
    let viewModel = TableEditorViewModel(image: image, autoDetectGrid: false, testName: testName)

    // Set the grid lines
    viewModel.verticalLines = testCase.verticalLines
    viewModel.horizontalLines = testCase.horizontalLines

    // Extract the table
    return try await withCheckedThrowingContinuation { continuation in
        viewModel.extractTable(format: format) { result in
            continuation.resume(with: result)
        }
    }
}

// MARK: - String Comparison Helpers

/// Calculate Levenshtein distance between two strings (edit distance)
/// Returns the minimum number of single-character edits needed to change one string into another
func levenshteinDistance(_ str1: String, _ str2: String) -> Int {
    let s1 = Array(str1)
    let s2 = Array(str2)
    let len1 = s1.count
    let len2 = s2.count

    // Create a matrix to store distances
    var matrix = Array(repeating: Array(repeating: 0, count: len2 + 1), count: len1 + 1)

    // Initialize first column and row
    for i in 0...len1 {
        matrix[i][0] = i
    }
    for j in 0...len2 {
        matrix[0][j] = j
    }

    // Calculate distances
    for i in 1...len1 {
        for j in 1...len2 {
            let cost = s1[i - 1] == s2[j - 1] ? 0 : 1
            matrix[i][j] = min(
                matrix[i - 1][j] + 1,      // deletion
                matrix[i][j - 1] + 1,      // insertion
                matrix[i - 1][j - 1] + cost // substitution
            )
        }
    }

    return matrix[len1][len2]
}

/// Calculate similarity ratio between two strings (0.0 to 1.0)
/// 1.0 = identical, 0.0 = completely different
func stringSimilarity(_ str1: String, _ str2: String) -> Double {
    let maxLen = max(str1.count, str2.count)
    if maxLen == 0 { return 1.0 }

    let distance = levenshteinDistance(str1, str2)
    return 1.0 - (Double(distance) / Double(maxLen))
}

/// Compare two CSV/Markdown outputs with fuzzy matching for OCR errors
/// Returns true if strings are identical or very similar (allowing for minor OCR errors)
/// - Parameters:
///   - actual: The actual OCR output
///   - expected: The expected output
///   - similarityThreshold: Minimum similarity ratio (0.0-1.0). Default 0.98 (98% similar)
/// - Returns: true if strings match exactly or are above similarity threshold
func fuzzyCompare(_ actual: String, _ expected: String, similarityThreshold: Double = 0.98) -> Bool {
    // First try exact match (fastest)
    if actual == expected {
        return true
    }

    // Calculate similarity
    let similarity = stringSimilarity(actual, expected)
    return similarity >= similarityThreshold
}

/// Compare two strings and return detailed character-by-character differences
func detailedStringComparison(_ actual: String, _ expected: String) -> String {
    var output = "\n========================================\n"
    output += "DETAILED STRING COMPARISON\n"
    output += "========================================\n\n"

    // Overall statistics
    output += "Actual length: \(actual.count) characters\n"
    output += "Expected length: \(expected.count) characters\n"
    output += "Difference: \(actual.count - expected.count) characters\n\n"

    // Line-by-line comparison
    let actualLines = actual.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    let expectedLines = expected.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

    output += "Lines in actual: \(actualLines.count)\n"
    output += "Lines in expected: \(expectedLines.count)\n\n"

    let maxLines = max(actualLines.count, expectedLines.count)

    for i in 0..<maxLines {
        let actualLine = i < actualLines.count ? actualLines[i] : "<MISSING>"
        let expectedLine = i < expectedLines.count ? expectedLines[i] : "<EXTRA LINE>"

        if actualLine == expectedLine {
            output += "✓ Line \(i + 1): MATCH\n"
        } else {
            output += "\n❌ Line \(i + 1): MISMATCH\n"
            output += "   Actual:   \"\(actualLine)\"\n"
            output += "   Expected: \"\(expectedLine)\"\n"

            // Character-by-character comparison for this line
            let charComparison = compareStringsCharByChar(actualLine, expectedLine)
            if !charComparison.isEmpty {
                output += charComparison
            }
        }
    }

    output += "\n========================================\n"
    return output
}

/// Compare two strings character by character and highlight differences
private func compareStringsCharByChar(_ str1: String, _ str2: String) -> String {
    let chars1 = Array(str1)
    let chars2 = Array(str2)
    let maxLen = max(chars1.count, chars2.count)

    var output = ""
    var diffPositions: [Int] = []

    for i in 0..<maxLen {
        let c1 = i < chars1.count ? chars1[i] : nil
        let c2 = i < chars2.count ? chars2[i] : nil

        if c1 != c2 {
            diffPositions.append(i)
        }
    }

    if !diffPositions.isEmpty {
        output += "   Differences at positions: \(diffPositions.map { String($0) }.joined(separator: ", "))\n"

        for pos in diffPositions.prefix(10) { // Show first 10 differences
            let c1 = pos < chars1.count ? chars1[pos] : nil
            let c2 = pos < chars2.count ? chars2[pos] : nil

            let c1Desc = c1.map { describeChar($0) } ?? "<END>"
            let c2Desc = c2.map { describeChar($0) } ?? "<END>"

            output += "     Position \(pos): '\(c1Desc)' vs '\(c2Desc)'\n"
        }

        if diffPositions.count > 10 {
            output += "     ... and \(diffPositions.count - 10) more differences\n"
        }
    }

    return output
}

/// Describe a character in a human-readable way
private func describeChar(_ char: Character) -> String {
    switch char {
    case "\n": return "\\n (newline)"
    case "\r": return "\\r (carriage return)"
    case "\t": return "\\t (tab)"
    case " ": return "SPACE"
    case ",": return "COMMA"
    case "\"": return "QUOTE"
    default:
        if char.isWhitespace {
            return "\\u{\(String(char.unicodeScalars.first!.value, radix: 16))} (whitespace)"
        }
        return String(char)
    }
}

// MARK: - Error Types

enum TestError: Error, CustomStringConvertible {
    case missingTestImage(String)

    var description: String {
        switch self {
        case .missingTestImage(let message):
            return message
        }
    }
}

// MARK: - Bundle Marker

/// Helper class to get the test bundle (needed because test structs don't have bundle)
private class BundleMarker {}
