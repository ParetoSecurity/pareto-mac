//
//  Firewall.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/07/2021.
//
import Foundation
import os.log

class FirewallCheck: ParetoCheck {
    override var UUID: String {
        "2e46c89a-5461-4865-a92e-3b799c12034a"
    }

    override var Title: String {
        "Firewall is on and configured"
    }

    override func checkPasses() -> Bool {
        let dictionary = readDefaultsFile(path: "/Library/Preferences/com.apple.alf.plist")
        if let globalstate = dictionary?.value(forKey: "globalstate") as? Int {
            // os_log("globalstate: %{public}s", log: Log.check, globalstate)
            return globalstate == 1
        }
        return false
    }
}
