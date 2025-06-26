//
//  Autologin.swift
//  Pareto Security
//
//  Created by Janez Troha on 19/07/2021.
//

class AutologinCheck: ParetoCheck {
    static let sharedInstance = AutologinCheck()
    override var UUID: String {
        "f962c423-fdf5-428a-a57a-816abc9b253e"
    }

    override var TitleON: String {
        "Automatic login is off"
    }

    override var TitleOFF: String {
        "Automatic login is on"
    }

    public var showSettingsWarnEvents: Bool {
        return true
    }

    override func checkPasses() -> Bool {
        // possible:{require password to wake:false, class:security preferences object, secure virtual memory:false, require password to unlock:false, automatic login:false, log out when inactive:false, log out when inactive interval:60}
        let script = "tell application \"System Events\" to tell security preferences to get automatic login"
        let out = runOSA(appleScript: script) ?? "false"
        return out.contains("false")
    }
}
