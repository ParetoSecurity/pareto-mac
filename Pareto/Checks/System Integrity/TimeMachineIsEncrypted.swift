//
//  TimeMachine.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/07/2021.
//
import Foundation
import os.log

class TimeMachineIsEncryptedCheck: ParetoCheck {
    static let sharedInstance = TimeMachineIsEncryptedCheck()
    override var UUID: String {
        "555a56c1-1098-4b5d-ac8a-a1e8fc52dcfd"
    }

    override var TitleON: String {
        "Time Machine backup is encrypted"
    }

    override var TitleOFF: String {
        "Time Machine backup is not encrypted"
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
        return readDefaultsFile(path: "/Library/Preferences/com.apple.TimeMachine.plist") != nil
    }

    override var showSettingsWarnDiskAccess: Bool {
        return true && readDefaultsFile(path: "/Library/Preferences/com.apple.TimeMachine.plist") == nil
    }

    override var details: String {
        // Check if Time Machine check is disabled first
        if !TimeMachineCheck.sharedInstance.isActive {
            return "Depends on 'Time Machine is on' check being enabled"
        }

        // Check if Time Machine is configured
        if !TimeMachineCheck.sharedInstance.isRunnable {
            return "Time Machine is not configured - no backup destination set"
        }

        // If this check itself isn't runnable for other reasons
        if !isRunnable {
            return disabledReason
        }

        // If we can read the Time Machine config, check encryption status
        guard let settings = readDefaultsFile(path: "/Library/Preferences/com.apple.TimeMachine.plist") else {
            return "Cannot read Time Machine configuration"
        }

        let tmConf = TimeMachineConfig(dict: settings)

        if !tmConf.AutoBackup {
            return "Automatic backups are disabled"
        }

        if tmConf.Destinations.isEmpty {
            return "No backup destinations configured"
        }

        if !tmConf.canCheckIsEncryptedBackup {
            return "Cannot verify encryption for network backup destinations"
        }

        if tmConf.isEncryptedBackup {
            return "All backup destinations are encrypted"
        } else {
            let unencrypted = tmConf.Destinations.filter { !$0.isEncrypted }.count
            return "\(unencrypted) unencrypted backup destination(s) found"
        }
    }

    override func checkPasses() -> Bool {
        guard let settings = readDefaultsFile(path: "/Library/Preferences/com.apple.TimeMachine.plist") else {
            os_log("/Library/Preferences/com.apple.TimeMachine.plist is empty")
            hasError = true
            return false
        }
        let tmConf = TimeMachineConfig(dict: settings)
        return tmConf.AutoBackup && tmConf.isEncryptedBackup
    }

    override var showInMenu: Bool {
        isActive && TimeMachineCheck.sharedInstance.isRunnable
    }
}
