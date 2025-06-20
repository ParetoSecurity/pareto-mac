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

    override public var isRunnable: Bool {
        if TimeMachineCheck.sharedInstance.isRunnable && isActive {
            let dict = readDefaultsFile(path: "/Library/Preferences/com.apple.TimeMachine.plist") as! [String: Any]?
            guard let settings = dict else {
                return false
            }
            let tmConf = TimeMachineConfig(dict: settings)
            return tmConf.canCheckIsEncryptedBackup
        }

        return false
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
            hasError = true
            return false
        }
        let tmConf = TimeMachineConfig(dict: settings)
        return tmConf.AutoBackup && tmConf.isEncryptedBackup
    }
}
