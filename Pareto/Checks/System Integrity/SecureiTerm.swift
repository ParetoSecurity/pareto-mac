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

class SecureiTermCheck: ParetoCheck {
    static let sharedInstance = SecureiTermCheck()
    override var UUID: String {
        "6cbe1cfd-ff28-4cc7-8998-5d72e608b28d"
    }

    override var TitleON: String {
        "iTerm uses secure entry"
    }

    override var TitleOFF: String {
        "iTerm is not using secure entry"
    }

    override var isRunnable: Bool {
        AppiTermCheck.sharedInstance.isInstalled
    }

    override func checkPasses() -> Bool {
        if let enabled = readDefaultsNative(path: "com.googlecode.iterm2", key: "\"Secure Input\"") {
            os_log("Secure Input, status %{enabled}s", log: Log.check, enabled)
            return enabled == "1"
        }
        // can also be missing if it never changed, but defaults to false
        return false
    }
}
