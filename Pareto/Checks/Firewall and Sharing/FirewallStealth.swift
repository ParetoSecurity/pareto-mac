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

    /// Returns the output of `socketfilterfw --getstealthmode`, run as root by the privileged helper.
    let helperProvider: () async -> String
    private let helperAnswer: HelperAnswer

    init(
        helperProvider: @escaping () async -> String = FirewallStealthCheck.fetchStealthModeViaHelper,
        helperTimeout: TimeInterval = 10
    ) {
        self.helperProvider = helperProvider
        helperAnswer = HelperAnswer(timeout: helperTimeout)
    }

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

    /// Takes the output of `socketfilterfw --getstealthmode`. Returns nil when it does not state
    /// the stealth mode, e.g. an error from the helper.
    static func evaluate(helperOutput output: String) -> Bool? {
        if output.contains("enabled") || output.contains("mode is on") {
            return true
        }
        return output.contains("disabled") || output.contains("mode is off") ? false : nil
    }

    private func helperPasses() async -> Bool? {
        let output = await helperProvider()
        guard let passes = Self.evaluate(helperOutput: output) else {
            os_log("FirewallStealthCheck: helper output could not be evaluated: %{public}@", log: Log.check, output)
            return nil
        }
        return passes
    }

    /// Asks the helper before a report runs, so the report does not print the stored result.
    override func prefetch(completion: @escaping () -> Void) {
        guard requiresHelper, isRunnable else {
            completion()
            return
        }
        helperAnswer.prefetch(for: self, fetch: helperPasses, completion: completion)
    }

    override func checkPasses() -> Bool {
        // The helper is only needed on macOS 15 to 25
        if requiresHelper {
            return helperAnswer.passes(for: self, fetch: helperPasses)
        }

        let out = runCMD(app: "/usr/libexec/ApplicationFirewall/socketfilterfw", args: ["--getstealthmode"])
        os_log("FirewallStealthCheck: Command output: %{public}@", out)
        return Self.evaluate(helperOutput: out) ?? false
    }

    static func fetchStealthModeViaHelper() async -> String {
        await withCheckedContinuation { continuation in
            Task { @MainActor in
                let helperManager = HelperToolManager()
                guard await helperManager.ensureHelperIsUpToDate() else {
                    continuation.resume(returning: "XPC: Helper tool is not installed")
                    return
                }
                await helperManager.isFirewallStealthEnabled { output in
                    continuation.resume(returning: output)
                }
            }
        }
    }
}
