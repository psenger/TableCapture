//
//  TableCaptureApp.swift
//  TableCapture
//
//  Created by Philip A Senger on 10/11/2025.
//

import SwiftUI
import ScreenCaptureKit

@main
struct TableCaptureApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var menu: NSMenu?
    var helpWindow: NSWindow?
    var editorWindow: NSWindow?
    var tableExtractor: TableExtractor = AppleVisionExtractor()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the status item (menu bar icon)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "tablecells", accessibilityDescription: "TableCapture")
            button.action = #selector(menuButtonClicked)
            button.target = self
        }

        // Create the menu
        menu = NSMenu()
        menu?.addItem(NSMenuItem(title: "Capture", action: #selector(capture), keyEquivalent: "c"))
        menu?.addItem(NSMenuItem.separator())
        menu?.addItem(NSMenuItem(title: "Help", action: #selector(showHelp), keyEquivalent: "h"))
        menu?.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        statusItem?.menu = menu

        // DEBUG: Auto-load test image feature (disabled for production)
        // #if DEBUG
        // if let debugImagePath = ProcessInfo.processInfo.environment["DEBUG_IMAGE_PATH"] {
        //     var imageURL = URL(fileURLWithPath: debugImagePath)
        //
        //     if !FileManager.default.fileExists(atPath: imageURL.path) {
        //         let projectPath = "/Users/psenger/Developer/TableCapture/"
        //         let relativePath = projectPath + debugImagePath
        //         imageURL = URL(fileURLWithPath: relativePath)
        //     }
        //
        //     if FileManager.default.fileExists(atPath: imageURL.path) {
        //         let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("debug-test-image.png")
        //         do {
        //             try? FileManager.default.removeItem(at: tempURL)
        //             try FileManager.default.copyItem(at: imageURL, to: tempURL)
        //             DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        //                 self.showTableEditor(imageURL: tempURL)
        //             }
        //         } catch {
        //             // Debug image load failed
        //         }
        //     }
        // }
        // #endif
    }
    
    @objc func menuButtonClicked() {
        statusItem?.menu = menu
    }
    
    @objc func capture() {
        #if DEBUG
        print("Capture screen clicked!")
        #endif

        checkScreenRecordingPermission { hasPermission in
            if hasPermission {
                self.performScreenCapture()
            } else {
                self.showPermissionAlert()
            }
        }
    }
    
    @objc func showHelp() {
        if helpWindow == nil {
            let helpView = HelpView()
            let hostingController = NSHostingController(rootView: helpView)
            
            helpWindow = NSWindow(contentViewController: hostingController)
            helpWindow?.title = "TableCapture Help"
            helpWindow?.styleMask = [.titled, .closable, .resizable]
            helpWindow?.center()
            helpWindow?.setFrameAutosaveName("HelpWindow")
        }
        
        helpWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - Screen Recording Permission
    
    func checkScreenRecordingPermission(completion: @escaping (Bool) -> Void) {
        if #available(macOS 12.3, *) {
            Task {
                do {
                    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                    completion(!content.displays.isEmpty)
                } catch {
                    completion(false)
                }
            }
        } else {
            completion(true)
        }
    }
    
    func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = """
        TableCapture needs permission to capture your screen.
        
        Please go to:
        System Settings → Privacy & Security → Screen Recording
        
        Then enable TableCapture and restart the app.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    // MARK: - Screen Capture

    func performScreenCapture() {
        statusItem?.menu = nil

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("capture.png")

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = [
            "-i",
            "-o",
            tempURL.path
        ]

        task.terminationHandler = { process in
            DispatchQueue.main.async {
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    #if DEBUG
                    print("Screenshot saved to: \(tempURL.path)")
                    #endif
                    self.showTableEditor(imageURL: tempURL)
                } else {
                    #if DEBUG
                    print("User cancelled screenshot")
                    #endif
                }

                self.statusItem?.menu = self.menu
            }
        }

        do {
            try task.run()
        } catch {
            #if DEBUG
            print("Error capturing screen: \(error)")
            #endif
            statusItem?.menu = menu
        }
    }

    // MARK: - Table Editor

    func showTableEditor(imageURL: URL) {
        #if DEBUG
        print("📂 Attempting to load image from: \(imageURL.path)")
        print("📂 File exists: \(FileManager.default.fileExists(atPath: imageURL.path))")
        print("📂 Is readable: \(FileManager.default.isReadableFile(atPath: imageURL.path))")
        #endif

        // Try loading via Data first (more reliable with file permissions)
        var image: NSImage?
        if let imageData = try? Data(contentsOf: imageURL) {
            #if DEBUG
            print("📂 Successfully read \(imageData.count) bytes")
            #endif
            image = NSImage(data: imageData)
        } else {
            #if DEBUG
            print("❌ Failed to read image data")
            #endif
        }

        // Fallback to direct load
        if image == nil {
            image = NSImage(contentsOf: imageURL)
        }

        guard let loadedImage = image else {
            let alert = NSAlert()
            alert.messageText = "Failed to Load Image"
            alert.informativeText = "Could not load the image at:\n\(imageURL.path)\n\nFile exists: \(FileManager.default.fileExists(atPath: imageURL.path))\nIs readable: \(FileManager.default.isReadableFile(atPath: imageURL.path))"
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            alert.runModal()

            // Clean up temp file on error
            cleanupTempFile(at: imageURL)
            return
        }

        #if DEBUG
        print("✅ Successfully loaded image: \(loadedImage.size)")
        #endif

        let editorView = TableEditorView(
            image: loadedImage,
            onComplete: { [weak self] result, format in
                self?.editorWindow?.close()
                self?.editorWindow = nil
                self?.handleExtractionResult(result, format: format == .csv ? "CSV" : "Markdown")

                // Clean up temp file after extraction
                self?.cleanupTempFile(at: imageURL)
            },
            onCancel: { [weak self] in
                self?.editorWindow?.close()
                self?.editorWindow = nil

                // Clean up temp file on cancel
                self?.cleanupTempFile(at: imageURL)
            }
        )
        
        let hostingController = NSHostingController(rootView: editorView)
        
        editorWindow = NSWindow(contentViewController: hostingController)
        editorWindow?.title = "Table Editor"
        editorWindow?.styleMask = [.titled, .closable, .resizable]
        editorWindow?.setContentSize(NSSize(width: 800, height: 600))
        editorWindow?.center()
        
        editorWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Result Handling

    func handleExtractionResult(_ result: Result<String, Error>, format: String) {
        switch result {
        case .success(let tableData):
            // Copy to clipboard
            copyToClipboard(tableData)

            // Show success alert
            let alert = NSAlert()
            alert.messageText = "\(format) Table Extracted!"
            alert.informativeText = "Table has been copied to your clipboard."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()

            #if DEBUG
            print("Successfully extracted table:\n\(tableData)")
            #endif

        case .failure(let error):
            // Show error alert
            let alert = NSAlert()
            alert.messageText = "Table Extraction Failed"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            alert.runModal()

            #if DEBUG
            print("Error extracting table: \(error)")
            #endif
        }
    }

    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    // MARK: - Cleanup

    private func cleanupTempFile(at url: URL) {
        // Only clean up files in the temporary directory
        let tempDir = FileManager.default.temporaryDirectory
        guard url.path.hasPrefix(tempDir.path) else {
            #if DEBUG
            print("🗑️ Skipping cleanup - not a temp file: \(url.path)")
            #endif
            return
        }

        #if DEBUG
        print("🗑️ Attempting to clean up: \(url.lastPathComponent)")
        print("🗑️ Full path: \(url.path)")
        print("🗑️ File exists: \(FileManager.default.fileExists(atPath: url.path))")
        #endif

        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
                #if DEBUG
                print("✅ Successfully deleted temp file: \(url.lastPathComponent)")
                #endif
            } else {
                #if DEBUG
                print("ℹ️ Temp file already deleted: \(url.lastPathComponent)")
                #endif
            }
        } catch {
            #if DEBUG
            print("❌ Failed to clean up temp file: \(error)")
            #endif
        }
    }
}
