//
//  ImagePreprocessor.swift
//  TableCapture
//
//  Chainable image preprocessing operations for OCR optimization
//

import Foundation
import AppKit
import CoreImage

/// A wrapper around CGImage that provides chainable preprocessing operations
/// and tracks metadata about applied transformations
struct ProcessedImage {
    let image: CGImage
    let metadata: [String]

    // MARK: - Initialization

    /// Create from NSImage
    init?(nsImage: NSImage) {
        guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        self.image = cgImage
        self.metadata = []
    }

    /// Create from CGImage (internal use)
    private init(image: CGImage, metadata: [String]) {
        self.image = image
        self.metadata = metadata
    }

    // MARK: - Conversion

    /// Convert back to NSImage
    func toNSImage() -> NSImage {
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }

    // MARK: - Chainable Operations

    /// Upscale image by a given factor
    /// - Parameter factor: Scale multiplier (e.g., 2.0 = double size)
    /// - Returns: New ProcessedImage with upscaled image
    func upscale(factor: CGFloat = 2.0) -> ProcessedImage {
        let newWidth = Int(CGFloat(image.width) * factor)
        let newHeight = Int(CGFloat(image.height) * factor)

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
            return self
        }

        // High quality interpolation for smooth upscaling
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))

        guard let upscaledImage = context.makeImage() else {
            return self
        }

        let newMetadata = metadata + ["Upscaled \(String(format: "%.1fx", factor)) (\(image.width)×\(image.height) → \(newWidth)×\(newHeight))"]
        return ProcessedImage(image: upscaledImage, metadata: newMetadata)
    }

    /// Upscale to a minimum height (for OCR optimization)
    /// - Parameter minHeight: Minimum height in pixels
    /// - Returns: New ProcessedImage, upscaled only if current height < minHeight
    func upscaleToMinHeight(_ minHeight: Int = 1200) -> ProcessedImage {
        guard image.height < minHeight else {
            return self // Already large enough
        }

        let scaleFactor = max(2.0, CGFloat(minHeight) / CGFloat(image.height))
        return upscale(factor: scaleFactor)
    }

    /// Convert image to grayscale
    /// - Returns: New ProcessedImage in grayscale
    func grayscale() -> ProcessedImage {
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let width = image.width
        let height = image.height

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return self
        }

        // Draw original image in grayscale
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let grayscaleImage = context.makeImage() else {
            return self
        }

        let newMetadata = metadata + ["Grayscale"]
        return ProcessedImage(image: grayscaleImage, metadata: newMetadata)
    }

    /// Enhance contrast and brightness
    /// - Parameters:
    ///   - contrast: Contrast multiplier (1.0 = no change, >1.0 = more contrast)
    ///   - brightness: Brightness adjustment (-1.0 to 1.0, 0 = no change)
    /// - Returns: New ProcessedImage with enhanced contrast
    func enhanceContrast(contrast: CGFloat = 1.3, brightness: CGFloat = 0.05) -> ProcessedImage {
        let ciImage = CIImage(cgImage: image)
        let filter = CIFilter(name: "CIColorControls")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(contrast, forKey: kCIInputContrastKey)
        filter?.setValue(brightness, forKey: kCIInputBrightnessKey)

        guard let outputImage = filter?.outputImage,
              let enhancedImage = CIContext(options: nil).createCGImage(outputImage, from: outputImage.extent) else {
            return self
        }

        let newMetadata = metadata + ["Enhanced contrast \(String(format: "%.1fx", contrast)), brightness \(String(format: "%.2f", brightness))"]
        return ProcessedImage(image: enhancedImage, metadata: newMetadata)
    }

    /// Binarize image (convert to pure black and white)
    /// - Parameters:
    ///   - exposure: Exposure adjustment (0.0 = no change, higher = more white)
    ///   - threshold: Contrast threshold for binarization (higher = more aggressive)
    /// - Returns: New ProcessedImage binarized to black and white
    func binarize(exposure: CGFloat = 0.5, threshold: CGFloat = 2.0) -> ProcessedImage {
        let ciImage = CIImage(cgImage: image)

        // Apply exposure adjustment to create strong black/white separation
        let exposureFilter = CIFilter(name: "CIExposureAdjust")
        exposureFilter?.setValue(ciImage, forKey: kCIInputImageKey)
        exposureFilter?.setValue(exposure, forKey: kCIInputEVKey)

        guard let exposedImage = exposureFilter?.outputImage else {
            return self
        }

        // Apply color threshold to binarize
        let thresholdFilter = CIFilter(name: "CIColorControls")
        thresholdFilter?.setValue(exposedImage, forKey: kCIInputImageKey)
        thresholdFilter?.setValue(threshold, forKey: kCIInputContrastKey)
        thresholdFilter?.setValue(0, forKey: kCIInputSaturationKey) // Remove any color

        guard let outputImage = thresholdFilter?.outputImage,
              let binarizedImage = CIContext(options: nil).createCGImage(outputImage, from: outputImage.extent) else {
            return self
        }

        let newMetadata = metadata + ["Binarized (exposure: \(String(format: "%.1f", exposure)), threshold: \(String(format: "%.1f", threshold)))"]
        return ProcessedImage(image: binarizedImage, metadata: newMetadata)
    }
}
