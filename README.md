# Table Capture

A lightweight macOS menu bar app that captures screenshots of tables and converts them to CSV or Markdown format and puts it in the buffer suitable for pasting.

![macOS](https://img.shields.io/badge/macOS-12.3+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.5+-orange.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)


## Development

### macOS Security & Permissions Issues

#### Why Does Rebuilding Break Permissions?

When you rebuild the app, macOS often treats it as a "different" application even though it's the same code. This happens because:

1. **Code Signature Changes**: Each build gets a new signature, and macOS ties permissions (like Screen Recording) to that signature
2. **Cached Permissions**: The old permission is still registered but for the "old" app signature
3. **macOS Gets Confused**: It sees your app as brand new and blocks it

#### Solutions

##### Quick Fix (During Development)

```bash
# 1. Kill the app completely
killall TableCapture

# 2. Reset Screen Recording permissions for your app
tccutil reset ScreenCapture com.philipasenger.TableCapture

# 3. Rebuild and run in Xcode
# You'll need to re-grant permission in System Settings → Privacy & Security → Screen Recording
```

##### Better Fix (Consistent Identity)

Set a **stable code signing identity** in Xcode:

1. Go to your project settings → **Signing & Capabilities**
2. Enable **Automatically manage signing**
3. Make sure you have a consistent **Team** selected
4. Ensure your **Bundle Identifier** never changes (e.g., `com.yourname.TableCapture`)

This helps macOS recognize your app across rebuilds.

##### Nuclear Option (When All Else Fails)

```bash
# Reset ALL TCC (privacy) permissions for your app - use carefully!
tccutil reset All com.philipasenger.TableCapture
```

⚠️ **Note**: You'll need to re-grant Screen Recording permission after each rebuild during development. This is annoying but normal for macOS security.

#### For Distribution (Eventually)

When you're ready to distribute the app:
- Sign with a **Developer ID** certificate
- **Notarize** the app with Apple

This makes the signature consistent and permissions stick between launches for your users.

## Design notes:

OCR Feature:

### **Option 1: img2table (Python) - EASIEST**

This is a Python library **specifically designed** for extracting tables from images. It's perfect for your use case!

Problem: external platform dep and hard to install. 

**Install:**
```bash
pip install img2table
pip install pytesseract
# Also install Tesseract OCR:
brew install tesseract
```

**Python Script** (`table_extractor.py`):
```python
#!/usr/bin/env python3
import sys
from img2table.document import Image
from img2table.ocr import TesseractOCR

def extract_table(image_path):
    # Initialize OCR
    ocr = TesseractOCR(n_threads=1, lang="eng")
    
    # Load image
    doc = Image(src=image_path)
    
    # Extract tables
    tables = doc.extract_tables(ocr=ocr, implicit_rows=True, borderless_tables=True)
    
    if not tables:
        print("ERROR: No tables found in image")
        return
    
    # Get first table and convert to CSV
    table = tables[0]
    csv_output = table.df.to_csv(index=False)
    print(csv_output)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 table_extractor.py <image_path>")
        sys.exit(1)
    
    extract_table(sys.argv[1])
```

**Usage from your Swift app:**
```swift
task.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
task.arguments = ["/path/to/table_extractor.py", url.path]
```
 
### **Option 2: Native macOS Vision Framework** 

Use Apple's built-in OCR (no external dependencies, but requires custom table logic).

This would be all Swift code, no external program needed:

```swift
import Vision
import AppKit

func processImage(at url: URL) {
    guard let image = NSImage(contentsOf: url),
          let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        print("Failed to load image")
        return
    }
    
    let request = VNRecognizeTextRequest { request, error in
        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            return
        }
        
        // Group text by Y coordinate to detect rows
        var rows: [Int: [(x: CGFloat, text: String)]] = [:]
        
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            
            let y = Int(observation.boundingBox.origin.y * 1000)
            let x = observation.boundingBox.origin.x
            
            if rows[y] == nil {
                rows[y] = []
            }
            rows[y]?.append((x: x, text: topCandidate.string))
        }
        
        // Convert to CSV
        var csvLines: [String] = []
        for y in rows.keys.sorted(by: >) {  // Sort top to bottom
            let sortedCells = rows[y]!.sorted { $0.x < $1.x }  // Sort left to right
            let line = sortedCells.map { $0.text }.joined(separator: ",")
            csvLines.append(line)
        }
        
        let csv = csvLines.joined(separator: "\n")
        print(csv)
        
        // Copy to clipboard
        DispatchQueue.main.async {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(csv, forType: .string)
            
            self.showSuccessAlert()
        }
    }
    
    request.recognitionLevel = .accurate
    
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    try? handler.perform([request])
}
```

