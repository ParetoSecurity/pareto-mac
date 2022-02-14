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

        // can also be missing if it never changed, but defaults to true
        var CriticalUpdateInstall = true
        var ConfigDataInstall = true

        if let CriticalUpdateInstallRaw = readDefaultsNative(path: path, key: "CriticalUpdateInstall") {
            os_log("CriticalUpdateInstall, status %{enabled}s", log: Log.check, CriticalUpdateInstall)
            CriticalUpdateInstall = (CriticalUpdateInstallRaw == "1")
        }
        if let ConfigDataInstallRaw = readDefaultsNative(path: path, key: "ConfigDataInstall") {
            os_log("ConfigDataInstall, status %{enabled}s", log: Log.check, ConfigDataInstall)
            ConfigDataInstall = (ConfigDataInstallRaw == "1")
        }

        return CriticalUpdateInstall && ConfigDataInstall
    }
}
