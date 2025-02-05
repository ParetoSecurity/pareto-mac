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

    override public var isRunnable: Bool {
        return TimeMachineCheck.sharedInstance.isRunnable && isActive
    }

    override public var showSettings: Bool {
        return readDefaultsFile(path: "/Library/Preferences/com.apple.TimeMachine.plist") as! [String: Any]? != nil
    }

    override public var showSettingsWarnDiskAccess: Bool {
        return true && readDefaultsFile(path: "/Library/Preferences/com.apple.TimeMachine.plist") as! [String: Any]? == nil
    }

    override func checkPasses() -> Bool {
        guard let settings = readDefaultsFile(path: "/Library/Preferences/com.apple.TimeMachine.plist") as! [String: Any]? else {
            os_log("/Library/Preferences/com.apple.TimeMachine.plist is empty")
            return false
        }
        let tmConf = TimeMachineConfig(dict: settings)
        return tmConf.AutoBackup && tmConf.upToDateBackup
    }
}
