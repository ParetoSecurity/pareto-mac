//
//  Screensaver.swift
//  Pareto Security
//
//  Created by Janez Troha on 19/07/2021.
//

import Foundation
import os.log

class ScreensaverPasswordCheck: ParetoCheck {
    final var ID = "37dee029-605b-4aab-96b9-5438e5aa44d8"
    final var TITLE = "Unlocking macOS requires password"

    required init(defaults: UserDefaults = .standard, id _: String! = "", title _: String! = "") {
        super.init(defaults: defaults, id: ID, title: TITLE)
    }

    override func checkPasses() -> Bool {
        // if let idleTime = CFPreferencesCopyAppValue("idleTime" as CFString, "com.apple.screensaver" as CFString) as? String {
        if let askForPassword = readDefaults(app: "com.apple.screensaver", key: "askForPassword") {
            os_log("askForPassword: %{public}s", askForPassword)
            return Int(askForPassword) ?? 0 == 1
        }

        return false
    }
}
