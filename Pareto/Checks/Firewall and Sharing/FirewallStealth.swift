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

    override func checkPasses() -> Bool {
        let dictionary = readDefaultsFile(path: "/Library/Preferences/com.apple.alf.plist")
        if let globalstate = dictionary?.value(forKey: "globalstate") as? Int {
            // os_log("globalstate: %{public}s", log: Log.check, globalstate)
            return globalstate == 2
        }
        return false
    }
}
