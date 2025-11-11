# Testing Guide for TableCapture

This guide explains how to write and run tests for the TableCapture app.

## Test Structure

The project uses two types of tests:

### 1. **Unit Tests** (`TableCaptureTests/`)
- **Framework:** Swift Testing (modern, introduced in Swift 5.9+)
- **Purpose:** Test individual functions, logic, and data transformations
- **Speed:** Fast (no UI, no app launch)
- **Location:** `TableCaptureTests/TableCaptureTests.swift`

### 2. **UI Tests** (`TableCaptureUITests/`)
- **Framework:** XCTest + XCUITest
- **Purpose:** Test user interactions and full app behavior
- **Speed:** Slower (launches full app)
- **Location:** `TableCaptureUITests/TableCaptureUITests.swift`

---

## Running Tests

### In Xcode

**Run all tests:**
- Press `⌘U` (Command + U)
- Or: **Product → Test**

**Run a single test:**
1. Click the diamond icon next to the test function
2. Or: Put cursor in test function and press `⌘U`

**Run a specific test file:**
- Click the diamond icon next to the `struct` or `class` name

### From Command Line

```bash
# Run all tests
xcodebuild test -project TableCapture.xcodeproj -scheme TableCapture

# Run only unit tests
xcodebuild test -project TableCapture.xcodeproj -scheme TableCapture -only-testing:TableCaptureTests

# Run only UI tests
xcodebuild test -project TableCapture.xcodeproj -scheme TableCapture -only-testing:TableCaptureUITests
```

---

## Writing Unit Tests (Swift Testing)

### Basic Structure

```swift
import Testing
@testable import TableCapture

struct MyTests {
    @Test("Description of what this tests")
    func testSomething() async throws {
        // Arrange: Set up test data
        let input = "test"

        // Act: Perform the action
        let result = someFunction(input)

        // Assert: Verify the result
        #expect(result == "expected")
    }
}
```

### Key Features

**Assertions:**
```swift
#expect(value == expected)           // Basic equality
#expect(value != unwanted)           // Inequality
#expect(array.contains(item))        // Contains check
#expect(value > 0)                   // Comparison
#expect(value == nil)                // Nil check
```

**Async tests:**
```swift
@Test func testAsync() async throws {
    let result = await someAsyncFunction()
    #expect(result.isSuccess)
}
```

**Test with parameters:**
```swift
@Test(arguments: [1, 2, 3, 4, 5])
func testMultipleInputs(number: Int) {
    #expect(number > 0)
}
```

---

## Writing UI Tests (XCTest)

### Basic Structure

```swift
import XCTest

final class MyUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    @MainActor
    func testSomething() throws {
        // Find UI elements
        let button = app.buttons["My Button"]

        // Interact with them
        button.tap()

        // Verify results
        XCTAssertTrue(button.exists)
    }
}
```

### Key Features

**Finding elements:**
```swift
app.buttons["Button Title"]          // Button by label
app.textFields["Email"]              // Text field
app.windows["Window Title"]          // Window
app.staticTexts["Label"]             // Text label
```

**Interactions:**
```swift
element.tap()                        // Click
element.typeText("hello")            // Type text
element.swipeLeft()                  // Swipe gesture
```

**Assertions:**
```swift
XCTAssertTrue(element.exists)
XCTAssertEqual(element.label, "Expected")
XCTAssertFalse(element.isEnabled)
XCTAssertNotNil(value)
```

---

## Current Test Coverage

### Unit Tests (`TableCaptureTests.swift`)

**CSV Formatting:**
- ✅ Escaping commas
- ✅ Escaping quotes
- ✅ Handling empty cells

**Markdown Formatting:**
- ✅ Table structure (headers, separators)
- ✅ Escaping pipe characters
- ✅ Handling uneven row lengths

**Grid Management:**
- ✅ Adding columns/rows
- ✅ Removing selected lines
- ✅ Clearing all lines

### UI Tests (`TableCaptureUITests.swift`)

**App Launch:**
- ✅ Launches without crashing
- ✅ Stays running after launch

**Performance:**
- ✅ Launch time measurement
- ✅ Memory usage measurement

**Accessibility:**
- ✅ VoiceOver support checks

---

## Best Practices

### Unit Tests

1. **Keep tests isolated** - Each test should be independent
2. **Use descriptive names** - Test names should explain what they verify
3. **Test one thing** - Each test should verify a single behavior
4. **Use `@testable import`** - Access internal types for testing

### UI Tests

1. **Use accessibility identifiers** - Make elements easier to find
2. **Wait for elements** - Use `waitForExistence(timeout:)`
3. **Test user journeys** - Simulate real user workflows
4. **Keep tests stable** - Avoid flaky tests with proper waits

### General

1. **Run tests before commits** - Ensure nothing breaks
2. **Write tests for bugs** - Prevent regressions
3. **Test edge cases** - Empty strings, nil values, extreme inputs
4. **Keep tests maintainable** - Refactor test code too

---

## Adding New Tests

### For a new function in `TableEditorViewModel`:

```swift
@Test("What this function should do")
func testNewFunction() async throws {
    let viewModel = TableEditorViewModel(image: createTestImage())

    // Test your function
    viewModel.newFunction()

    #expect(viewModel.someProperty == expectedValue)
}
```

### For a new UI feature:

```swift
@MainActor
func testNewUIFeature() throws {
    let app = XCUIApplication()
    app.launch()

    // Find and interact with your UI
    let newButton = app.buttons["New Feature"]
    newButton.tap()

    // Verify the result
    XCTAssertTrue(app.staticTexts["Success"].exists)
}
```

---

## Troubleshooting

**Tests won't run:**
- Clean build folder: `⌘⇧K`
- Delete derived data: `Xcode → Settings → Locations → Derived Data`

**UI tests can't find elements:**
- Add accessibility identifiers to SwiftUI views:
  ```swift
  Button("My Button") { }
      .accessibilityIdentifier("myButton")
  ```
- Use `po app.debugDescription` in debugger to see all elements

**Tests are flaky:**
- Add explicit waits:
  ```swift
  let element = app.buttons["My Button"]
  XCTAssertTrue(element.waitForExistence(timeout: 5))
  ```

---

## Resources

- [Swift Testing Documentation](https://developer.apple.com/documentation/testing)
- [XCTest Documentation](https://developer.apple.com/documentation/xctest)
- [UI Testing Guide](https://developer.apple.com/library/archive/documentation/DeveloperTools/Conceptual/testing_with_xcode/chapters/09-ui_testing.html)
