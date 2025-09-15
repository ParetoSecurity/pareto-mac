//
//  TimeMachine.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/07/2021.
//
import Foundation
import os.log

class TimeMachineCheck: ParetoCheck {
    static let sharedInstance = TimeMachineCheck()
    override var UUID: String {
        "355a56c1-1098-4b5d-ac8a-a1e8fc52dcfd"
    }

    override var TitleON: String {
        "Time Machine is on"
    }

    override var TitleOFF: String {
        "Time Machine is off"
    }

    override var hasDebug: Bool {
        return true
    }

    override func debugInfo() -> String {
        let tmutil = runCMD(app: "/usr/bin/tmutil", args: ["destinationinfo"])
        return "tmutil:\n\(tmutil)\nTimeMachine: \(readDefaultsFile(path: "/Library/Preferences/com.apple.TimeMachine.plist") as AnyObject)"
    }

    override var isRunnable: Bool {
        // Otherwise require proper configuration and enabled state
        guard let config = readDefaultsFile(path: "/Library/Preferences/com.apple.TimeMachine.plist") else {
            return false
        }
        if config.count <= 1 { return false }
        if let autoBackup = config["AutoBackup"] as? Int, autoBackup == 0 { return false }
        return isActive
    }

    override var showSettingsWarnDiskAccess: Bool {
        // If we cannot read the TM plist, likely missing Full Disk Access
        return readDefaultsFile(path: "/Library/Preferences/com.apple.TimeMachine.plist") == nil
    }

    var isConfigured: Bool {
        let status = runCMD(app: "/usr/bin/tmutil", args: ["destinationinfo"])
        return status.contains("ID") && status.contains("Name")
    }

    override var details: String {
        // If not runnable due to configuration, return the reason
        if !isRunnable {
            return disabledReason
        }

        guard let settings = readDefaultsFile(path: "/Library/Preferences/com.apple.TimeMachine.plist") else {
            // Fallback to tmutil if plist not readable
            if isConfigured {
                return "Time Machine is configured (via tmutil)"
            } else {
                return "Time Machine is not configured - no backup destination set"
            }
        }

        let tmConf = TimeMachineConfig(dict: settings)

        if tmConf.Destinations.isEmpty {
            return "No backup destinations configured"
        }

        if !tmConf.AutoBackup {
            return "Automatic backups are disabled"
        }

        if tmConf.LastDestinationID.isEmpty {
            return "Time Machine configured but no backups have been made yet"
        }

        return "Time Machine is enabled with \(tmConf.Destinations.count) destination(s)"
    }

    override func checkPasses() -> Bool {
        guard let settings = readDefaultsFile(path: "/Library/Preferences/com.apple.TimeMachine.plist") else {
            os_log("/Library/Preferences/com.apple.TimeMachine.plist use fallback")
            let status = runCMD(app: "/usr/bin/tmutil", args: ["status"])
            return isConfigured && !status.contains("Stopping = 1")
        }
        let tmConf = TimeMachineConfig(dict: settings)
        return tmConf.AutoBackup && !tmConf.Destinations.isEmpty && !tmConf.LastDestinationID.isEmpty
    }
}
