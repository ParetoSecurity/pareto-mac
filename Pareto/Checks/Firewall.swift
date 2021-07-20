//
//  GateKeeper.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/07/2021.
//
import Foundation
import os.log

class FirewallCheck: ParetoCheck {
    final var ID = "2e46c89a-5461-4865-a92e-3b799c12034c"
    final var TITLE = "Firewall active"

    required init(defaults: UserDefaults = .standard, id _: String! = "", title _: String! = "") {
        super.init(defaults: defaults, id: ID, title: TITLE)
    }

    override func checkPasses() -> Bool {
        let dictionary = readDefaultsFile(path: "/Library/Preferences/com.apple.alf.plist")
        if let globalstate = dictionary?.value(forKey: "globalstate") as? Int {
            // os_log("globalstate: %{public}s", globalstate)
            return globalstate == 1
        }
        return false
    }
}
