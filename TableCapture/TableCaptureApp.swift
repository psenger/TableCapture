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
    }
    
    @objc func menuButtonClicked() {
        statusItem?.menu = menu
    }
    
    @objc func capture() {
        print("Capture screen clicked!")

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
                    print("Screenshot saved to: \(tempURL.path)")
                    self.showTableEditor(imageURL: tempURL)
                } else {
                    print("User cancelled screenshot")
                }

                self.statusItem?.menu = self.menu
            }
        }

        do {
            try task.run()
        } catch {
            print("Error capturing screen: \(error)")
            statusItem?.menu = menu
        }
    }

    // MARK: - Table Editor

    func showTableEditor(imageURL: URL) {
        guard let image = NSImage(contentsOf: imageURL) else {
            let alert = NSAlert()
            alert.messageText = "Failed to Load Image"
            alert.informativeText = "Could not load the captured screenshot."
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        
        let editorView = TableEditorView(
            image: image,
            onComplete: { [weak self] result, format in
                self?.editorWindow?.close()
                self?.editorWindow = nil
                self?.handleExtractionResult(result, format: format == .csv ? "CSV" : "Markdown")
            },
            onCancel: { [weak self] in
                self?.editorWindow?.close()
                self?.editorWindow = nil
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

            print("Successfully extracted table:\n\(tableData)")

        case .failure(let error):
            // Show error alert
            let alert = NSAlert()
            alert.messageText = "Table Extraction Failed"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            alert.runModal()

            print("Error extracting table: \(error)")
        }
    }

    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
