//
//  Screensaver.swift
//  Pareto Security
//
//  Created by Janez Troha on 19/07/2021.
//

import Foundation

class ScreensaverCheck: ParetoCheck {
    static let sharedInstance = ScreensaverCheck()
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
        return true
    }

    // Reads the per-user, current-host screensaver delay (seconds) natively
    func checkScreensaver() -> Bool {
        let domain = "com.apple.screensaver" as CFString
        let key = "idleTime" as CFString

        let value = CFPreferencesCopyValue(
            key,
            domain,
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        )

        let seconds: Int = {
            if let num = value as? NSNumber {
                return num.intValue
            } else if let str = value as? String, let intVal = Int(str) {
                return intVal
            } else {
                return 0
            }
        }()

        return seconds > 0 && seconds <= 60 * 20
    }

    // Native read of com.apple.screensaver loginWindowIdleTime (seconds) at loginwindow (AnyUser/CurrentHost)
    // See: macOS security guidance references for enforcing loginwindow screensaver timeout
    func checkLock() -> Bool {
        let domain = "com.apple.screensaver" as CFString
        let key = "loginWindowIdleTime" as CFString

        // Try AnyUser/CurrentHost which is where loginwindow settings typically live
        let value = CFPreferencesCopyValue(
            key,
            domain,
            kCFPreferencesAnyUser,
            kCFPreferencesCurrentHost
        )

        let seconds: Int = {
            if let num = value as? NSNumber {
                return num.intValue
            } else if let str = value as? String, let intVal = Int(str) {
                return intVal
            } else {
                return 0
            }
        }()

        return seconds >= 0 && seconds <= 60 * 20
    }

    override func checkPasses() -> Bool {
        return checkScreensaver() || checkLock()
    }
}
