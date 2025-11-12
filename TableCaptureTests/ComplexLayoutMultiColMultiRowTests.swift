//
//  ComplexLayoutMultiColMultiRowTests.swift
//  TableCaptureTests
//
//  Tests for complex table with multiple columns, rows, and multi-line cells
//  Image: complext-layout-multi-line-multi-col-multi-row.png
//  Dimensions: 980px wide × 616px height
//  Grid: 5 columns × 4 rows (including header)
//

import Testing
import Foundation
import AppKit
@testable import TableCapture

// MARK: - Complex Layout Multi-Column Multi-Row Tests

struct ComplexLayoutMultiColMultiRowTests {

    // Complex 5-column, 4-row table with multi-line content
    // This tests a realistic table with headers and data rows containing multi-line text
    // Horizontal lines at Y: 49px (0.08 from top = 0.92 from bottom), 252px (0.41 from top = 0.59 from bottom), 460px (0.75 from top = 0.25 from bottom)
    // Vertical lines at X: 150px (0.15), 254px (0.26), 456px (0.47), 757px (0.77)
    // NOTE: macOS uses bottom-left origin, so Y coordinates are inverted (1.0 - original value)
    static let complexLayout = TableTestCase(
        imageName: "complext-layout-multi-line-multi-col-multi-row",
        verticalLines: [0.15, 0.26, 0.47, 0.77],      // 4 vertical lines create 5 columns
        horizontalLines: [0.92, 0.59, 0.25],          // 3 horizontal lines (inverted for bottom-left origin)
        expectedCSV: """
        "Location","Dates","First-Time Track","Returning Student Track","Rationale"
        "Bungendore","Jan 5-9 (Week 1)","Code Foundations (Mon-Tue)Creative Coders (Wed-Fri)From Beginner to Builder (Mon-Fri)","Advanced GodotWed-Fri Evening Zoom (7-9pm)(See critical limitations)","Low accommodation costs, small returning pool, geographic reach"
        "Norwest","Jan 12-16 (Week 2)","Code Foundations (Mon-Tue)Creative Coders (Wed-Fri)From Beginner to Builder (Mon-Fri)","Advanced GodotDECISION POINT:Option A if enrollment ≥8Option C if enrollment <8(See critical limitations)","Highest returning student base, assess by Nov 24"
        "Blaxland","Jan 19-23 (Week 3)","Code Foundations (Mon-Tue)Creative Coders (Wed-Fri)From Beginner to Builder (Mon-Fri)","Advanced GodotWed-Fri Evening Zoom (7-9pm)(See critical limitations)","Single-room venue, new location, consolidate previous weeks"
        """,
        expectedMarkdown: """
        | Location | Dates | First-Time Track | Returning Student Track | Rationale |
        | --- | --- | --- | --- | --- |
        | Bungendore | Jan 5-9 (Week 1) | Code Foundations (Mon-Tue)Creative Coders (Wed-Fri)From Beginner to Builder (Mon-Fri) | Advanced GodotWed-Fri Evening Zoom (7-9pm)(See critical limitations) | Low accommodation costs, small returning pool, geographic reach |
        | Norwest | Jan 12-16 (Week 2) | Code Foundations (Mon-Tue)Creative Coders (Wed-Fri)From Beginner to Builder (Mon-Fri) | Advanced GodotDECISION POINT:Option A if enrollment ≥8Option C if enrollment <8(See critical limitations) | Highest returning student base, assess by Nov 24 |
        | Blaxland | Jan 19-23 (Week 3) | Code Foundations (Mon-Tue)Creative Coders (Wed-Fri)From Beginner to Builder (Mon-Fri) | Advanced GodotWed-Fri Evening Zoom (7-9pm)(See critical limitations) | Single-room venue, new location, consolidate previous weeks |
        """
    )

    @Test("Complex layout - CSV extraction")
    func testComplexLayoutCSV() async throws {
        let result = try await runOCRTest(testCase: Self.complexLayout, format: .csv)

        let normalizedResult = result.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedExpected = Self.complexLayout.expectedCSV.trimmingCharacters(in: .whitespacesAndNewlines)

        #expect(normalizedResult == normalizedExpected,
                "CSV output doesn't match expected.\nGot:\n\(result)\n\nExpected:\n\(Self.complexLayout.expectedCSV)")
    }

    @Test("Complex layout - Markdown extraction")
    func testComplexLayoutMarkdown() async throws {
        let result = try await runOCRTest(testCase: Self.complexLayout, format: .markdown)

        let normalizedResult = result.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedExpected = Self.complexLayout.expectedMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)

        #expect(normalizedResult == normalizedExpected,
                "Markdown output doesn't match expected.\nGot:\n\(result)\n\nExpected:\n\(Self.complexLayout.expectedMarkdown)")
    }

    @Test("Complex layout - Debug output")
    @MainActor
    func debugComplexLayout() async throws {
        let image = try loadTestImage(named: Self.complexLayout.imageName)
        let viewModel = TableEditorViewModel(image: image, autoDetectGrid: false)

        viewModel.verticalLines = Self.complexLayout.verticalLines
        viewModel.horizontalLines = Self.complexLayout.horizontalLines

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
        COMPLEX LAYOUT MULTI-COL MULTI-ROW OCR EXTRACTION
        ========================================
        Image: \(Self.complexLayout.imageName)
        Dimensions: 980px × 616px
        Grid: 5 columns × 4 rows (including header)

        Vertical Lines (X positions):
          150px (0.15), 254px (0.26), 456px (0.47), 757px (0.77)

        Horizontal Lines (Y positions):
          49px (0.08), 252px (0.41), 460px (0.75)

        Expected Layout:
        - Header row: Location | Dates | First-Time Track | Returning Student Track | Rationale
        - Row 1: Bungendore (Jan 5-9, Week 1)
        - Row 2: Norwest (Jan 12-16, Week 2)
        - Row 3: Blaxland (Jan 19-23, Week 3)
        - Multi-line cells throughout

        ----------------------------------------
        CSV OUTPUT:
        ----------------------------------------
        \(csvResult)

        ----------------------------------------
        CSV EXPECTED:
        ----------------------------------------
        \(Self.complexLayout.expectedCSV)

        ----------------------------------------
        MARKDOWN OUTPUT:
        ----------------------------------------
        \(markdownResult)

        ----------------------------------------
        MARKDOWN EXPECTED:
        ----------------------------------------
        \(Self.complexLayout.expectedMarkdown)

        ----------------------------------------
        CHARACTER COMPARISON:
        ----------------------------------------
        CSV Output bytes: \(csvResult.utf8.map { String(format: "%02X", $0) }.joined(separator: " "))
        CSV Expected bytes: \(Self.complexLayout.expectedCSV.utf8.map { String(format: "%02X", $0) }.joined(separator: " "))

        Markdown Output bytes: \(markdownResult.utf8.map { String(format: "%02X", $0) }.joined(separator: " "))
        Markdown Expected bytes: \(Self.complexLayout.expectedMarkdown.utf8.map { String(format: "%02X", $0) }.joined(separator: " "))
        ========================================

        """)
    }
}
