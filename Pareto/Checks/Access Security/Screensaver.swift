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

    static func copyPowerPreferences() -> [String: Any]? {
        let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY)
        guard let symbol = dlsym(handle, "IOPMCopyPMPreferences") else { return nil }
        typealias CopyFunction = @convention(c) () -> Unmanaged<CFDictionary>?
        let IOPMCopyPMPreferences = unsafeBitCast(symbol, to: CopyFunction.self)
        return IOPMCopyPMPreferences()?.takeRetainedValue() as? [String: Any]
    }

    override func checkPasses() -> Bool {
        if checkScreensaver() {
            return true
        }
        guard let prefs = powerPreferencesProvider() else {
            os_log("IOPMCopyPMPreferences returned no power settings", log: Log.check)
            hasError = true
            return false
        }
        return Self.displaySleepPasses(prefs)
    }
}
