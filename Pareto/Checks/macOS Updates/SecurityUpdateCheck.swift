//
//  AutoUpdateCheck.swift
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
        if let enabled = readDefaultsNative(path: path, key: "AutomaticCheckEnabled") {
            os_log("AutomaticCheckEnabled, status %{enabled}s", log: Log.check, enabled)
            return enabled == "1"
        }
        return false
    }
}
