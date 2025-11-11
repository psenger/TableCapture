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
func runOCRTest(testCase: TableTestCase, format: TableFormat) async throws -> String {
    let image = try loadTestImage(named: testCase.imageName)
    let viewModel = TableEditorViewModel(image: image, autoDetectGrid: false)

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
