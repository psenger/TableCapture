# OCR Test Image Guide

This guide explains how to create and use test images for OCR testing.

## 🎯 Start Here: Simple Single-Cell Test

Before testing complex tables, verify that basic OCR works with a single-cell test:

1. **Create test image:**
   - Open a text editor or web browser
   - Type the word "Hello" in a clear font (Arial, Helvetica, 18-24pt)
   - Take a screenshot of just that word (aim for ~200px wide)
   - Save as `simple-hello.png`

2. **Add to project:**
   - Drag `simple-hello.png` into `TableCaptureTests/Resources/` in Xcode
   - Check **Target Membership → TableCaptureTests** in File Inspector

3. **Run the test:**
   - In Xcode Test Navigator, find `testSimpleHelloCSV()`
   - Click the diamond icon to run it
   - If it passes, OCR is working! Move on to multi-cell tests
   - If it fails, run `debugSimpleHello()` to see what OCR extracted

4. **Troubleshooting:**
   - Make sure the word is clearly visible in the screenshot
   - Use a standard font (avoid fancy/stylized fonts)
   - Ensure good contrast (black text on white background)

## Quick Start

1. **Take a screenshot** of a table (can be from any app, web page, etc.)
2. **Save it** as a PNG file (e.g., `simple-2x2-table.png`)
3. **Add to project:**
   - Drag the image into `TableCaptureTests/Resources/` folder in Xcode
   - **Important:** Check **Target Membership → TableCaptureTests** in File Inspector
4. **Create a test case** in `OCRTests.swift`
5. **Specify grid lines** (where the columns/rows divide)
6. **Specify expected output** (what OCR should extract)

## How to Determine Grid Line Positions

Grid lines are specified as **normalized coordinates** from 0.0 to 1.0:

### Vertical Lines (Column Dividers)
- `0.0` = Left edge of image
- `0.5` = Middle of image
- `1.0` = Right edge of image

**Example:** A table with 3 columns needs 2 vertical dividers:
```swift
verticalLines: [0.33, 0.66]  // Divides image into thirds
```

### Horizontal Lines (Row Dividers)
- `0.0` = Bottom edge of image
- `0.5` = Middle of image
- `1.0` = Top edge of image

**Example:** A table with 3 rows needs 2 horizontal dividers:
```swift
horizontalLines: [0.33, 0.66]  // Divides image into thirds
```

## Finding Exact Grid Positions

### Method 1: Use the App Itself! 🎯
1. Run TableCapture app
2. Capture your test image
3. In the editor, adjust grid lines until they're perfect
4. **Use the debug console** to print the grid positions

Add this temporary code to `TableEditorViewModel.swift`:
```swift
func printGridPositions() {
    print("Vertical lines: \(verticalLines)")
    print("Horizontal lines: \(horizontalLines)")
}
```

Then call it before extraction.

### Method 2: Use Preview.app
1. Open your test image in Preview
2. Tools → Show Inspector (⌘I)
3. Note the image dimensions (e.g., 1000px wide)
4. Use the cursor position to find divider locations
5. Calculate: `position / width` or `position / height`

**Example:**
- Image is 1000px wide
- Column divider is at 333px
- Grid position: `333 / 1000 = 0.333`

### Method 3: Estimate and Iterate
1. Start with rough estimates (e.g., `[0.3, 0.6]`)
2. Run the test
3. Use the `inspectOCRResults()` test to see what was extracted
4. Adjust grid lines based on results
5. Repeat until accurate

## Creating Test Cases

### Step-by-Step Example

Let's create a test for this table:

```
| Name  | Age | City |
|-------|-----|------|
| Alice | 28  | NYC  |
| Bob   | 35  | LA   |
```

**1. Take a screenshot and save as `people-table.png`**

**2. Add it to the project:**
- Drag to `TableCaptureTests/Resources/`
- Check Target Membership

**3. Create test case in `OCRTests.swift`:**

```swift
static let peopleTable = TableTestCase(
    imageName: "people-table",

    // Grid lines: 3 columns = 2 dividers at 33% and 66%
    verticalLines: [0.33, 0.66],

    // Grid lines: 3 rows (header + 2 data) = 2 dividers
    // Adjust these based on actual row heights!
    horizontalLines: [0.4, 0.7],

    expectedCSV: """
    Name,Age,City
    Alice,28,NYC
    Bob,35,LA
    """,

    expectedMarkdown: """
    | Name | Age | City |
    | --- | --- | --- |
    | Alice | 28 | NYC |
    | Bob | 35 | LA |
    """
)
```

**4. Add tests:**

```swift
@Test("People table - CSV")
func testPeopleTableCSV() async throws {
    let result = try await runOCRTest(testCase: Self.peopleTable, format: .csv)
    let normalized = result.trimmingCharacters(in: .whitespacesAndNewlines)
    let expected = Self.peopleTable.expectedCSV.trimmingCharacters(in: .whitespacesAndNewlines)

    #expect(normalized == expected)
}
```

## Tips for Good Test Images

### ✅ Good Test Images:
- Clear, high-resolution screenshots
- Good contrast (dark text on light background)
- Standard fonts (Arial, Helvetica, etc.)
- Well-aligned text in cells
- Consistent spacing
- Simple table structure

### ❌ Avoid:
- Blurry or low-resolution images
- Fancy fonts or stylized text
- Rotated or skewed tables
- Very small text (< 10pt)
- Tables with merged cells
- Heavy backgrounds or patterns

## Debugging Failed Tests

### Test fails? Here's what to do:

**1. Use the inspection test:**
```swift
@Test("Debug my table")
func debugMyTable() async throws {
    let image = try loadTestImage(named: "my-table")
    let viewModel = TableEditorViewModel(image: image)
    viewModel.verticalLines = [0.5]
    viewModel.horizontalLines = [0.5]

    let result = try await withCheckedThrowingContinuation { continuation in
        viewModel.extractTable(format: .csv) { result in
            continuation.resume(with: result)
        }
    }

    print("GOT:\n\(result)")
    print("\nEXPECTED:\n\(expectedCSV)")
}
```

**2. Check the actual vs expected output:**
- Compare character by character
- Watch for extra spaces, newlines
- Check for OCR errors ("O" vs "0", "I" vs "1", etc.)

**3. Adjust expectations:**
If OCR is consistently getting something slightly wrong, you may need to:
- Adjust grid lines
- Use a better quality image
- Use partial matching instead of exact matching
- Improve the OCR settings in the app

**4. Use partial matching for brittle tests:**
```swift
@Test("Table contains key data")
func testPartialMatch() async throws {
    let result = try await runOCRTest(testCase: myTable, format: .csv)

    // More forgiving than exact match
    #expect(result.contains("Name"))
    #expect(result.contains("Alice"))
    #expect(result.contains("28"))
}
```

## Example Test Images to Create

Here are some good starter test cases:

1. **simple-hello.png** ⭐ START HERE
   - Single cell with just one word: "Hello"
   - No grid lines needed
   - Perfect baseline test to verify OCR works before testing complex tables
   - Take a screenshot of just the word "Hello" in a clear font (Arial, Helvetica)
   - Recommended size: ~200px wide, ~100px tall

2. **simple-hello-world.png** ⭐ MULTI-LINE TEST
   - Single cell with two lines of text: "Hello" on one line, "World" on the next
   - No grid lines needed
   - Tests OCR handling of line breaks within a single cell
   - Take a screenshot of:
     ```
     Hello
     World
     ```
   - Use a clear font (Arial, Helvetica, 18-24pt)
   - Recommended size: ~200px wide, ~120px tall
   - Expected behavior: OCR should detect both lines and preserve the line break

3. **simple-2x2-table.png**
   - Just 2 columns, 2 rows
   - Simple text like "Name, Age" / "John, 25"

3. **numbers-table.png**
   - Test number recognition
   - Multiple columns of numbers

3. **mixed-content.png**
   - Text, numbers, and special characters
   - Test edge cases like "O'Brien" or "123-456"

4. **sparse-table.png**
   - Some empty cells
   - Tests handling of missing data

5. **dense-table.png**
   - Lots of text in cells
   - Tests multi-word cell content

## Real World Example: mixed-screenshot.png

This is an actual test case included in the project that demonstrates a complex, real-world table.

### Image Details
- **Filename:** `mixed-screenshot.png`
- **Dimensions:** 1706px × 1038px
- **Content:** Schedule table with 5 columns and 4 rows
- **Complexity:** Multi-line cell content, special characters, mixed text

### Grid Line Calculations

**Original pixel coordinates (0,0 at top-left):**
- Vertical lines: 310px, 485px, 822px, 1038px
- Horizontal lines: 90px, 370px, 710px

**Conversion to normalized coordinates:**

Vertical lines (divide by width):
- 310px ÷ 1706px = 0.182
- 485px ÷ 1706px = 0.284
- 822px ÷ 1706px = 0.482
- 1038px ÷ 1706px = 0.608

Horizontal lines (flip and divide by height, since Vision uses bottom-left origin):
- 90px from top → (1038 - 90) ÷ 1038 = **0.913**
- 370px from top → (1038 - 370) ÷ 1038 = **0.643**
- 710px from top → (1038 - 710) ÷ 1038 = **0.316**

### Expected Data

**Row 1 (Headers):**
- Location
- Dates
- First-Time Track
- Returning Student Track
- Rationale

**Row 2:**
- Bungendore
- Jan 5-9 (Week 1)
- Code Foundations (Mon-Tue)Creative Coders (Wed-Fri)From Beginner to Builder (Mon-Fri)
- Advanced GodotWed-Fri Evening Zoom (7-9pm)(See critical limitations)
- Low accommodation costs, small returning pool, geographic reach

**Row 3:**
- Norwest
- Jan 12-16 (Week 2)
- Code Foundations (Mon-Tue)Creative Coders (Wed-Fri)From Beginner to Builder (Mon-Fri)
- Advanced GodotDECISION POINT:Option A if enrollment ≥80ption C if enrollment <8(See critical limitations)
- Highest returning student base, assess by Nov 24

**Row 4:**
- Blaxland
- Jan 19-23 (Week 3)
- Code Foundations (Mon-Tue)Creative Coders (Wed-Fri)From Beginner to Builder (Mon-Fri)
- Advanced GodotWed-Fri Evening Zoom (7-9pm) (See critical limitations)
- Single-room venue, new location, consolidate previous weeks

### Test Functions

Four tests are provided for this image:

1. **`testMixedScreenshotCSV()`** - Tests exact CSV extraction
2. **`testMixedScreenshotMarkdown()`** - Tests exact Markdown extraction
3. **`testMixedScreenshotPartialMatch()`** - Tests for presence of key data (more forgiving)
4. **`debugMixedScreenshot()`** - Prints actual vs expected output for debugging

### Running the Tests

```bash
# Run just the mixed screenshot tests
# In Xcode Test Navigator, expand OCRTests and run individual tests

# Or run the debug test to see actual OCR output:
# Click the diamond icon next to debugMixedScreenshot()
```

### What This Tests

This test case is valuable because it exercises:
- **Multi-line cell content** - Cells contain multiple lines of text
- **Special characters** - Parentheses, dashes, ≥, < symbols
- **Mixed formatting** - Bold headers, regular text, dates
- **Variable text density** - Some cells are sparse, others are dense
- **Real-world complexity** - Actual use case, not artificial test data

### Converting Your Own Pixel Coordinates

If you have pixel coordinates from another image, use this formula:

**For vertical lines (X coordinates):**
```
normalized_x = pixel_x / image_width
```

**For horizontal lines (Y coordinates):**
```
normalized_y = (image_height - pixel_y) / image_height
```

Note: The Y-axis flip is necessary because Vision uses bottom-left as origin (0,0), but most tools (Preview, Photoshop, etc.) use top-left as origin.

### Example Conversion Script

You can use this Swift code snippet to convert coordinates:

```swift
let imageWidth: CGFloat = 1706
let imageHeight: CGFloat = 1038

// Your pixel coordinates (from top-left origin)
let verticalPixels: [CGFloat] = [310, 485, 822, 1038]
let horizontalPixels: [CGFloat] = [90, 370, 710]

// Convert to normalized coordinates
let verticalLines = verticalPixels.map { $0 / imageWidth }
let horizontalLines = horizontalPixels.map { (imageHeight - $0) / imageHeight }

print("verticalLines: \(verticalLines)")
print("horizontalLines: \(horizontalLines)")
```

## Directory Structure

```
TableCaptureTests/
├── TableCaptureTests.swift      # Unit tests (formatting, grid logic)
├── OCRTests.swift               # OCR integration tests
├── Resources/                   # Test images go here
│   ├── simple-2x2-table.png
│   ├── medium-3x3-table.png
│   └── [your test images]
└── README.md                    # This file
```

## Running the Tests

```bash
# Run all tests
⌘U in Xcode

# Run just OCR tests
# Click the diamond icon next to "struct OCRTests"

# Run a specific test
# Click the diamond icon next to the test function
```

## Next Steps

1. Create your first test image (start simple!)
2. Add it to the Resources folder
3. Create a test case in `OCRTests.swift`
4. Run it and see what happens
5. Iterate on grid positions and expectations
6. Add more test cases as you find edge cases

Good luck! 🎉
