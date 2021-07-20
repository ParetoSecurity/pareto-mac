//
//  GateKeeper.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/07/2021.
//
import Foundation
import os.log

class GatekeeperCheck: ParetoCheck {
    final var ID = "b59e172e-6a2d-4309-94ed-11e8722836b3"
    final var TITLE = "Gatekeeper active"

    required init(defaults: UserDefaults = .standard, id _: String! = "", title _: String! = "") {
        super.init(defaults: defaults, id: ID, title: TITLE)
    }

    override func checkPasses() -> Bool {
        let dictionary = readDefaultsFile(path: "/var/db/SystemPolicy-prefs.plist")
        if let enabled = dictionary?.object(forKey: "enabled") as? String {
            return enabled == "yes"
        }
        return false
    }
}
