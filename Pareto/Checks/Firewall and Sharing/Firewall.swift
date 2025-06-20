//
//  Firewall.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/07/2021.
//

import Foundation
import os.log

// Reference type to avoid Swift 6 concurrency mutation warnings
private class Box<T> {
    var value: T
    init(_ value: T) {
        self.value = value
    }
}

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

    override public var requiresHelper: Bool {
        if #available(macOS 15, *) {
            return true
        }
        return false
    }

    override public var isRunnable: Bool {
        if !isActive {
            return false
        }
        if #available(macOS 15, *) {
            if requiresHelper {
                return HelperToolUtilities.isHelperInstalled()
            }
        }
        return true
    }

    override func checkPasses() -> Bool {
        os_log("FirewallCheck: checkPasses called")

        if #available(macOS 15, *) {
            os_log("FirewallCheck: Running macOS 15+ check with helper")
            let semaphore = DispatchSemaphore(value: 0)
            let result = Box(false) // Use a reference type to avoid mutation warnings

            DispatchQueue.global(qos: .userInteractive).async {
                Task { @MainActor in
                    os_log("FirewallCheck: Task started, creating helper manager")
                    let helperManager = HelperToolManager()

                    os_log("FirewallCheck: Ensuring helper is up to date")
                    // Ensure helper is up to date before running check
                    let helperReady = await helperManager.ensureHelperIsUpToDate()
                    os_log("FirewallCheck: Helper ready status: %{public}s", helperReady ? "true" : "false")

                    if helperReady {
                        os_log("FirewallCheck: Calling isFirewallEnabled")
                        await helperManager.isFirewallEnabled { output in
                            os_log("FirewallCheck: Received firewall output: %{public}s", output)
                            result.value = output.contains("State = 1") || output.contains("State = 2")
                            os_log("FirewallCheck: Firewall enabled result: %{public}s", result.value ? "true" : "false")
                            semaphore.signal()
                        }
                    } else {
                        os_log("FirewallCheck: Helper failed to install/update, signaling failure")
                        // Helper failed to install/update, signal failure
                        semaphore.signal()
                    }
                }
            }

            os_log("FirewallCheck: Waiting for result with 10 second timeout")
            // Wait with timeout to prevent blocking forever
            let timeoutResult = semaphore.wait(timeout: .now() + 10.0)
            if timeoutResult == .timedOut {
                os_log("FirewallCheck: Timed out waiting for result", log: Log.app)
                return false
            }

            os_log("FirewallCheck: Check completed with result: %{public}s", result.value ? "true" : "false")
            return result.value
        }

        let native = readDefaultsFile(path: "/Library/Preferences/com.apple.alf.plist")
        if let globalstate = native?.value(forKey: "globalstate") as? Int {
            return globalstate >= 1
        }
        return false
    }
}
