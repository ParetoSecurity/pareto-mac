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
    private let helperResultLock = OSAllocatedUnfairLock<Bool?>(initialState: nil)
    private let helperCheckInFlight = OSAllocatedUnfairLock(initialState: false)
    override var UUID: String {
        "2e46c89a-5461-4865-a92e-3b799c12034a"
    }

    override var TitleON: String {
        "Firewall is on"
    }

    override var TitleOFF: String {
        "Firewall is off"
    }

    override var requiresHelper: Bool {
        if #available(macOS 26, *) {
            return false
        }
        if #available(macOS 15, *) {
            return true
        }
        return false
    }

    override var isRunnable: Bool {
        if teamEnforced {
            return true
        }
        if !isActive {
            return false
        }

        if #available(macOS 26, *) {
            return true
        }

        if #available(macOS 15, *) {
            if requiresHelper {
                return HelperToolUtilities.isHelperInstalled()
            }
        }
        return true
    }

    override var prerequisiteFailureDetails: String? {
        if isRunnable {
            return nil
        }

        if #available(macOS 15, *) {
            if requiresHelper, !HelperToolUtilities.isHelperInstalled() {
                let helperPath = "/Library/PrivilegedHelperTools/co.niteo.ParetoSecurityHelper"
                let helperExists = FileManager.default.fileExists(atPath: helperPath)

                if helperExists {
                    return "Helper tool exists at \(helperPath) but is not properly authorized. Please approve in System Settings > General > Login Items > Allow in Background."
                } else {
                    return "Helper tool not installed at \(helperPath). The app will attempt to install it when you authorize."
                }
            }
        }

        return nil
    }

    override func checkPasses() -> Bool {
        if #available(macOS 26, *) {
            let out = runCMD(app: "/usr/libexec/ApplicationFirewall/socketfilterfw", args: ["--getglobalstate"])
            os_log("FirewallCheck: Command output: %{public}@", out)
            return out.contains("State = 1") || out.contains("State = 2")
        }

        if #available(macOS 15, *) {
            refreshHelperResultIfNeeded()
            return helperResultLock.withLock { $0 } ?? checkPassed
        }

        let out = runCMD(app: "/usr/libexec/ApplicationFirewall/socketfilterfw", args: ["--getglobalstate"])
        os_log("FirewallCheck: Command output: %{public}@", out)
        return out.contains("State = 1") || out.contains("State = 2")
    }

    private func refreshHelperResultIfNeeded() {
        let shouldStart = helperCheckInFlight.withLock { inFlight in
            if inFlight { return false }
            inFlight = true
            return true
        }
        guard shouldStart else { return }

        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            let enabled = await self.fetchFirewallEnabledViaHelper()
            self.helperResultLock.withLock { $0 = enabled }
            self.helperCheckInFlight.withLock { $0 = false }
        }
    }

    private func fetchFirewallEnabledViaHelper() async -> Bool {
        await withCheckedContinuation { continuation in
            Task { @MainActor in
                let helperManager = HelperToolManager()
                let helperReady = await helperManager.ensureHelperIsUpToDate()
                guard helperReady else {
                    continuation.resume(returning: false)
                    return
                }

                await helperManager.isFirewallEnabled { output in
                    let enabled = output.contains("State = 1") || output.contains("State = 2")
                    continuation.resume(returning: enabled)
                }
            }
        }
    }
}
