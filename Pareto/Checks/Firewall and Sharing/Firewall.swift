//
//  Firewall.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/07/2021.
//

class FirewallCheck: ParetoCheck {
    static let sharedInstance = FirewallCheck()
    override var UUID: String {
        "2e46c89a-5461-4865-a92e-3b799c12034a"
    }

    override var TitleON: String {
        "Firewall is on"
    }

    override var TitleOFF: String {
        "Firewall is off"
    }

    override public var isCritical: Bool {
        return true
    }

    override public var hasDebug: Bool {
        return true
    }

    override public func debugInfo() -> String {
        let systemextensionsctl = runCMD(app: "/usr/bin/systemextensionsctl", args: ["list", "com.apple.system_extension.network_extension"])
        return "systemextensionsctl:\n\(systemextensionsctl)"
    }

    func extensionActive(name: String) -> Bool {
        let list = runCMD(app: "/usr/bin/systemextensionsctl", args: ["list", "com.apple.system_extension.network_extension"])
        for app in list.split(separator: "\n") {
            if app.contains(name) {
                return app.contains("activated enabled")
            }
        }
        return false
    }

    var isLittleSnitchActive: Bool {
        extensionActive(name: "at.obdev.littlesnitch.networkextension")
    }

    var isLuluActive: Bool {
        extensionActive(name: "com.objective-see.lulu.extension")
    }

    override func checkPasses() -> Bool {
        if #available(macOS 15, *) {
            let out = runCMD(app: "/usr/libexec/ApplicationFirewall/socketfilterfw", args: ["--getglobalstate"])
            return out.contains("enabled")

        } else {
            let native = readDefaultsFile(path: "/Library/Preferences/com.apple.alf.plist")

            if let globalstate = native?.value(forKey: "globalstate") as? Int {
                return globalstate >= 1
            }

            return false
        }
    }
    
    
    
}
