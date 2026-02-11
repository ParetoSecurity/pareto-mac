//
//  FirewallStealth.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/07/2021.
//

import Foundation
import os.log

class FirewallStealthCheck: ParetoCheck {
    static let sharedInstance = FirewallStealthCheck()
    private let helperResultLock = OSAllocatedUnfairLock<Bool?>(initialState: nil)
    private let helperCheckInFlight = OSAllocatedUnfairLock(initialState: false)
    override var UUID: String {
        "2e46c89a-5461-4865-a92e-3b799c12034b"
    }

    override var TitleON: String {
        "Firewall stealth mode is enabled"
    }

    override var TitleOFF: String {
        "Firewall stealth mode is disabled"
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
        if !FirewallCheck.sharedInstance.isActive || !isActive {
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

    override var showSettings: Bool {
        if teamEnforced {
            return false
        }
        return FirewallCheck.sharedInstance.isActive
    }

    override func checkPasses() -> Bool {
        if #available(macOS 26, *) {
            let out = runCMD(app: "/usr/libexec/ApplicationFirewall/socketfilterfw", args: ["--getstealthmode"])
            return out.contains("enabled") || out.contains("mode is on")
        }

        if #available(macOS 15, *) {
            refreshHelperResultIfNeeded()
            return helperResultLock.withLock { $0 } ?? checkPassed
        }

        let out = runCMD(app: "/usr/libexec/ApplicationFirewall/socketfilterfw", args: ["--getstealthmode"])
        return out.contains("enabled") || out.contains("mode is on")
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
            let enabled = await self.fetchStealthEnabledViaHelper()
            self.helperResultLock.withLock { $0 = enabled }
            self.helperCheckInFlight.withLock { $0 = false }
        }
    }

    private func fetchStealthEnabledViaHelper() async -> Bool {
        await withCheckedContinuation { continuation in
            Task { @MainActor in
                let helperManager = HelperToolManager()
                let helperReady = await helperManager.ensureHelperIsUpToDate()
                guard helperReady else {
                    continuation.resume(returning: false)
                    return
                }

                await helperManager.isFirewallStealthEnabled { output in
                    let enabled = output.contains("enabled") || output.contains("mode is on")
                    continuation.resume(returning: enabled)
                }
            }
        }
    }
}
