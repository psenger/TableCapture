//
//  HelpView.swift
//  TableCapture
//
//  Created by Philip A Senger on 10/11/2025.
//

import SwiftUI

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Image(systemName: "tablecells")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                    VStack(alignment: .leading) {
                        Text("TableCapture")
                            .font(.largeTitle)
                            .bold()
                        Text("Convert screen grids to CSV or Markdown")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom)
                
                Divider()
                
                // Getting Started
                VStack(alignment: .leading, spacing: 10) {
                    Text("🚀 Getting Started")
                        .font(.title2)
                        .bold()
                    
                    Text("TableCapture lives in your menu bar (top right of your screen). Click the table icon to access the menu.")
                }
                
                Divider()
                
                // Required Permissions
                VStack(alignment: .leading, spacing: 10) {
                    Text("🔐 Required Permissions")
                        .font(.title2)
                        .bold()
                    
                    Text("TableCapture needs Screen Recording permission to capture your screen.")
                        .foregroundColor(.red)
                        .bold()
                    
                    Text("To grant permission:")
                        .padding(.top, 5)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            Text("1.")
                                .bold()
                            Text("Open **System Settings** (or System Preferences)")
                        }
                        HStack(alignment: .top) {
                            Text("2.")
                                .bold()
                            Text("Go to **Privacy & Security** → **Screen Recording**")
                        }
                        HStack(alignment: .top) {
                            Text("3.")
                                .bold()
                            Text("Find **TableCapture** in the list and enable it")
                        }
                        HStack(alignment: .top) {
                            Text("4.")
                                .bold()
                            Text("If TableCapture is not in the list, click the **+** button and add it")
                        }
                        HStack(alignment: .top) {
                            Text("5.")
                                .bold()
                            Text("**Quit and restart** TableCapture completely")
                        }
                    }
                    .padding(.leading)
                    
                    Button("Open System Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 5)
                }
                
                Divider()
                
                // How to Use
                VStack(alignment: .leading, spacing: 10) {
                    Text("📸 How to Use")
                        .font(.title2)
                        .bold()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            Text("1.")
                                .bold()
                            Text("Click the **table icon** in your menu bar")
                        }
                        HStack(alignment: .top) {
                            Text("2.")
                                .bold()
                            Text("Select **Capture Screen** (or press ⌘C)")
                        }
                        HStack(alignment: .top) {
                            Text("3.")
                                .bold()
                            Text("Your cursor will change to **crosshairs** ➕")
                        }
                        HStack(alignment: .top) {
                            Text("4.")
                                .bold()
                            Text("**Click and drag** to select the grid/table area")
                        }
                        HStack(alignment: .top) {
                            Text("5.")
                                .bold()
                            Text("Release to capture")
                        }
                        HStack(alignment: .top) {
                            Text("6.")
                                .bold()
                            Text("TableCapture will convert it to CSV or Markdown")
                        }
                    }
                    .padding(.leading)
                    
                    Text("**Tip:** Press **ESC** to cancel the capture")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .padding(.top, 5)
                }
                
                Divider()
                
                // Supported Formats
                VStack(alignment: .leading, spacing: 10) {
                    Text("📄 Supported Formats")
                        .font(.title2)
                        .bold()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "doc.text")
                            Text("**CSV** - Comma-separated values for Excel, Google Sheets, etc.")
                        }
                        HStack {
                            Image(systemName: "text.alignleft")
                            Text("**Markdown Table** - For documentation, GitHub, Notion, etc.")
                        }
                    }
                }
                
                Divider()
                
                // Troubleshooting
                VStack(alignment: .leading, spacing: 10) {
                    Text("🔧 Troubleshooting")
                        .font(.title2)
                        .bold()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("**\"could not create image from rect\" error:**")
                                .bold()
                            Text("• Screen Recording permission is not granted")
                            Text("• Follow the steps in \"Required Permissions\" above")
                            Text("• Make sure to restart the app after granting permission")
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("**Crosshairs don't appear:**")
                                .bold()
                            Text("• Check Screen Recording permission")
                            Text("• Restart your Mac if permission was just granted")
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("**Table not detected correctly:**")
                                .bold()
                            Text("• Make sure the grid has clear lines and text")
                            Text("• Try capturing a smaller area")
                            Text("• Ensure good contrast between text and background")
                        }
                    }
                }
                
                Divider()
                
                // Footer
                Text("Version 1.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(30)
        }
        .frame(width: 600, height: 700)
    }
}

#Preview {
    HelpView()
}
