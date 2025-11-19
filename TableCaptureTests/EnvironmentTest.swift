//
//  EnvironmentTest.swift
//  TableCaptureTests
//
//  Simple test to verify environment variables are passed to tests
//

import Testing
import Foundation

struct EnvironmentTest {
    @Test("Verify DEBUG_OUTPUT_DIR environment variable")
    func testEnvironmentVariable() {
        let debugDir = ProcessInfo.processInfo.environment["DEBUG_OUTPUT_DIR"]
        print("DEBUG_OUTPUT_DIR = \(debugDir ?? "NOT SET")")

        if let dir = debugDir {
            print("Environment variable IS SET to: \(dir)")
            // Try to create the directory
            do {
                try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
                print("Successfully created directory at: \(dir)")

                // Write a test file
                let testFile = (dir as NSString).appendingPathComponent("env_test.txt")
                try "Environment variable test".write(toFile: testFile, atomically: true, encoding: .utf8)
                print("Successfully wrote test file to: \(testFile)")
            } catch {
                print("Failed to create directory or file: \(error)")
            }
        } else {
            print("Environment variable NOT SET")
        }
    }
}
