//
//  AutoUpdateAppCheck.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/07/2021.
//

import Foundation
import os.log
import Regex
import Version

class AutoUpdateAppCheck: ParetoCheck {
    static let sharedInstance = AutoUpdateAppCheck()
    override var UUID: String {
        "940e7a88-2dd4-4a50-bf9c-3d842e0a2c94"
    }

    override var TitleON: String {
        "App Store updates are automatic"
    }

    override var TitleOFF: String {
        "App Store updates are not automatic"
    }

    override func checkPasses() -> Bool {
        let path = "/Library/Preferences/com.apple.commerce.plist"
        if let enabled = readDefaultsNative(path: path, key: "AutoUpdate") {
            os_log("AutoUpdate, status %{enabled}s", log: Log.check, enabled)
            return enabled == "1"
        }
        // can also be missing if it never changed, but defaults to true
        return true
    }
}
