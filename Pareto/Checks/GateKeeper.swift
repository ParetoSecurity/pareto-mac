//
//  Gatekeeper.swift
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
    func isSandboxingEnabled() -> Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }
    override func checkPasses() -> Bool {
        let path = "/var/db/SystemPolicy-prefs.plist"
        if (isSandboxingEnabled()){
            // if enabled one cannot read system file even with entitlement
            guard let _ = NSDictionary(contentsOfFile: path) else {
                return true
            }
            return false
        }
        
        // If we are not sandboxed
        let dictionary = readDefaultsFile(path: path)
        if let enabled = dictionary?.object(forKey: "enabled") as? String {
            return enabled == "yes"
        }
        return false
    }
}
