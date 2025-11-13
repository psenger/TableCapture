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

    // OCR engine for text recognition (pluggable)
    private var ocrEngine: CellOCREngine

    // Debug output directory (set from environment variable)
    private let debugOutputDir: String?
    private let debugTestName: String?
    private var debugTestSubdirectory: String?

    // Shared timestamp directory for the entire test run (class variable)
    private static var sharedTimestampDir: String?

    init(image: NSImage, autoDetectGrid: Bool = true, testName: String? = nil, ocrEngine: CellOCREngine? = nil) {
        self.originalImage = image
        // Default to Tesseract if no engine specified
        self.ocrEngine = ocrEngine ?? TesseractOCREngine(preserveMultilineFormatting: false)
        self.displayImage = image
        self.debugTestName = testName

        // Read debug output directory from environment
        self.debugOutputDir = ProcessInfo.processInfo.environment["DEBUG_OUTPUT_DIR"]

        // Create test-specific subdirectory if debug output is enabled AND we have a test name
        // This prevents debug output during normal app usage (when testName is nil)
        if let baseDir = debugOutputDir, testName != nil {
            // Create or reuse the shared timestamp directory
            if TableEditorViewModel.sharedTimestampDir == nil {
                // Try to reuse a recent directory (within last 60 seconds) to avoid multiple timestamps in same test run
                var timestampDirPath: String?
                let fileManager = FileManager.default

                if let existingDirs = try? fileManager.contentsOfDirectory(atPath: baseDir) {
                    let recentDirs = existingDirs.filter { dirName in
                        let fullPath = (baseDir as NSString).appendingPathComponent(dirName)
                        var isDirectory: ObjCBool = false
                        guard fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory),
                              isDirectory.boolValue else { return false }

                        // Check if directory was created in last 60 seconds
                        if let attrs = try? fileManager.attributesOfItem(atPath: fullPath),
                           let creationDate = attrs[.creationDate] as? Date {
                            return Date().timeIntervalSince(creationDate) < 60
                        }
                        return false
                    }.sorted(by: >)  // Most recent first

                    if let recentDir = recentDirs.first {
                        timestampDirPath = (baseDir as NSString).appendingPathComponent(recentDir)
                    }
                }

                // Create new timestamp directory if none found
                if timestampDirPath == nil {
                    let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
                    timestampDirPath = (baseDir as NSString).appendingPathComponent(timestamp)
                    do {
                        try fileManager.createDirectory(atPath: timestampDirPath!, withIntermediateDirectories: true)
                    } catch {
                        timestampDirPath = nil
                    }
                }

                TableEditorViewModel.sharedTimestampDir = timestampDirPath
            }

            // Create test-specific subdirectory within the timestamp directory
            if let timestampDir = TableEditorViewModel.sharedTimestampDir {
                // Safe to force unwrap testName here because we already checked testName != nil above
                let subdirPath = (timestampDir as NSString).appendingPathComponent(testName!)

                do {
                    try FileManager.default.createDirectory(atPath: subdirPath, withIntermediateDirectories: true)
                    self.debugTestSubdirectory = subdirPath

                    // Save the original test image
                    if let tiffData = image.tiffRepresentation,
                       let bitmapRep = NSBitmapImageRep(data: tiffData),
                       let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                        let imageURL = URL(fileURLWithPath: subdirPath).appendingPathComponent("test_image.png")
                        try pngData.write(to: imageURL)
                    }
                } catch {
                    self.debugTestSubdirectory = nil
                }
            } else {
                self.debugTestSubdirectory = nil
            }
        } else {
            self.debugTestSubdirectory = nil
        }

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

        // Use the configured OCR engine
        extractWithOCR(image: originalImage, cells: cells, format: format, completion: completion)
    }

    // MARK: - Generic OCR Extraction

    private func extractWithOCR(image: NSImage, cells: [[CGRect]], format: TableFormat, completion: @escaping (Result<String, Error>) -> Void) {
        // Update the OCR engine's formatting preference
        ocrEngine.preserveMultilineFormatting = preserveMultilineFormatting

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

                // Pre-process the cell image for better OCR accuracy
                let processedImage = preprocessCellForOCR(cellImage)

                // Run OCR on this cell using the configured engine
                let cellText = ocrEngine.recognizeText(in: processedImage) ?? ""
                rowTexts.append(cellText)

                // Debug output: save cell image and text
                if let debugDir = debugTestSubdirectory {
                    saveCellDebugInfo(
                        originalCellImage: cellImage,
                        preprocessedCellImage: processedImage,
                        cellBounds: cellBounds,
                        rowIndex: rowIndex,
                        colIndex: colIndex,
                        extractedText: cellText,
                        outputDir: debugDir
                    )
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

    // MARK: - OCR Preprocessing

    private func preprocessCellForOCR(_ cellImage: NSImage) -> NSImage {
        // Guard extracts the CGImage from NSImage, which is needed for low-level image processing
        // operations like upscaling, grayscale conversion, contrast enhancement, etc.
        // If extraction fails (rare), we safely return the original image unchanged.
        guard let cgImage = cellImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return cellImage
        }

        // Just return the original cell image without any preprocessing
        return cellImage

        // Step 1: Upscale if the cell is too small (DISABLED)
        // let minCellHeight = 40  // Tesseract works best with text height >= 30-40px
        // var processedImage = cgImage
        //
        // if cgImage.height < minCellHeight {
        //     let scaleFactor = max(2.0, Double(minCellHeight) / Double(cgImage.height))
        //     processedImage = upscaleCellImage(cgImage, scaleFactor: scaleFactor)
        //
        //     #if DEBUG
        //     print("    📏 Upscaled cell from \(cgImage.height)px to \(processedImage.height)px (scale: \(String(format: "%.1f", scaleFactor))x)")
        //     #endif
        // }
        //
        // return NSImage(cgImage: processedImage, size: NSSize(width: processedImage.width, height: processedImage.height))

        // Step 2: Convert to grayscale
        // let grayscaleImage = convertToGrayscale(processedImage)

        // Step 3: Enhance contrast
        // let contrastedImage = enhanceContrast(grayscaleImage)

        // Step 4: Binarize (convert to pure black and white)
        // let binarizedImage = binarizeImage(contrastedImage)

        // return NSImage(cgImage: binarizedImage, size: NSSize(width: binarizedImage.width, height: binarizedImage.height))
    }

    private func upscaleCellImage(_ cgImage: CGImage, scaleFactor: Double) -> CGImage {
        let newWidth = Int(Double(cgImage.width) * scaleFactor)
        let newHeight = Int(Double(cgImage.height) * scaleFactor)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        // Use premultiplied alpha to preserve image transparency and anti-aliasing
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)

        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: newWidth * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return cgImage
        }

        // DO NOT fill with white - preserve original image appearance
        // High quality interpolation for smooth upscaling
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))

        return context.makeImage() ?? cgImage
    }

    private func convertToGrayscale(_ cgImage: CGImage) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let width = cgImage.width
        let height = cgImage.height

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return cgImage
        }

        // Draw original image in grayscale
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        return context.makeImage() ?? cgImage
    }

    private func enhanceContrast(_ cgImage: CGImage) -> CGImage {
        let ciImage = CIImage(cgImage: cgImage)
        let filter = CIFilter(name: "CIColorControls")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(1.3, forKey: kCIInputContrastKey)  // Increase contrast by 30%
        filter?.setValue(0.05, forKey: kCIInputBrightnessKey)  // Slight brightness boost

        guard let outputImage = filter?.outputImage,
              let cgContext = CIContext(options: nil).createCGImage(outputImage, from: outputImage.extent) else {
            return cgImage
        }

        return cgContext
    }

    private func binarizeImage(_ cgImage: CGImage) -> CGImage {
        // Use Otsu's thresholding approximation via CIFilter
        let ciImage = CIImage(cgImage: cgImage)

        // Apply exposure adjustment to create strong black/white separation
        let exposureFilter = CIFilter(name: "CIExposureAdjust")
        exposureFilter?.setValue(ciImage, forKey: kCIInputImageKey)
        exposureFilter?.setValue(0.5, forKey: kCIInputEVKey)

        guard let exposedImage = exposureFilter?.outputImage else {
            return cgImage
        }

        // Apply color threshold to binarize
        let thresholdFilter = CIFilter(name: "CIColorControls")
        thresholdFilter?.setValue(exposedImage, forKey: kCIInputImageKey)
        thresholdFilter?.setValue(2.0, forKey: kCIInputContrastKey)  // Very high contrast
        thresholdFilter?.setValue(0, forKey: kCIInputSaturationKey)  // Remove any color

        guard let outputImage = thresholdFilter?.outputImage,
              let binarized = CIContext(options: nil).createCGImage(outputImage, from: outputImage.extent) else {
            return cgImage
        }

        return binarized
    }

    private func upscaleImageForOCR(_ cgImage: CGImage) -> CGImage {
        let minRecommendedHeight = 1200 // Minimum height for good OCR (increased from 800)
        let currentHeight = cgImage.height

        // If image is already large enough, return as-is
        guard currentHeight < minRecommendedHeight else {
            return cgImage
        }

        // Calculate scale factor (at least 2x, or whatever brings us to minRecommendedHeight)
        let scaleFactor = max(2.0, Double(minRecommendedHeight) / Double(currentHeight))
        let newWidth = Int(Double(cgImage.width) * scaleFactor)
        let newHeight = Int(Double(cgImage.height) * scaleFactor)

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
            return upscaledImage
        } else {
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

        // Reverse to get top-to-bottom order (we built bottom-to-top due to CGImage coordinates)
        return cells.reversed()
    }
    
    private func saveCellDebugInfo(
        originalCellImage: NSImage,
        preprocessedCellImage: NSImage,
        cellBounds: CGRect,
        rowIndex: Int,
        colIndex: Int,
        extractedText: String,
        outputDir: String
    ) {
        let cellDirName = String(format: "%02d_row_%02d_col", rowIndex, colIndex)
        let cellDirURL = URL(fileURLWithPath: outputDir).appendingPathComponent(cellDirName)

        // Create directory for this cell
        do {
            try FileManager.default.createDirectory(at: cellDirURL, withIntermediateDirectories: true)

            // Save the original cropped cell image
            if let tiffData = originalCellImage.tiffRepresentation,
               let bitmapRep = NSBitmapImageRep(data: tiffData),
               let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                let imageURL = cellDirURL.appendingPathComponent("cell_original.png")
                try pngData.write(to: imageURL)
            }

            // Save the preprocessed cell image
            if let tiffData = preprocessedCellImage.tiffRepresentation,
               let bitmapRep = NSBitmapImageRep(data: tiffData),
               let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                let imageURL = cellDirURL.appendingPathComponent("cell_preprocessed.png")
                try pngData.write(to: imageURL)
            }

            // Save the extracted text
            let textURL = cellDirURL.appendingPathComponent("text.txt")
            try extractedText.write(to: textURL, atomically: true, encoding: .utf8)

            // Save the crop dimensions
            let dimensionsURL = cellDirURL.appendingPathComponent("dimensions.txt")
            let dimensionsInfo = """
                Cell Position: Row \(rowIndex), Column \(colIndex)

                Normalized Bounds (0.0-1.0):
                  Origin: (x: \(cellBounds.origin.x), y: \(cellBounds.origin.y))
                  Size: (width: \(cellBounds.size.width), height: \(cellBounds.size.height))

                Original Image Size:
                  Width: \(originalCellImage.size.width)px
                  Height: \(originalCellImage.size.height)px

                Preprocessed Image Size:
                  Width: \(preprocessedCellImage.size.width)px
                  Height: \(preprocessedCellImage.size.height)px

                Extracted Text:
                '\(extractedText)'
                """
            try dimensionsInfo.write(to: dimensionsURL, atomically: true, encoding: .utf8)

        } catch {
            // Silently fail - this is debug output only
        }
    }
    
    private func formatAsCSV(_ table: [[String]]) -> String {
        var lines: [String] = []
        for row in table {
            // Defensive approach: Always quote all fields (RFC 4180 compliant)
            let escapedRow = row.map { cell -> String in
                // Escape any double quotes by doubling them
                let escaped = cell.replacingOccurrences(of: "\"", with: "\"\"")
                // Always wrap in double quotes (defensive CSV)
                return "\"\(escaped)\""
            }
            lines.append(escapedRow.joined(separator: ","))
        }
        // Join rows with newlines (newlines within cells are preserved inside quotes)
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
