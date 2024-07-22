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

    override public var hasDebug: Bool {
        return true
    }

    override public func debugInfo() -> String {
        let dictionary = readDefaultsFile(path: "/Library/Preferences/com.apple.alf.plist")
        let out = runCMD(app: "/usr/libexec/ApplicationFirewall/socketfilterfw", args: ["--getstealthmode"])
        return "com.apple.alf.plist:\n\(dictionary.debugDescription)\nsocketfilterfw:\n\(out)"
    }

    override public var showSettings: Bool {
        if teamEnforced {
            return false
        }
        return FirewallCheck.sharedInstance.isActive
    }

    override func checkPasses() -> Bool {
        let out = runCMD(app: "/usr/libexec/ApplicationFirewall/socketfilterfw", args: ["--getstealthmode"])
        return out.contains("enabled") || out.contains("mode is on")
    }
}
