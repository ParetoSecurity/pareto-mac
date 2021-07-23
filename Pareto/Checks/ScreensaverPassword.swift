//
//  ScreensaverPassword.swift
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
        let homeDirURL = FileManager.default.homeDirectoryForCurrentUser.path.replacingOccurrences(of: "/Library/Containers/dz0ny.dev.Pareto/Data", with: "")
        let dictionary = readDefaultsFile(path: homeDirURL + "/Library/Preferences/com.apple.screensaver.plist")

        if let askForPassword = dictionary?.value(forKey: "askForPassword") as? Int {
            // os_log("askForPassword: %{public}s", askForPassword)
            return askForPassword == 1
        }

        return false
    }
}
