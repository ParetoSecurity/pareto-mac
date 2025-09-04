//
//  SecurityUpdateCheck.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/07/2021.
//

import Foundation
import os.log
import Regex
import Version

class SecurityUpdateCheck: ParetoCheck {
    static let sharedInstance = SecurityUpdateCheck()
    override var UUID: String {
        "c491097c-6b8a-4cad-ae08-87c8bdfce100"
    }

    override var TitleON: String {
        "Security updates are enabled"
    }

    override var TitleOFF: String {
        "Security updates are disabled"
    }

    override func checkPasses() -> Bool {
        let path = "/Library/Preferences/com.apple.SoftwareUpdate"
        var enabled = true
        if let state = readDefaultsNative(path: path, key: "CriticalUpdateInstall") {
            os_log("AutomaticCheckEnabled, state %{enabled}s", log: Log.check, state)
            if !state.isEmpty {
                enabled = state == "1"
            }
        }
        if let state = readDefaultsNative(path: path, key: "AutomaticCheckEnabled") {
            os_log("AutomaticCheckEnabled, state %{enabled}s", log: Log.check, state)
            if !state.isEmpty {
                enabled = state == "1"
            }
        }
        // can also be missing if it never changed, but defaults to true
        return enabled
    }
}
