//
//  AppStoreUpdatesCheck.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/07/2021.
//

import Foundation
import os.log
import Regex
import Version

class AutoUpdateCheck: ParetoCheck {
    static let sharedInstance = AutoUpdateCheck()
    override var UUID: String {
        "dba1dea4-8c96-4b33-95f4-63d68bd0387e"
    }
    
    override var TitleON: String {
        "macOS updates are auto-installed"
    }
    
    override var TitleOFF: String {
        "macOS updates are not auto-installed"
    }
    
    override func checkPasses() -> Bool {
        let path = "/Library/Preferences/com.apple.SoftwareUpdate"
        if let enabled = readDefaultsNative(path: path, key: "AutomaticallyInstallMacOSUpdates") {
            os_log("AutomaticallyInstallMacOSUpdates, status %{enabled}s", log: Log.check, enabled)
            return enabled == "1"
        }
        // can also be missing if it never changed, but defaults to true
        return true
    }
}
