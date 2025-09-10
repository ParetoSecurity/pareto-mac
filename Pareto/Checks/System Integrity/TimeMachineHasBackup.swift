//
//  TimeMachine.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/07/2021.
//
import Foundation
import os.log

class TimeMachineHasBackupCheck: ParetoCheck {
    static let sharedInstance = TimeMachineHasBackupCheck()
    override var UUID: String {
        "455a56c1-1098-4b5d-ac8a-a1e8fc52dcfd"
    }

    override var TitleON: String {
        "Time Machine has up to date backup"
    }

    override var TitleOFF: String {
        "Time Machine is missing up to date backup"
    }

    override var isRunnable: Bool {
        // This check depends on Time Machine being configured and runnable
        // Even if team enforced, it can't run if Time Machine isn't set up

        // First check if Time Machine check is even enabled
        if !TimeMachineCheck.sharedInstance.isActive {
            return false
        }

        // Then check if Time Machine is configured
        if !TimeMachineCheck.sharedInstance.isRunnable {
            return false
        }

        // Finally check if this check itself is active
        return isActive
    }

    override var showSettings: Bool {
        return readDefaultsFile(path: "/Library/Preferences/com.apple.TimeMachine.plist") as! [String: Any]? != nil
    }

    override var showSettingsWarnDiskAccess: Bool {
        return true && readDefaultsFile(path: "/Library/Preferences/com.apple.TimeMachine.plist") as! [String: Any]? == nil
    }

    override var details: String {
        // If this check isn't runnable, return the reason why
        if !isRunnable {
            // Check if Time Machine check is disabled first
            if !TimeMachineCheck.sharedInstance.isActive {
                return "Depends on 'Time Machine is on' check being enabled"
            }

            // Check if Time Machine is configured
            if !TimeMachineCheck.sharedInstance.isRunnable {
                return "Time Machine is not configured - no backup destination set"
            }

            // Other reasons this check might not be runnable
            return disabledReason
        }

        // If we can read the Time Machine config, check backup status
        guard let settings = readDefaultsFile(path: "/Library/Preferences/com.apple.TimeMachine.plist") as! [String: Any]? else {
            return "Cannot read Time Machine configuration"
        }

        let tmConf = TimeMachineConfig(dict: settings)

        if !tmConf.AutoBackup {
            return "Automatic backups are disabled"
        }

        if tmConf.Destinations.isEmpty {
            return "No backup destinations configured"
        }

        if tmConf.upToDateBackup {
            return "Last backup was within the past 7 days"
        } else {
            // Find the most recent backup
            let mostRecent = tmConf.Destinations.map { $0.ReferenceLocalSnapshotDate }.max() ?? Date.distantPast
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            if mostRecent == Date.distantPast {
                return "No recent backup found"
            } else {
                return "Last backup: \(formatter.string(from: mostRecent))"
            }
        }
    }

    override func checkPasses() -> Bool {
        guard let settings = readDefaultsFile(path: "/Library/Preferences/com.apple.TimeMachine.plist") as! [String: Any]? else {
            os_log("/Library/Preferences/com.apple.TimeMachine.plist is empty")
            hasError = true
            return false
        }
        let tmConf = TimeMachineConfig(dict: settings)
        return tmConf.AutoBackup && tmConf.upToDateBackup
    }
    
    override var showInMenu: Bool {
        self.isActive && TimeMachineCheck.sharedInstance.isRunnableCached()
    }
}
