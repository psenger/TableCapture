//
//  MixedScreenshotTests.swift
//  TableCaptureTests
//
//  Tests for complex real-world table (mixed-screenshot.png)
//

import Testing
import Foundation
import AppKit
@testable import TableCapture

// MARK: - Mixed Screenshot Tests

struct MixedScreenshotTests {

    // Real test case: Mixed content table
    static let mixedScreenshot = TableTestCase(
        imageName: "mixed-screenshot",
        verticalLines: [ 0.158614402917046,
                         0.257064721969006,
                         0.445761166818596,
                         0.761166818596171 ],
        horizontalLines: [ 0.068452380952381,
                           0.40922619047619,
                           0.745535714285714 ],
        expectedCSV: """
        "Location","Dates","First-Time Track","Returning Student Track","Rationale"
        "Bungendore","Jan 5-9 (Week 1)","Code Foundations (Mon-Tue) Creative Coders (Wed-Fri) From Beginner to Builder (Mon-Fri)","Advanced Godot Wed-Fri Evening Zoom (7-9pm)(See critical limitations)","Low accommodation costs small returning pool, geographic reach"
        "Norwest","Jan 12-16 (Week 2)","Code Foundations (Mon-Tue) Creative Coders (Wed-Fri) From Beginner to Builder (Mon-Fri)","Advanced Godot DECISION POINT:Option A if enrollment >=8 Option C if enrollment < 8 (See critical limitations)","Highest returning student base assess by Nov 24"
        "Blaxland","Jan 19-23 (Week 3)","Code Foundations (Mon-Tue)Creative Coders (Wed-Fri) From Beginner to Builder (Mon-Fri)","Advanced Godot Wed-Fri Evening Zoom (7-9pm) (See critical limitations)","Single-room venue, new location consolidate previous weeks"
        """,
        expectedMarkdown: """
        | Location | Dates | First-Time Track | Returning Student Track | Rationale |
        | --- | --- | --- | --- | --- |
        | Bungendore | Jan 5-9 (Week 1) | Code Foundations (Mon-Tue) Creative Coders (Wed-Fri) From Beginner to Builder (Mon-Fri) | Advanced Godot Wed-Fri Evening Zoom (7-9pm) (See critical limitations) | Low accommodation costs, small returning pool, geographic reach |
        | Norwest | Jan 12-16 (Week 2) | Code Foundations (Mon-Tue) Creative Coders (Wed-Fri) From Beginner to Builder (Mon-Fri) | Advanced Godot DECISION POINT: Option A if enrollment >=8 Option C if enrollment < 8 (See critical limitations) | Highest returning student base, assess by Nov 24 |
        | Blaxland | Jan 19-23 (Week 3) | Code Foundations (Mon-Tue) Creative Coders (Wed-Fri) From Beginner to Builder (Mon-Fri) | Advanced Godot Wed-Fri Evening Zoom (7-9pm) (See critical limitations) | Single-room venue, new location, consolidate previous weeks |
        """
    )

    @Test("Mixed screenshot - CSV extraction")
    func testMixedScreenshotCSV() async throws {
        let result = try await runOCRTest(testCase: Self.mixedScreenshot, format: .csv, testName: "MixedScreenshot")

        let normalizedResult = result.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedExpected = Self.mixedScreenshot.expectedCSV.trimmingCharacters(in: .whitespacesAndNewlines)

        #expect(normalizedResult == normalizedExpected,
                "CSV output doesn't match expected.\nGot:\n\(result)\n\nExpected:\n\(Self.mixedScreenshot.expectedCSV)")
    }

    @Test("Mixed screenshot - Markdown extraction")
    func testMixedScreenshotMarkdown() async throws {
        let result = try await runOCRTest(testCase: Self.mixedScreenshot, format: .markdown, testName: "MixedScreenshot")

        let normalizedResult = result.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedExpected = Self.mixedScreenshot.expectedMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)

        #expect(normalizedResult == normalizedExpected,
                "Markdown output doesn't match expected.\nGot:\n\(result)\n\nExpected:\n\(Self.mixedScreenshot.expectedMarkdown)")
    }

//    @Test("Mixed screenshot - Partial match (key data)")
//    func testMixedScreenshotPartialMatch() async throws {
//        let result = try await runOCRTest(testCase: Self.mixedScreenshot, format: .csv, testName: "MixedScreenshot")
//
//        // Check for key pieces of data (more forgiving)
//        #expect(result.contains("Location"), "Should contain 'Location' header")
//        #expect(result.contains("Bungendore"), "Should contain 'Bungendore'")
//        #expect(result.contains("Norwest"), "Should contain 'Norwest'")
//        #expect(result.contains("Blaxland"), "Should contain 'Blaxland'")
//        #expect(result.contains("Jan 5-9"), "Should contain 'Jan 5-9'")
//        #expect(result.contains("Code Foundations"), "Should contain 'Code Foundations'")
//    }

    @Test("Mixed screenshot - Debug output")
    @MainActor
    func debugMixedScreenshot() async throws {
        let image = try loadTestImage(named: Self.mixedScreenshot.imageName)
        let viewModel = TableEditorViewModel(image: image, autoDetectGrid: false, testName: "MixedScreenshot")

        viewModel.verticalLines = Self.mixedScreenshot.verticalLines
        viewModel.horizontalLines = Self.mixedScreenshot.horizontalLines

        let csvResult = try await withCheckedThrowingContinuation { continuation in
            viewModel.extractTable(format: .csv) { result in
                continuation.resume(with: result)
            }
        }

        print("""

        ========================================
        MIXED SCREENSHOT OCR EXTRACTION
        ========================================
        Image: \(Self.mixedScreenshot.imageName)
        Dimensions: 1706px × 1038px
        Vertical Lines: \(Self.mixedScreenshot.verticalLines)
        Horizontal Lines: \(Self.mixedScreenshot.horizontalLines)

        CSV Output:
        \(csvResult)

        Expected:
        \(Self.mixedScreenshot.expectedCSV)
        ========================================

        """)
    }
}
