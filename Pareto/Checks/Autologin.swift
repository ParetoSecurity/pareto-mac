//
//  Autologin.swift
//  Pareto Security
//
//  Created by Janez Troha on 19/07/2021.
//

import Foundation
import os.log

class AutologinCheck: ParetoCheck {
    final var ID = "f962c423-fdf5-428a-a57a-816abc9b253e"
    final var TITLE = "Auto login is disabled"

    required init(defaults: UserDefaults = .standard, id _: String! = "", title _: String! = "") {
        super.init(defaults: defaults, id: ID, title: TITLE)
    }

    override func checkPasses() -> Bool {
        let dictionary = readDefaultsFile(path: "/Library/Preferences/com.apple.loginwindow.plist")
        if let autoLoginUser = dictionary?.value(forKey: "autoLoginUser") as? String {
            os_log("autoLoginUser: %{public}s", autoLoginUser)
            return !autoLoginUser.isEmpty
        }
        return true
    }
}
