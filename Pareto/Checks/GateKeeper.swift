//
//  GateKeeper.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/07/2021.
//
import Foundation

class GatekeeperCheck: ParetoCheck {
    final var ID = "b59e172e-6a2d-4309-94ed-11e8722836b3"
    final var TITLE = "Gatekeeper active"

    required init(defaults: UserDefaults = .standard, id _: String! = "", title _: String! = "") {
        super.init(defaults: defaults, id: ID, title: TITLE)
    }

    override func checkPasses() -> Bool {
        let path = "/var/db/SystemPolicy-prefs.plist"
        guard let dictionary = NSDictionary(contentsOfFile: path) else {
            return false
        }
        if let enabled = dictionary.object(forKey: "enabled") as? String {
            return enabled == "yes"
        }
        return false
    }
}
