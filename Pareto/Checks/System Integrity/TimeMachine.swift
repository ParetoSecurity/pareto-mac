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

    var isConfigured: Bool {
        let status = runCMD(app: "/usr/bin/tmutil", args: ["destinationinfo"])
        return status.contains("ID") && status.contains("Name")
    }

    private var dict: NSDictionary? {
        readDefaultsFile(path: "/Library/Preferences/com.apple.TimeMachine.plist")
    }

    override func checkPasses() -> Bool {
        if dict == nil {
            os_log("/Library/Preferences/com.apple.TimeMachine.plist use fallabck")
            let status = runCMD(app: "/usr/bin/tmutil", args: ["status"])
            return isConfigured && !status.contains("Stopping = 1")
        }
        let tmConf = TimeMachineConfig(obj: dict!)
        return tmConf.AutoBackup && !tmConf.Destinations.isEmpty && !tmConf.LastDestinationID.isEmpty
    }
}
