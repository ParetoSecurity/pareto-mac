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

    /// Returns the output of `socketfilterfw --getglobalstate`, run as root by the privileged helper.
    let helperProvider: () async -> String
    private let helperAnswer: HelperAnswer

    init(
        helperProvider: @escaping () async -> String = FirewallCheck.fetchStateViaHelper,
        helperTimeout: TimeInterval = 10
    ) {
        self.helperProvider = helperProvider
        helperAnswer = HelperAnswer(timeout: helperTimeout)
    }

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

        if #available(macOS 15, *), requiresHelper, !HelperToolUtilities.isHelperInstalled() {
            let helperPath = "/Library/PrivilegedHelperTools/co.niteo.ParetoSecurityHelper"
            let helperExists = FileManager.default.fileExists(atPath: helperPath)

            if helperExists {
                return "Helper tool exists at \(helperPath) but is not properly authorized. Please approve in System Settings > General > Login Items > Allow in Background."
            } else {
                return "Helper tool not installed at \(helperPath). The app will attempt to install it when you authorize."
            }
        }

        return nil
    }

    /// Takes the output of `socketfilterfw --getglobalstate`. Returns nil when it does not state
    /// the firewall's state, e.g. an error from the helper.
    static func evaluate(helperOutput output: String) -> Bool? {
        if output.contains("State = 1") || output.contains("State = 2") {
            return true
        }
        return output.contains("State = ") ? false : nil
    }

    private func helperPasses() async -> Bool? {
        let output = await helperProvider()
        guard let passes = Self.evaluate(helperOutput: output) else {
            os_log("FirewallCheck: helper output could not be evaluated: %{public}@", log: Log.check, output)
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

        let out = runCMD(app: "/usr/libexec/ApplicationFirewall/socketfilterfw", args: ["--getglobalstate"])
        os_log("FirewallCheck: Command output: %{public}@", out)
        return Self.evaluate(helperOutput: out) ?? false
    }

    static func fetchStateViaHelper() async -> String {
        await withCheckedContinuation { continuation in
            Task { @MainActor in
                let helperManager = HelperToolManager()
                guard await helperManager.ensureHelperIsUpToDate() else {
                    continuation.resume(returning: "XPC: Helper tool is not installed")
                    return
                }
                await helperManager.isFirewallEnabled { output in
                    continuation.resume(returning: output)
                }
            }
        }
    }
}
