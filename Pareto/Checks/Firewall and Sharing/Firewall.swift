//
//  Firewall.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/07/2021.
//

import Foundation
import os.log


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

    override func checkPasses() -> Bool {
        if #available(macOS 15, *) {
            let semaphore = DispatchSemaphore(value: 0)
            var enabled = false
            DispatchQueue.global(qos: .userInteractive).async {
                Task {
                    await HelperToolManager().isFirewallEnabled { out in
                        enabled = out.contains("State = 1") || out.contains("State = 2")
                        semaphore.signal()
                    }
                }
            }
            semaphore.wait()
            return enabled
        }
        
        let native = readDefaultsFile(path: "/Library/Preferences/com.apple.alf.plist")
        if let globalstate = native?.value(forKey: "globalstate") as? Int {
            return globalstate >= 1
        }
        return false
        
    }
}
