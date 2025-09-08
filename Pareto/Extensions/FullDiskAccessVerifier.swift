//
//  FullDiskAccessVerifier.swift
//  Pareto Security
//
//  Created by Claude on 2025-09-08.
//

import Foundation
import os.log

enum FullDiskAccessVerifier {
    static func hasFullDiskAccess() -> Bool {
        let tmPlistPath = "/Library/Preferences/com.apple.TimeMachine.plist"

        // Check if file exists
        guard FileManager.default.fileExists(atPath: tmPlistPath) else {
            os_log("FDA check: Time Machine plist does not exist")
            return false
        }

        // Try to read as NSDictionary
        if let dict = NSDictionary(contentsOfFile: tmPlistPath) {
            if dict.count > 0 {
                os_log("FDA check: Successfully read Time Machine plist with %d entries", dict.count)
                return true
            }
        }

        // Try using FileHandle
        if let handle = FileHandle(forReadingAtPath: tmPlistPath) {
            defer { handle.closeFile() }
            let data = handle.readData(ofLength: 10)
            if !data.isEmpty {
                os_log("FDA check: Read Time Machine plist via FileHandle")
                return true
            }
        }

        // Try to read raw data
        if let data = try? Data(contentsOf: URL(fileURLWithPath: tmPlistPath)) {
            if !data.isEmpty {
                os_log("FDA check: Successfully read Time Machine plist data (%d bytes)", data.count)
                return true
            }
        }

        os_log("FDA check: Cannot read Time Machine plist - No Full Disk Access")
        return false
    }
}
