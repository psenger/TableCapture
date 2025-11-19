//
//  CellOCREngine.swift
//  TableCapture
//
//  Protocol for pluggable OCR engines that recognize text in individual cells
//

import Foundation
import AppKit

/// Protocol for OCR engines that extract text from individual cell images
protocol CellOCREngine {
    /// Recognizes text in a single cell image
    /// - Parameter image: The cropped cell image to process
    /// - Returns: Extracted text, or nil if no text found
    func recognizeText(in image: NSImage) -> String?

    /// Human-readable name of the OCR engine
    var name: String { get }

    /// If true, preserve newlines in extracted text; if false, join lines with spaces
    var preserveMultilineFormatting: Bool { get set }
}
