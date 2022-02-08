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

class SystemUpdatesCheck: ParetoCheck {
    static let sharedInstance = SystemUpdatesCheck()
    override var UUID: String {
        "b56b3b65-b296-489d-bbf2-defc9fee8abd"
    }

    override var TitleON: String {
        "Security updates are auto-installed"
    }

    override var TitleOFF: String {
        "Security updates are not auto-installed"
    }

    override func checkPasses() -> Bool {
        let path = "/Library/Preferences/com.apple.SoftwareUpdate"
        var allOK = false
        if let CriticalUpdateInstall = readDefaultsNative(path: path, key: "CriticalUpdateInstall") {
            os_log("CriticalUpdateInstall, status %{enabled}s", log: Log.check, CriticalUpdateInstall)
            allOK = (CriticalUpdateInstall == "1")
        }
        if let ConfigDataInstall = readDefaultsNative(path: path, key: "ConfigDataInstall") {
            os_log("ConfigDataInstall, status %{enabled}s", log: Log.check, ConfigDataInstall)
            allOK = (ConfigDataInstall == "1")
        }

        return allOK
    }
}
