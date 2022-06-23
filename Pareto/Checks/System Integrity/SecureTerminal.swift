//
//  SecureTerminal.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/07/2021.
//

import Foundation
import os.log
import Regex
import Version

class SecureTerminalCheck: ParetoCheck {
    static let sharedInstance = SecureTerminalCheck()
    override var UUID: String {
        "5cbe1cfd-ff28-4cc7-8998-5d72e608b28d"
    }

    override var TitleON: String {
        "Terminal uses secure entry"
    }

    override var TitleOFF: String {
        "Terminal is not using secure entry"
    }

    override func checkPasses() -> Bool {
        if let enabled = readDefaultsNative(path: "com.apple.Terminal", key: "SecureKeyboardEntry") {
            os_log("SecureKeyboardEntry, status %{enabled}s", log: Log.check, enabled)
            return enabled.contains("1")
        }
        return false
    }
}
