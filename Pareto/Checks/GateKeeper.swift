//
//  Gatekeeper.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/07/2021.
//
import Foundation
import os.log

class GatekeeperCheck: ParetoCheck {
    override var UUID: String {
        "b59e172e-6a2d-4309-94ed-11e8722836b3"
    }

    override var TitleON: String {
        "Gatekeeper is on"
    }

    override var TitleOFF: String {
        "Gatekeeper is off"
    }

    func isSandboxingEnabled() -> Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }

    override func checkPasses() -> Bool {
        let path = "/var/db/SystemPolicy-prefs.plist"
        if isSandboxingEnabled() {
            os_log("Running in sandbox %{public}s - %{public}s", log: Log.check, UUID, Title)
            // if enabled one cannot read system file even with entitlement
            if NSDictionary(contentsOfFile: path) != nil {
                os_log("Gatekeeper file not found", log: Log.check)
                return true
            }
            return false
        }

        // If we are not sandboxed
        let dictionary = readDefaultsFile(path: path)
        if let enabled = dictionary?.object(forKey: "enabled") as? String {
            os_log("Gatekeeper file found, status %{enabled}s", log: Log.check, enabled)
            return enabled == "yes"
        }

        // falback if global file is not present (probably due to the upgrade)
        let output = runCMD(app: "/usr/sbin/spctl", args: ["--status"])
        os_log("spctl fallback, status %{enabled}s", log: Log.check, output)
        return output.contains("assessments enabled")
    }
}
