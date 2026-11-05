//
//  Screensaver.swift
//  Pareto Security
//
//  Created by Janez Troha on 19/07/2021.
//

import Foundation
import os.log

class ScreensaverCheck: ParetoCheck {
    static let sharedInstance = ScreensaverCheck()

    let idleTimeProvider: () -> Any?
    let powerPreferencesProvider: () -> [String: Any]?

    init(
        idleTimeProvider: @escaping () -> Any? = {
            CFPreferencesCopyAppValue("idleTime" as CFString, "com.apple.screensaver" as CFString)
        },
        powerPreferencesProvider: @escaping () -> [String: Any]? = ScreensaverCheck.copyPowerPreferences
    ) {
        self.idleTimeProvider = idleTimeProvider
        self.powerPreferencesProvider = powerPreferencesProvider
    }

    override var UUID: String {
        "13e4dbf1-f87f-4bd9-8a82-f62044f002f4"
    }

    override var TitleON: String {
        "Screensaver or screen lock shows in under 20min"
    }

    override var TitleOFF: String {
        "Screensaver or screen lock shows in more than 20min"
    }

    override var showSettingsWarnEvents: Bool {
        true
    }

    /// Reads the screensaver delay (seconds), including values forced by a configuration profile
    func checkScreensaver() -> Bool {
        let value = idleTimeProvider()

        let seconds: Int = if let num = value as? NSNumber {
            num.intValue
        } else if let str = value as? String, let intVal = Int(str) {
            intVal
        } else {
            0
        }

        return seconds > 0 && seconds <= 60 * 20
    }

    /// Display sleep timers (minutes, 0 = never) from System Settings > Lock Screen.
    /// UPS Power only appears with a UPS attached and is ignored.
    static func displaySleepPasses(_ prefs: [String: Any]?) -> Bool {
        guard let prefs else { return false }

        let profiles = ["AC Power", "Battery Power"].compactMap { prefs[$0] as? [String: Any] }
        guard !profiles.isEmpty else { return false }

        return profiles.allSatisfy { profile in
            guard let minutes = (profile["Display Sleep Timer"] as? NSNumber)?.intValue else { return false }
            return minutes > 0 && minutes <= 20
        }
    }

    /// Reads the power profiles through `pmset -g custom`, which needs no privileges and only uses public tools.
    static func copyPowerPreferences() -> [String: Any]? {
        parsePmsetCustom(runCMD(app: "/usr/bin/pmset", args: ["-g", "custom"]))
    }

    /// Turns `pmset -g custom` output into `["AC Power": ["Display Sleep Timer": 10], ...]`.
    /// Profile headers end with a colon ("AC Power:"), settings are indented "key value" lines.
    static func parsePmsetCustom(_ output: String) -> [String: Any]? {
        var prefs: [String: Any] = [:]
        var profile: String?

        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                continue
            }
            if trimmed.hasSuffix(":"), !line.hasPrefix(" ") {
                let name = String(trimmed.dropLast())
                profile = name
                prefs[name] = [String: Any]()
                continue
            }
            let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            guard let profile, parts.count >= 2, parts[0] == "displaysleep", let minutes = Int(parts[1]) else {
                continue
            }
            var settings = prefs[profile] as? [String: Any] ?? [:]
            settings["Display Sleep Timer"] = NSNumber(value: minutes)
            prefs[profile] = settings
        }

        return prefs.isEmpty ? nil : prefs
    }

    override func checkPasses() -> Bool {
        if checkScreensaver() {
            return true
        }
        guard let prefs = powerPreferencesProvider() else {
            os_log("pmset returned no power settings", log: Log.check)
            hasError = true
            return false
        }
        return Self.displaySleepPasses(prefs)
    }
}
