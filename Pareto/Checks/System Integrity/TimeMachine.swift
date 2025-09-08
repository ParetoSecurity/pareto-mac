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
        return "tmutil:\n\(tmutil)\nTimeMachine: \(readDefaultsFile(path: "/Library/Preferences/com.apple.TimeMachine.plist") as! [String: Any]? as AnyObject)"
    }

    override var isRunnable: Bool {
        // Even if team enforced, we need Time Machine to be configured
        guard let config = readDefaultsFile(path: "/Library/Preferences/com.apple.TimeMachine.plist") as! [String: Any]? else {
            return false
        }
        // Check if there's actual configuration (not just an empty or minimal plist)
        if config.count <= 1 {
            return false
        }
        // If team enforced, it's runnable regardless of isActive
        if teamEnforced {
            return true
        }
        // Otherwise, it needs to be active
        return isActive
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
        
        guard let settings = readDefaultsFile(path: "/Library/Preferences/com.apple.TimeMachine.plist") as! [String: Any]? else {
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
        guard let settings = readDefaultsFile(path: "/Library/Preferences/com.apple.TimeMachine.plist") as! [String: Any]? else {
            os_log("/Library/Preferences/com.apple.TimeMachine.plist use fallback")
            let status = runCMD(app: "/usr/bin/tmutil", args: ["status"])
            return isConfigured && !status.contains("Stopping = 1")
        }
        let tmConf = TimeMachineConfig(dict: settings)
        return tmConf.AutoBackup && !tmConf.Destinations.isEmpty && !tmConf.LastDestinationID.isEmpty
    }
}
