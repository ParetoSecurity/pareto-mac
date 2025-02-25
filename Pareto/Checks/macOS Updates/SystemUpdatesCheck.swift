//
//  SystemUpdatesCheck.swift
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
        "Security updates are automatic"
    }

    override var TitleOFF: String {
        "Security updates are not automatic"
    }

    override func checkPasses() -> Bool {
        let path = "/Library/Preferences/com.apple.SoftwareUpdate"

        // can also be missing if it never changed, but defaults to true
        var CriticalUpdateInstall = true
        var ConfigDataInstall = true

        if let CriticalUpdateInstallRaw = readDefaultsNative(path: path, key: "CriticalUpdateInstall") {
            CriticalUpdateInstall = (CriticalUpdateInstallRaw == "1")
        }
        if let ConfigDataInstallRaw = readDefaultsNative(path: path, key: "ConfigDataInstall") {
            ConfigDataInstall = (ConfigDataInstallRaw == "1")
        }

        return CriticalUpdateInstall && ConfigDataInstall
    }
}
