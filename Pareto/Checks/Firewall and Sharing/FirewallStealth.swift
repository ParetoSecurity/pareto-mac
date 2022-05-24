//
//  FirewallStealth.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/07/2021.
//

class FirewallStealthCheck: ParetoCheck {
    static let sharedInstance = FirewallStealthCheck()
    override var UUID: String {
        "2e46c89a-5461-4865-a92e-3b799c12034b"
    }

    override var TitleON: String {
        "Firewall stealth mode is enabled"
    }

    override var TitleOFF: String {
        "Firewall stealth mode is disabled"
    }

    override public var isRunnable: Bool {
        return FirewallCheck.sharedInstance.isActive && isActive
    }

    override public var showSettings: Bool {
        if teamEnforced {
            return false
        }
        return FirewallCheck.sharedInstance.isActive
    }

    override func checkPasses() -> Bool {
        let dictionary = readDefaultsFile(path: "/Library/Preferences/com.apple.alf.plist")
        if let stealthenabled = dictionary?.value(forKey: "stealthenabled") as? Int {
            // os_log("globalstate: %{public}s", log: Log.check, globalstate)
            return stealthenabled >= 1
        }
        return false
    }
}
