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

class AutomaticDownloadCheck: ParetoCheck {
    static let sharedInstance = AutomaticDownloadCheck()
    override var UUID: String {
        "1fa68e99-e152-4ac1-8362-e6b7c54cc4b4"
    }

    override var TitleON: String {
        "Downloading new updates is enabled"
    }

    override var TitleOFF: String {
        "Downloading new updates is disabled"
    }

    override func checkPasses() -> Bool {
        let path = "/Library/Preferences/com.apple.SoftwareUpdate"
        if let enabled = readDefaultsNative(path: path, key: "AutomaticDownload") {
            os_log("AutomaticDownload, status %{enabled}s", log: Log.check, enabled)
            return enabled == "1"
        }
        return false
    }
}
