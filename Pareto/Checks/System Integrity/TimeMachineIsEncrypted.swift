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

    private var dict: [String: Any]? {
        readDefaultsFile(path: "/Library/Preferences/com.apple.TimeMachine.plist") as! [String: Any]?
    }

    override public var isRunnable: Bool {
        return dict != nil && isActive
    }

    override public var showSettings: Bool {
        return dict != nil
    }

    override public var showSettingsWarnDiskAccess: Bool {
        return true && dict == nil
    }

    override func checkPasses() -> Bool {
        guard let settings = dict else {
            os_log("/Library/Preferences/com.apple.TimeMachine.plist is empty")
            return false
        }
        let tmConf = TimeMachineConfig(dict: settings)
        return tmConf.AutoBackup && tmConf.isEncryptedBackup
    }
}
