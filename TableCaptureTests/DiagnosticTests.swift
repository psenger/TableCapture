//
//  DiagnosticTests.swift
//  TableCaptureTests
//
//  Diagnostic tests to debug OCR issues
//

import Testing
import Foundation
import AppKit
import Vision
@testable import TableCapture

// MARK: - Helper Functions

func upscaleForDiagnostic(_ cgImage: CGImage) -> CGImage {
    let scaleFactor = 2.0  // Match the production scale factor
    let newWidth = Int(Double(cgImage.width) * scaleFactor)
    let newHeight = Int(Double(cgImage.height) * scaleFactor)

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

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

    // Fill with white background
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: newWidth, height: newHeight))

    context.interpolationQuality = .high
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))

    return context.makeImage() ?? cgImage
}

// MARK: - Diagnostic Tests

struct DiagnosticTests {

    @Test("Two-column image - Raw OCR output (no grid)")
    @MainActor
    func diagnoseRawOCRTwoColumn() async throws {
        let image = try loadTestImage(named: "two-column-multiline")

        print("\n========================================")
        print("IMAGE LOADING DEBUG")
        print("========================================")
        print("NSImage size: \(image.size)")
        print("NSImage representations: \(image.representations.count)")
        for rep in image.representations {
            print("  - \(type(of: rep)): \(rep.pixelsWide)x\(rep.pixelsHigh)")
        }

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("Failed to convert NSImage to CGImage")
            return
        }

        print("ORIGINAL CGImage size: \(cgImage.width)x\(cgImage.height)")
        print("CGImage colorSpace: \(cgImage.colorSpace?.name ?? "nil" as CFString)")
        print("CGImage bitsPerPixel: \(cgImage.bitsPerPixel)")
        print("CGImage alphaInfo: \(cgImage.alphaInfo.rawValue)")

        // Calculate approximate text height
        let imageHeight = CGFloat(cgImage.height)
        let estimatedTextHeightPerLine = imageHeight / 3.0  // 3 rows
        let normalizedTextHeight = estimatedTextHeightPerLine / imageHeight
        print("Estimated text height per line: \(Int(estimatedTextHeightPerLine))px (\(String(format: "%.3f", normalizedTextHeight)) normalized)")
        print("⚠️ Vision OCR typically needs text to be at least 10-15 pixels tall")

        // Try upscaling
        print("\n--- UPSCALING IMAGE ---")
        let upscaledImage = upscaleForDiagnostic(cgImage)
        print("UPSCALED CGImage size: \(upscaledImage.width)x\(upscaledImage.height)")

        // Try FAST recognition level first
        print("\n--- TRYING FAST RECOGNITION LEVEL ---")
        let fastRequest = VNRecognizeTextRequest()
        fastRequest.recognitionLevel = .fast
        fastRequest.usesLanguageCorrection = false

        let fastHandler = VNImageRequestHandler(cgImage: upscaledImage, options: [:])
        try fastHandler.perform([fastRequest])

        if let fastObs = fastRequest.results, !fastObs.isEmpty {
            print("✅ FAST recognition found \(fastObs.count) text items!")
            for (i, obs) in fastObs.enumerated() {
                if let text = obs.topCandidates(1).first?.string {
                    print("  [\(i)] \(text)")
                }
            }
        } else {
            print("❌ FAST recognition found nothing")
        }

        // Try ACCURATE recognition level
        print("\n--- TRYING ACCURATE RECOGNITION LEVEL ---")
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]
        request.minimumTextHeight = 0.0  // Detect any size text

        let handler = VNImageRequestHandler(cgImage: upscaledImage, options: [:])
        try handler.perform([request])

        guard let observations = request.results, !observations.isEmpty else {
            print("❌ NO TEXT DETECTED BY VISION FRAMEWORK!")
            print("This means the OCR cannot see any text in the image.")
            print("\nPossible causes:")
            print("- Text is too small")
            print("- Text color is too light/low contrast")
            print("- Image quality is poor")
            print("- Image is blank or corrupted")
            return
        }

        print("""

        ========================================
        RAW VISION OCR OUTPUT
        ========================================
        Image: two-column-multiline.png
        Total text observations: \(observations.count)

        """)

        for (index, observation) in observations.enumerated() {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let text = candidate.string
            let bounds = observation.boundingBox

            print("""
            [\(index)] Text: "\(text)"
                   Confidence: \(String(format: "%.2f", candidate.confidence))
                   Bounding Box: x=\(String(format: "%.3f", bounds.minX)) y=\(String(format: "%.3f", bounds.minY)) w=\(String(format: "%.3f", bounds.width)) h=\(String(format: "%.3f", bounds.height))

            """)
        }

        print("""
        ========================================
        ANALYSIS:
        ========================================
        Expected to find: A, C, E, B, D
        Actually found: \(observations.count) text items

        """)
    }

    @Test("Simple hello image - Raw OCR output")
    @MainActor
    func diagnoseRawOCRSimpleHello() async throws {
        let image = try loadTestImage(named: "simple-hello")

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("Failed to convert NSImage to CGImage")
            return
        }

        print("\n========================================")
        print("SIMPLE HELLO IMAGE TEST")
        print("========================================")
        print("Image size: \(cgImage.width)x\(cgImage.height)")
        print("Color space: \(cgImage.colorSpace?.name ?? "nil" as CFString)")

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let observations = request.results, !observations.isEmpty else {
            print("❌ NO TEXT DETECTED - Vision framework may be broken!")
            return
        }

        print("✅ Found \(observations.count) text observation(s)")

        for (index, observation) in observations.enumerated() {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let text = candidate.string
            let bounds = observation.boundingBox

            print("""
            [\(index)] Text: "\(text)"
                   Confidence: \(String(format: "%.2f", candidate.confidence))
                   Bounding Box: x=\(String(format: "%.3f", bounds.minX)) y=\(String(format: "%.3f", bounds.minY)) w=\(String(format: "%.3f", bounds.width)) h=\(String(format: "%.3f", bounds.height))

            """)
        }

        print("========================================\n")

        // Now try the EXACT SAME image but upscaled
        print("\n--- NOW TESTING UPSCALED VERSION OF SIMPLE-HELLO ---")
        let upscaled = upscaleForDiagnostic(cgImage)
        print("Upscaled to: \(upscaled.width)x\(upscaled.height)")

        let upRequest = VNRecognizeTextRequest()
        upRequest.recognitionLevel = .accurate
        upRequest.usesLanguageCorrection = false

        let upHandler = VNImageRequestHandler(cgImage: upscaled, options: [:])
        try upHandler.perform([upRequest])

        if let upObs = upRequest.results, !upObs.isEmpty {
            print("✅ Upscaled version found \(upObs.count) text items")
            for (i, obs) in upObs.enumerated() {
                if let text = obs.topCandidates(1).first?.string {
                    print("  [\(i)] \(text)")
                }
            }
        } else {
            print("❌ Upscaled version found NOTHING - upscaling is breaking OCR!")
        }
    }

    @Test("Check image dimensions and properties")
    @MainActor
    func diagnoseImageProperties() throws {
        let images = ["two-column-multiline", "simple-hello", "simple-hello-world"]

        print("""

        ========================================
        IMAGE PROPERTIES
        ========================================

        """)

        for imageName in images {
            do {
                let image = try loadTestImage(named: imageName)
                let size = image.size

                print("""
                Image: \(imageName)
                  Size: \(size.width) x \(size.height) points
                  Has CGImage: \(image.cgImage(forProposedRect: nil, context: nil, hints: nil) != nil)

                """)
            } catch {
                print("Image: \(imageName) - NOT FOUND\n")
            }
        }

        print("========================================\n")
    }
}
