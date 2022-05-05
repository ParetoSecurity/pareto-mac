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

    private var dict: NSDictionary? {
        readDefaultsFile(path: "/Library/Preferences/com.apple.TimeMachine.plist")
    }

    override public var isRunnable: Bool {
        return dict != nil && isActive
    }

    override public var showSettings: Bool {
        return dict != nil
    }

    override public var showSettingsWarnDiskAccess: Bool {
        return true
    }

    override func checkPasses() -> Bool {
        if dict == nil {
            os_log("/Library/Preferences/com.apple.TimeMachine.plist is empty")
            return false
        }
        let tmConf = TimeMachineConfig(obj: dict!)
        return tmConf.AutoBackup && tmConf.upToDateBackup
    }
}
