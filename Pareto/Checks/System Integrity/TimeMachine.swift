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

    override public var hasDebug: Bool {
        return true
    }

    override public func debugInfo() -> String {
        let tmutil = runCMD(app: "/usr/bin/tmutil", args: ["destinationinfo"])
        return "tmutil:\n\(tmutil)\nTimeMachine: \(dict as AnyObject)"
    }

    var isConfigured: Bool {
        let status = runCMD(app: "/usr/bin/tmutil", args: ["destinationinfo"])
        return status.contains("ID") && status.contains("Name")
    }

    private var dict: [String: Any]? {
        readDefaultsFile(path: "/Library/Preferences/com.apple.TimeMachine.plist") as! [String: Any]?
    }

    override func checkPasses() -> Bool {
        guard let settings = dict else {
            os_log("/Library/Preferences/com.apple.TimeMachine.plist use fallback")
            let status = runCMD(app: "/usr/bin/tmutil", args: ["status"])
            return isConfigured && !status.contains("Stopping = 1")
        }
        let tmConf = TimeMachineConfig(dict: settings)
        return tmConf.AutoBackup && !tmConf.Destinations.isEmpty && !tmConf.LastDestinationID.isEmpty
    }
}
