# Contributing to TableCapture

Thank you for your interest in contributing to TableCapture! This guide will help you get started with development.

## Table of Contents

- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Running Tests](#running-tests)
- [Building a Release](#building-a-release)
- [macOS Security & Permissions](#macos-security--permissions)
- [Architecture & Design Notes](#architecture--design-notes)
- [Submitting Changes](#submitting-changes)

---

## Getting Started

### Prerequisites

- **macOS 12.3+** (Monterey or later)
- **Xcode 14+** with Swift 5.5+
- **Apple Silicon** Mac (arm64)

### Clone the Repository

```bash
git clone https://github.com/psenger/TableCapture.git
cd TableCapture
```

### Open in Xcode

```bash
open TableCapture.xcodeproj
```

---

## Development Setup

1. Open `TableCapture.xcodeproj` in Xcode
2. Select the `TableCapture` scheme
3. Build and run (`⌘R`)
4. Grant Screen Recording permission when prompted (System Settings > Privacy & Security > Screen Recording)

---

## Running Tests

### In Xcode

- **Run all tests:** `⌘U`
- **Run a single test:** Click the diamond icon next to the test function

### From Command Line

#### Run all tests:

```bash
xcodebuild test -project TableCapture.xcodeproj -scheme TableCapture -destination 'platform=macOS,arch=arm64'
```

#### Run only the ComplexLayoutMultiColMultiRowTests:

```bash
xcodebuild test -project TableCapture.xcodeproj -scheme TableCapture -destination 'platform=macOS,arch=arm64' -only-testing:TableCaptureTests/ComplexLayoutMultiColMultiRowTests
```

#### Run only the debug test to see OCR output:

```bash
xcodebuild test -project TableCapture.xcodeproj -scheme TableCapture -destination 'platform=macOS,arch=arm64' -only-testing:TableCaptureTests/ComplexLayoutMultiColMultiRowTests/debugComplexLayout
```

#### Run a specific test (CSV or Markdown):

```bash
xcodebuild test -project TableCapture.xcodeproj -scheme TableCapture -destination 'platform=macOS,arch=arm64' -only-testing:TableCaptureTests/ComplexLayoutMultiColMultiRowTests/testComplexLayoutMarkdown
```

### Test Structure

| Type | Framework | Location | Purpose |
|------|-----------|----------|---------|
| Unit Tests | Swift Testing | `TableCaptureTests/` | Test functions, logic, data transformations |
| UI Tests | XCTest + XCUITest | `TableCaptureUITests/` | Test user interactions and full app behavior |

For detailed testing documentation, see [TESTING.md](TESTING.md).

---

## Building a Release

### Creating a Release Candidate

1. **Build for Release in Xcode**
   - Select **Product → Archive** from the menu
   - Wait for the archive to complete
   - In the Organizer window, click **Distribute App**
   - Choose **Custom** → **Copy App** and save to a location (e.g., Desktop)

2. **Locate the .app Bundle**
   - Find `TableCapture.app` in the exported location

3. **Create a Professional DMG Installer** (with drag-to-Applications)

   ```bash
   # Navigate to the folder containing TableCapture.app
   cd /path/to/exported/app

   # Create Applications symlink next to your app
   ln -s /Applications Applications

   # Create the DMG containing both the app and Applications link
   hdiutil create -volname "TableCapture" \
     -srcfolder . \
     -ov -format UDZO \
     ../TableCapture.dmg

   # Clean up the symlink
   rm Applications
   ```

4. **Create a GitHub Release**
   - Go to your repository → **Releases**
   - Click **Draft a new release**
   - Create a new tag (e.g., `v1.0.0`)
   - Add release notes
   - Upload the `TableCapture.dmg` file
   - Publish the release

---

## macOS Security & Permissions

### Why Does Rebuilding Break Permissions?

When you rebuild the app, macOS often treats it as a "different" application:

1. **Code Signature Changes**: Each build gets a new signature, and macOS ties permissions (like Screen Recording) to that signature
2. **Cached Permissions**: The old permission is still registered but for the "old" app signature
3. **macOS Gets Confused**: It sees your app as brand new and blocks it

### Solutions

#### Quick Fix (During Development)

```bash
# 1. Kill the app completely
killall TableCapture

# 2. Reset Screen Recording permissions for your app
tccutil reset ScreenCapture com.philipasenger.TableCapture

# 3. Rebuild and run in Xcode
# You'll need to re-grant permission in System Settings → Privacy & Security → Screen Recording
```

#### Better Fix (Consistent Identity)

Set a **stable code signing identity** in Xcode:

1. Go to your project settings → **Signing & Capabilities**
2. Enable **Automatically manage signing**
3. Make sure you have a consistent **Team** selected
4. Ensure your **Bundle Identifier** never changes (e.g., `com.yourname.TableCapture`)

#### Nuclear Option (When All Else Fails)

```bash
# Reset ALL TCC (privacy) permissions for your app - use carefully!
tccutil reset All com.philipasenger.TableCapture
```

> **Note**: You'll need to re-grant Screen Recording permission after each rebuild during development. This is annoying but normal for macOS security.

### For Distribution

When ready to distribute:
- Sign with a **Developer ID** certificate
- **Notarize** the app with Apple

This makes the signature consistent and permissions stick between launches for users.

---

## Architecture & Design Notes

### OCR Implementation

TableCapture uses a dual OCR approach:

#### Primary: Apple Vision Framework (Native macOS)

- No external dependencies
- Fast and accurate for most tables
- Uses `VNRecognizeTextRequest` for text recognition
- Custom logic groups text by Y coordinate to detect rows

```swift
// Simplified flow:
1. Load image as CGImage
2. Create VNRecognizeTextRequest
3. Group VNRecognizedTextObservation by Y coordinate (rows)
4. Sort cells within each row by X coordinate (columns)
5. Convert to CSV/Markdown format
```

#### Fallback: Tesseract OCR

- Used for challenging cases (e.g., single letters)
- Integrated via Tesseract-macOS wrapper
- See [ACKNOWLEDGMENTS.md](ACKNOWLEDGMENTS.md) for library details

### Alternative Approaches Considered

#### img2table (Python) - Not Used

While `img2table` is specifically designed for table extraction, it was not chosen due to:
- External Python dependency
- Harder to install and bundle
- Would require shipping Python runtime

```python
# Example of what img2table usage would look like:
from img2table.document import Image
from img2table.ocr import TesseractOCR

ocr = TesseractOCR(n_threads=1, lang="eng")
doc = Image(src=image_path)
tables = doc.extract_tables(ocr=ocr, implicit_rows=True, borderless_tables=True)
```

---

## Submitting Changes

### Pull Request Process

1. **Fork the repository** and create your branch from `main`
2. **Write tests** for any new functionality
3. **Run all tests** to ensure nothing is broken
4. **Update documentation** if you've changed APIs or added features
5. **Submit a pull request** with a clear description of changes

### Code Style

- Follow Swift best practices and existing code patterns
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions focused and small

### Commit Messages

- Use clear, descriptive commit messages
- Start with a verb (Add, Fix, Update, Remove, etc.)
- Reference issues when applicable (e.g., "Fix #123: ...")

---

## Questions?

If you have questions or need help:
- Open an issue on GitHub
- Check existing issues for similar questions

Thank you for contributing!
