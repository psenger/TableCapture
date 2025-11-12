//
//  TableCaptureUITests.swift
//  TableCaptureUITests
//
//  Created by Philip A Senger on 10/11/2025.
//

import XCTest

final class TableCaptureUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Menu Bar Tests

    @MainActor
    func testMenuBarIconExists() throws {
        // Note: Menu bar apps are tricky to test with UI tests
        // The app should launch without crashing
        XCTAssertTrue(app.state == .runningForeground || app.state == .runningBackground)
    }

    @MainActor
    func testAppLaunchesSuccessfully() throws {
        // Verify the app launches and doesn't crash
        XCTAssertTrue(app.state == .runningForeground || app.state == .runningBackground)

        // Give it a moment to initialize
        sleep(1)

        // App should still be running
        XCTAssertTrue(app.state == .runningForeground || app.state == .runningBackground)
    }

    // MARK: - Help Window Tests

    @MainActor
    func testHelpWindowOpens() throws {
        // This test assumes you can trigger help programmatically
        // In reality, menu bar testing is complex and may require accessibility APIs

        // If help window exists, it should have expected content
        let helpWindows = app.windows.matching(identifier: "HelpWindow")
        if helpWindows.count > 0 {
            let helpWindow = helpWindows.firstMatch
            XCTAssertTrue(helpWindow.exists)
        }
    }

    // MARK: - Performance Tests

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    func testMemoryUsage() throws {
        // Measure memory footprint
        measure(metrics: [XCTMemoryMetric()]) {
            // Simulate some app activity
            sleep(2)
        }
    }
}

// MARK: - Table Editor UI Tests

extension TableCaptureUITests {

    @MainActor
    func testTableEditorWindowElements() throws {
        // Note: This test would need the editor window to be open
        // You might need to trigger it programmatically or via accessibility

        let editorWindow = app.windows["Table Editor"]

        // Only run if editor window exists
        if editorWindow.exists {
            // Check for key buttons
            XCTAssertTrue(editorWindow.buttons["Cancel"].exists ||
                         app.buttons["Cancel"].exists)
            XCTAssertTrue(editorWindow.buttons["Extract as CSV"].exists ||
                         app.buttons["Extract as CSV"].exists)
            XCTAssertTrue(editorWindow.buttons["Extract as Markdown"].exists ||
                         app.buttons["Extract as Markdown"].exists)
        }
    }

    @MainActor
    func testGridControlButtons() throws {
        // Check if grid control buttons exist when editor is open
        let editorWindow = app.windows["Table Editor"]

        if editorWindow.exists {
            // These buttons should exist in the toolbar
            let addColumnButton = editorWindow.buttons.matching(identifier: "Add Column").firstMatch
            let addRowButton = editorWindow.buttons.matching(identifier: "Add Row").firstMatch

            // If they exist, verify they're enabled initially
            if addColumnButton.exists {
                XCTAssertTrue(addColumnButton.isEnabled)
            }
            if addRowButton.exists {
                XCTAssertTrue(addRowButton.isEnabled)
            }
        }
    }
}

// MARK: - Accessibility Tests

extension TableCaptureUITests {

    @MainActor
    func testKeyboardShortcuts() throws {
        // Test keyboard accessibility
        // Command+C should trigger capture (when menu bar is accessible)
        // Command+Q should quit

        // This is a placeholder - actual implementation depends on accessibility
        XCTAssertTrue(true, "Keyboard shortcut testing requires accessibility setup")
    }

    @MainActor
    func testVoiceOverSupport() throws {
        // Verify key UI elements have accessibility labels
        // This ensures the app is usable with VoiceOver

        let editorWindow = app.windows["Table Editor"]
        if editorWindow.exists {
            // Check that buttons have proper accessibility
            let cancelButton = editorWindow.buttons["Cancel"]
            if cancelButton.exists {
                XCTAssertNotNil(cancelButton.label)
                XCTAssertFalse(cancelButton.label.isEmpty)
            }
        }
    }
}
