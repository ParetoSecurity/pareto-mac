//
//  FirewallStealth.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/07/2021.
//

import Foundation

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

    override public var requiresHelper: Bool {
        if #available(macOS 15, *) {
            return true
        }
        return false
    }

    override public var isRunnable: Bool {
        if !FirewallCheck.sharedInstance.isActive || !isActive {
            return false
        }
        if #available(macOS 15, *) {
            if requiresHelper {
                return HelperToolUtilities.isHelperInstalled()
            }
        }
        return true
    }

    override public var showSettings: Bool {
        if teamEnforced {
            return false
        }
        return FirewallCheck.sharedInstance.isActive
    }

    override func checkPasses() -> Bool {
        if #available(macOS 15, *) {
            let semaphore = DispatchSemaphore(value: 0)
            var enabled = false

            DispatchQueue.global(qos: .userInteractive).async {
                Task {
                    let helperManager = HelperToolManager()
                    // Ensure helper is up to date before running check
                    let helperReady = await helperManager.ensureHelperIsUpToDate()
                    if helperReady {
                        await helperManager.isFirewallStealthEnabled { out in
                            enabled = out.contains("enabled") || out.contains("mode is on")
                            semaphore.signal()
                        }
                    } else {
                        // Helper failed to install/update, signal failure
                        semaphore.signal()
                    }
                }
            }

            semaphore.wait()
            return enabled
        }
        let out = runCMD(app: "/usr/libexec/ApplicationFirewall/socketfilterfw", args: ["--getstealthmode"])
        return out.contains("enabled") || out.contains("mode is on")
    }
}
