//
//  AutomaticInstallCheck.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/07/2021.
//

import Foundation
import os.log
import Regex
import Version

class AutomaticInstallCheck: ParetoCheck {
    static let sharedInstance = AutomaticInstallCheck()
    override var UUID: String {
        "1fa68e99-e152-4ac1-8362-e6b7c54cc4b4"
    }

    override var TitleON: String {
        "Automatic install of new updates"
    }

    override var TitleOFF: String {
        "Automatic install of new updates is disabled"
    }

    override func checkPasses() -> Bool {
        let path = "/Library/Preferences/com.apple.SoftwareUpdate"
        if let enabled = readDefaultsNative(path: path, key: "AutomaticallyInstallMacOSUpdates") {
            os_log("AutomaticDownload, status %{enabled}s", log: Log.check, enabled)
            return enabled == "1"
        }
        return false
    }
}
