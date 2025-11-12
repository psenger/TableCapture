//
//  TableEditorView.swift
//  TableCapture
//
//  Visual editor for adjusting table cell boundaries
//

import SwiftUI
import AppKit
import Vision
import Combine

struct TableEditorView: View {
    let image: NSImage
    let onComplete: (Result<String, Error>, TableFormat) -> Void
    let onCancel: () -> Void

    @StateObject private var viewModel: TableEditorViewModel

    init(image: NSImage, onComplete: @escaping (Result<String, Error>, TableFormat) -> Void, onCancel: @escaping () -> Void) {
        self.image = image
        self.onComplete = onComplete
        self.onCancel = onCancel
        _viewModel = StateObject(wrappedValue: TableEditorViewModel(image: image))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar - Two Rows
            VStack(spacing: 8) {
                // Row 1: Title and Grid Controls
                HStack(spacing: 12) {
                    Text("Adjust Table Grid")
                        .font(.headline)

                    Spacer()

                    // Grid controls
                    HStack(spacing: 8) {
                        Button(action: { viewModel.addColumn() }) {
                            Label("Add Column", systemImage: "rectangle.split.3x1")
                        }
                        .help("Add a vertical column divider")

                        Button(action: { viewModel.addRow() }) {
                            Label("Add Row", systemImage: "rectangle.split.1x2")
                        }
                        .help("Add a horizontal row divider")

                        Divider()
                            .frame(height: 20)

                        Button(action: { viewModel.removeSelectedLine() }) {
                            Label("Delete Line", systemImage: "trash")
                        }
                        .disabled(viewModel.selectedLine == nil)
                        .help("Delete selected grid line (⌫)")

                        Button(action: { viewModel.clearAllLines() }) {
                            Label("Clear All", systemImage: "xmark.circle")
                        }
                        .help("Remove all grid lines")
                    }
                }

                // Row 2: Multi-line option and Action Buttons
                HStack(spacing: 8) {
                    Toggle("Preserve multi-line formatting", isOn: $viewModel.preserveMultilineFormatting)
                        .help("When enabled:\n• Markdown: Lines joined with <br/>\n• CSV: Lines joined with \\n (cell quoted)")

                    Spacer()

                    Button("Cancel") {
                        onCancel()
                    }
                    .keyboardShortcut(.cancelAction)

                    Button("Extract as CSV") {
                        viewModel.extractTable(format: .csv) { result in
                            onComplete(result, .csv)
                        }
                    }
                    .keyboardShortcut("c", modifiers: [.command])
                    .disabled(viewModel.verticalLines.isEmpty && viewModel.horizontalLines.isEmpty)

                    Button("Extract as Markdown") {
                        viewModel.extractTable(format: .markdown) { result in
                            onComplete(result, .markdown)
                        }
                    }
                    .keyboardShortcut("m", modifiers: [.command])
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.verticalLines.isEmpty && viewModel.horizontalLines.isEmpty)
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Image with grid overlay
            GeometryReader { geometry in
                ZStack {
                    // Background image
                    if let nsImage = viewModel.displayImage {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                    
                    // Grid overlay
                    GridOverlayView(
                        verticalLines: $viewModel.verticalLines,
                        horizontalLines: $viewModel.horizontalLines,
                        imageSize: viewModel.imageSize,
                        selectedLine: $viewModel.selectedLine
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // Instructions
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 4) {
                    Text("• Click the circular handle on any line to select it (turns blue)")
                    Text("• Drag handles to reposition grid lines")
                    Text("• Press Delete or Backspace to remove selected line")
                    Text("• Use buttons above to add/remove lines")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 800, minHeight: 600)
        .onKeyPress(.delete) {
            viewModel.removeSelectedLine()
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "\u{8}")) { _ in
            // Handle backspace (ASCII BS character 0x08)
            viewModel.removeSelectedLine()
            return .handled
        }
    }
}

// MARK: - Grid Overlay View

struct GridOverlayView: View {
    @Binding var verticalLines: [CGFloat]
    @Binding var horizontalLines: [CGFloat]
    let imageSize: CGSize
    @Binding var selectedLine: GridLine?
    
    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / imageSize.width,
                          geometry.size.height / imageSize.height)
            let scaledWidth = imageSize.width * scale
            let scaledHeight = imageSize.height * scale
            let offsetX = (geometry.size.width - scaledWidth) / 2
            let offsetY = (geometry.size.height - scaledHeight) / 2
            
            ZStack {
                // Red border box around image
                Rectangle()
                    .stroke(Color.red.opacity(0.6), lineWidth: 3)
                    .frame(width: scaledWidth, height: scaledHeight)
                    .position(x: offsetX + scaledWidth / 2, y: offsetY + scaledHeight / 2)

                // Vertical lines with drag handles
                ForEach(Array(verticalLines.enumerated()), id: \.offset) { index, xPos in
                    GridLineView(
                        position: xPos,
                        isVertical: true,
                        isSelected: selectedLine == .vertical(index),
                        scale: scale,
                        scaledWidth: scaledWidth,
                        scaledHeight: scaledHeight,
                        offsetX: offsetX,
                        offsetY: offsetY,
                        onSelect: {
                            selectedLine = .vertical(index)
                        },
                        onDrag: { newPosition in
                            verticalLines[index] = max(0.01, min(0.99, newPosition))
                        }
                    )
                }
                
                // Horizontal lines with drag handles
                ForEach(Array(horizontalLines.enumerated()), id: \.offset) { index, yPos in
                    GridLineView(
                        position: yPos,
                        isVertical: false,
                        isSelected: selectedLine == .horizontal(index),
                        scale: scale,
                        scaledWidth: scaledWidth,
                        scaledHeight: scaledHeight,
                        offsetX: offsetX,
                        offsetY: offsetY,
                        onSelect: {
                            selectedLine = .horizontal(index)
                        },
                        onDrag: { newPosition in
                            horizontalLines[index] = max(0.01, min(0.99, newPosition))
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Individual Grid Line View

struct GridLineView: View {
    let position: CGFloat
    let isVertical: Bool
    let isSelected: Bool
    let scale: CGFloat
    let scaledWidth: CGFloat
    let scaledHeight: CGFloat
    let offsetX: CGFloat
    let offsetY: CGFloat
    let onSelect: () -> Void
    let onDrag: (CGFloat) -> Void
    
    @State private var isDragging = false
    
    var body: some View {
        if isVertical {
            // Vertical line
            let screenX = offsetX + (position * scaledWidth)
            
            ZStack {
                // The line itself
                Rectangle()
                    .fill(isSelected ? Color.blue.opacity(0.8) : Color.red.opacity(0.6))
                    .frame(width: 3)
                    .frame(height: scaledHeight)
                    .position(x: screenX, y: offsetY + scaledHeight / 2)
                
                // Draggable handle
                Circle()
                    .fill(isSelected ? Color.blue : Color.red)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .position(x: screenX, y: offsetY + scaledHeight / 2)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if !isDragging {
                                    // Select on first drag
                                    onSelect()
                                }
                                isDragging = true
                                let newX = (value.location.x - offsetX) / scaledWidth
                                onDrag(newX)
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
                    .onTapGesture {
                        onSelect()
                    }
                    .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
            }
        } else {
            // Horizontal line
            let screenY = offsetY + ((1 - position) * scaledHeight)
            
            ZStack {
                // The line itself
                Rectangle()
                    .fill(isSelected ? Color.blue.opacity(0.8) : Color.red.opacity(0.6))
                    .frame(height: 3)
                    .frame(width: scaledWidth)
                    .position(x: offsetX + scaledWidth / 2, y: screenY)
                
                // Draggable handle
                Circle()
                    .fill(isSelected ? Color.blue : Color.red)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .position(x: offsetX + scaledWidth / 2, y: screenY)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if !isDragging {
                                    // Select on first drag
                                    onSelect()
                                }
                                isDragging = true
                                let newY = 1 - ((value.location.y - offsetY) / scaledHeight)
                                onDrag(newY)
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
                    .onTapGesture {
                        onSelect()
                    }
                    .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
            }
        }
    }
}

// MARK: - View Model

class TableEditorViewModel: ObservableObject {
    let originalImage: NSImage
    @Published var displayImage: NSImage?
    @Published var verticalLines: [CGFloat] = []
    @Published var horizontalLines: [CGFloat] = []
    @Published var selectedLine: GridLine?
    @Published var preserveMultilineFormatting: Bool = false

    var imageSize: CGSize {
        originalImage.size
    }
    
    private let extractor = AppleVisionExtractor()
    
    init(image: NSImage, autoDetectGrid: Bool = true) {
        self.originalImage = image
        self.displayImage = image
        if autoDetectGrid {
            detectInitialGrid()
        }
    }
    
    func detectInitialGrid() {
        // Use Vision to detect text and suggest initial grid lines
        guard let cgImage = originalImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return
        }
        
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self = self,
                  let observations = request.results as? [VNRecognizedTextObservation] else {
                return
            }
            
            DispatchQueue.main.async {
                self.generateGridFromObservations(observations)
            }
        }
        request.recognitionLevel = .accurate
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }
    
    private func generateGridFromObservations(_ observations: [VNRecognizedTextObservation]) {
        guard !observations.isEmpty else { return }
        
        // Collect left edges (X) and top/bottom edges (Y) of all text
        var xStarts = [CGFloat]()
        var yEdges = [CGFloat]()
        
        for observation in observations {
            let bounds = observation.boundingBox
            xStarts.append(bounds.origin.x)
            yEdges.append(bounds.origin.y)
            yEdges.append(bounds.origin.y + bounds.height)
        }
        
        // Cluster X positions to find column boundaries
        // Use aggressive clustering to avoid too many columns
        let clusteredX = clusterPositions(xStarts.sorted(), threshold: 0.05)
        
        // Remove the leftmost column boundary (we don't need a line at x=0)
        verticalLines = clusteredX.filter { $0 > 0.05 }
        
        // Cluster Y positions to find row boundaries
        let clusteredY = clusterPositions(yEdges.sorted(), threshold: 0.02)
        
        // Remove boundaries too close to edges
        horizontalLines = clusteredY.filter { $0 > 0.05 && $0 < 0.95 }
        
        print("DEBUG: Detected \(verticalLines.count) vertical lines and \(horizontalLines.count) horizontal lines")
    }
    
    private func clusterPositions(_ positions: [CGFloat], threshold: CGFloat) -> [CGFloat] {
        guard !positions.isEmpty else { return [] }
        
        var clusters: [CGFloat] = [positions[0]]
        
        for position in positions {
            if let lastCluster = clusters.last, abs(position - lastCluster) <= threshold {
                // Update cluster center
                clusters[clusters.count - 1] = (lastCluster + position) / 2
            } else {
                clusters.append(position)
            }
        }
        
        return clusters
    }
    
    func addColumn() {
        // Add a vertical line in the middle of the widest gap
        if verticalLines.isEmpty {
            verticalLines.append(0.5)
        } else {
            let sortedLines = verticalLines.sorted()
            var maxGap: CGFloat = 0
            var gapPosition: CGFloat = 0
            
            // Check gap from 0 to first line
            if sortedLines[0] > maxGap {
                maxGap = sortedLines[0]
                gapPosition = sortedLines[0] / 2
            }
            
            // Check gaps between lines
            for i in 0..<sortedLines.count - 1 {
                let gap = sortedLines[i + 1] - sortedLines[i]
                if gap > maxGap {
                    maxGap = gap
                    gapPosition = (sortedLines[i] + sortedLines[i + 1]) / 2
                }
            }
            
            // Check gap from last line to 1
            if (1 - sortedLines.last!) > maxGap {
                gapPosition = (sortedLines.last! + 1) / 2
            }
            
            verticalLines.append(gapPosition)
        }
    }
    
    func addRow() {
        // Add a horizontal line in the middle of the tallest gap
        if horizontalLines.isEmpty {
            horizontalLines.append(0.5)
        } else {
            let sortedLines = horizontalLines.sorted()
            var maxGap: CGFloat = 0
            var gapPosition: CGFloat = 0
            
            // Check gap from 0 to first line
            if sortedLines[0] > maxGap {
                maxGap = sortedLines[0]
                gapPosition = sortedLines[0] / 2
            }
            
            // Check gaps between lines
            for i in 0..<sortedLines.count - 1 {
                let gap = sortedLines[i + 1] - sortedLines[i]
                if gap > maxGap {
                    maxGap = gap
                    gapPosition = (sortedLines[i] + sortedLines[i + 1]) / 2
                }
            }
            
            // Check gap from last line to 1
            if (1 - sortedLines.last!) > maxGap {
                gapPosition = (sortedLines.last! + 1) / 2
            }
            
            horizontalLines.append(gapPosition)
        }
    }
    
    func removeSelectedLine() {
        guard let selected = selectedLine else { return }
        
        // Clear selection FIRST to avoid index issues
        selectedLine = nil
        
        switch selected {
        case .vertical(let index):
            if index >= 0 && index < verticalLines.count {
                verticalLines.remove(at: index)
            }
        case .horizontal(let index):
            if index >= 0 && index < horizontalLines.count {
                horizontalLines.remove(at: index)
            }
        }
    }
    
    func clearAllLines() {
        verticalLines.removeAll()
        horizontalLines.removeAll()
        selectedLine = nil
    }
    
    func extractTable(format: TableFormat, completion: @escaping (Result<String, Error>) -> Void) {
        // Create cells based on grid lines
        let cells = createCellsFromGrid()

        // Use Vision to extract text
        guard let cgImage = originalImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            completion(.failure(TableExtractionError.extractionFailed("Failed to load image")))
            return
        }

        // Upscale image if needed for better OCR accuracy
        // Vision OCR needs text to be at least 10-15 pixels tall
        let upscaledImage = upscaleImageForOCR(cgImage)

        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(.failure(TableExtractionError.noOutput))
                return
            }

            print("🔍 OCR found \(observations.count) text observations")
            for (i, obs) in observations.enumerated() {
                if let text = obs.topCandidates(1).first?.string {
                    let bounds = obs.boundingBox
                    print("  [\(i)] '\(text)' at x=\(String(format: "%.3f", bounds.minX)) y=\(String(format: "%.3f", bounds.minY))")
                }
            }

            // If Vision found no text, fallback to Tesseract
            if observations.isEmpty {
                print("⚠️ Vision OCR found 0 text observations - falling back to Tesseract")
                self.extractWithTesseract(image: self.originalImage, cells: cells, format: format, completion: completion)
                return
            }

            // Assign text to cells
            let table = self.assignTextToCells(observations: observations, cells: cells)

            // Format output
            let output: String
            switch format {
            case .csv:
                output = self.formatAsCSV(table)
            case .markdown:
                output = self.formatAsMarkdown(table)
            }

            completion(.success(output))
        }
        // .fast is documented to be better at individual characters vs .accurate (which is optimized for words)
        // Source: Apple Developer community reports accurate struggles with single characters
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        request.automaticallyDetectsLanguage = false

        // Provide custom words to help recognize single characters and common table content
        // This supplements the built-in dictionary and takes priority
        request.customWords = [
            // Single letters (both cases)
            "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
            "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
            "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
            "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"
        ]

        // Allow recognition of single characters and short strings
        if #available(macOS 13.0, *) {
            request.minimumTextHeight = 0.0  // Detect even very small text
        }

        let handler = VNImageRequestHandler(cgImage: upscaledImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            completion(.failure(error))
        }
    }

    // MARK: - Tesseract Fallback

    private func extractWithTesseract(image: NSImage, cells: [[CGRect]], format: TableFormat, completion: @escaping (Result<String, Error>) -> Void) {
        print("🔧 Using Tesseract OCR for extraction...")

        // Initialize Tesseract
        let tesseract = SLTesseract()
        tesseract.language = "eng"

        // Optional: Configure for specific character sets if needed
        // tesseract.charWhitelist = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 "

        // Extract text from each cell
        var table: [[String]] = []

        for (rowIndex, row) in cells.enumerated() {
            var rowTexts: [String] = []

            for (colIndex, cellBounds) in row.enumerated() {
                // Crop image to cell bounds
                guard let cellImage = cropImageToCell(image: image, cellBounds: cellBounds) else {
                    rowTexts.append("")
                    continue
                }

                // Run Tesseract OCR on this cell
                if let recognizedText = tesseract.recognize(cellImage), !recognizedText.isEmpty {
                    let cleanedText = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
                    rowTexts.append(cleanedText)
                    print("  Cell[\(rowIndex)][\(colIndex)]: '\(cleanedText)'")
                } else {
                    rowTexts.append("")
                }
            }

            table.append(rowTexts)
        }

        // Format output
        let output: String
        switch format {
        case .csv:
            output = self.formatAsCSV(table)
        case .markdown:
            output = self.formatAsMarkdown(table)
        }

        print("✅ Tesseract extraction complete")
        completion(.success(output))
    }

    private func cropImageToCell(image: NSImage, cellBounds: CGRect) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)

        // Convert normalized coordinates to pixel coordinates
        let x = cellBounds.origin.x * imageWidth
        let y = cellBounds.origin.y * imageHeight
        let width = cellBounds.size.width * imageWidth
        let height = cellBounds.size.height * imageHeight

        // Crop the image
        let cropRect = CGRect(x: x, y: y, width: width, height: height)
        guard let croppedCGImage = cgImage.cropping(to: cropRect) else {
            return nil
        }

        return NSImage(cgImage: croppedCGImage, size: NSSize(width: cropRect.width, height: cropRect.height))
    }

    private func upscaleImageForOCR(_ cgImage: CGImage) -> CGImage {
        let minRecommendedHeight = 1200 // Minimum height for good OCR (increased from 800)
        let currentHeight = cgImage.height

        print("🔍 Upscaling check: Current height = \(currentHeight)px, threshold = \(minRecommendedHeight)px")

        // If image is already large enough, return as-is
        guard currentHeight < minRecommendedHeight else {
            print("✅ Image already large enough, no upscaling needed")
            return cgImage
        }

        // Calculate scale factor (at least 2x, or whatever brings us to minRecommendedHeight)
        let scaleFactor = max(2.0, Double(minRecommendedHeight) / Double(currentHeight))
        let newWidth = Int(Double(cgImage.width) * scaleFactor)
        let newHeight = Int(Double(cgImage.height) * scaleFactor)

        print("📈 Upscaling image from \(cgImage.width)x\(currentHeight) to \(newWidth)x\(newHeight) (scale: \(String(format: "%.2f", scaleFactor))x)")

        // Create upscaled image with standardized format
        // IMPORTANT: Use noneSkipLast (no alpha) for better OCR compatibility
        // Vision OCR works better with images that have no alpha channel
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)

        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: newWidth * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return cgImage
        }

        // Fill with white background (since we're removing alpha)
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: newWidth, height: newHeight))

        // Use high quality interpolation
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))

        if let upscaledImage = context.makeImage() {
            print("✅ Successfully upscaled to \(upscaledImage.width)x\(upscaledImage.height)")
            return upscaledImage
        } else {
            print("❌ Failed to create upscaled image, using original")
            return cgImage
        }
    }

    private func createCellsFromGrid() -> [[CGRect]] {
        let sortedVertical = ([0.0] + verticalLines + [1.0]).sorted()
        let sortedHorizontal = Array(([0.0] + horizontalLines + [1.0]).sorted().reversed())
        
        var cells: [[CGRect]] = []
        
        for rowIndex in 0..<(sortedHorizontal.count - 1) {
            var row: [CGRect] = []
            let top = sortedHorizontal[rowIndex]
            let bottom = sortedHorizontal[rowIndex + 1]
            
            for colIndex in 0..<(sortedVertical.count - 1) {
                let left = sortedVertical[colIndex]
                let right = sortedVertical[colIndex + 1]
                
                row.append(CGRect(x: left, y: bottom, width: right - left, height: top - bottom))
            }
            cells.append(row)
        }
        
        return cells
    }
    
    private func assignTextToCells(observations: [VNRecognizedTextObservation], cells: [[CGRect]]) -> [[String]] {
        var table: [[String]] = []

        for row in cells {
            var rowData: [String] = []

            for cell in row {
                var textsInCell: [(String, CGFloat)] = []

                for observation in observations {
                    let textBounds = observation.boundingBox
                    let centerX = textBounds.midX
                    let centerY = textBounds.midY

                    if cell.contains(CGPoint(x: centerX, y: centerY)) {
                        if let text = observation.topCandidates(1).first?.string {
                            textsInCell.append((text, textBounds.origin.y))
                        }
                    }
                }

                // Sort by Y position (top to bottom) and join
                textsInCell.sort { $0.1 > $1.1 }

                // Join with newline if preserving multi-line formatting, otherwise with space
                let separator = preserveMultilineFormatting ? "\n" : " "
                let cellText = textsInCell.map { $0.0 }.joined(separator: separator)
                rowData.append(cellText)
            }

            table.append(rowData)
        }

        return table
    }
    
    private func formatAsCSV(_ table: [[String]]) -> String {
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
    
    private func formatAsMarkdown(_ table: [[String]]) -> String {
        guard !table.isEmpty else { return "" }
        var lines: [String] = []
        let columnCount = table.map { $0.count }.max() ?? 0

        for (index, row) in table.enumerated() {
            var paddedRow = row
            while paddedRow.count < columnCount {
                paddedRow.append("")
            }

            let escapedRow = paddedRow.map { cell -> String in
                var escaped = cell.replacingOccurrences(of: "|", with: "\\|")
                // If preserving multi-line, replace newlines with <br/>
                if preserveMultilineFormatting {
                    escaped = escaped.replacingOccurrences(of: "\n", with: "<br/>")
                }
                return escaped
            }
            lines.append("| " + escapedRow.joined(separator: " | ") + " |")

            if index == 0 {
                let separator = "| " + Array(repeating: "---", count: columnCount).joined(separator: " | ") + " |"
                lines.append(separator)
            }
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - Supporting Types

enum GridLine: Equatable {
    case vertical(Int)
    case horizontal(Int)
}
