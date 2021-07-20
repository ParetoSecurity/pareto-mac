//
//  GateKeeper.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/07/2021.
//
import Foundation

class FirewallCheck: ParetoCheck {
    final var ID = "2e46c89a-5461-4865-a92e-3b799c12034c"
    final var TITLE = "Firewall active"

    required init(defaults: UserDefaults = .standard, id _: String! = "", title _: String! = "") {
        super.init(defaults: defaults, id: ID, title: TITLE)
    }

    override func checkPasses() -> Bool {
        let dictionary = self.readDefaultsFile(path: "/Library/Preferences/com.apple.alf.plist")
        if let enabled = dictionary?.object(forKey: "firewallunload") as? Int {
            return enabled == 0
        }
        return false
    }
}
