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

    override func checkPasses() -> Bool {
        let dict = readDefaultsFile(path: "/Library/Preferences/com.apple.TimeMachine.plist")
        if dict == nil {
            os_log("/Library/Preferences/com.apple.TimeMachine.plist is empty")
            return false
        }
        let tmConf = TimeMachineConfig(obj: dict!)
        return tmConf.AutoBackup && tmConf.isEncryptedBackup
    }
}
