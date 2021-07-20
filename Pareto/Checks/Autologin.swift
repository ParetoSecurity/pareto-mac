//
//  Autologin.swift
//  Pareto Security
//
//  Created by Janez Troha on 19/07/2021.
//

import Foundation

class AutologinCheck: ParetoCheck {
    final var ID = "f962c423-fdf5-428a-a57a-816abc9b253e"
    final var TITLE = "Auto login is disabled"

    required init(defaults: UserDefaults = .standard, id _: String! = "", title _: String! = "") {
        super.init(defaults: defaults, id: ID, title: TITLE)
    }

    override func checkPasses() -> Bool {
        if let autoLoginUser = CFPreferencesCopyAppValue("autoLoginUser" as CFString, "com.apple.loginwindow" as CFString) as? String {
        //if let autoLoginUser = self.readDefaults(app: "com.apple.loginwindow", key: "autoLoginUser") {
            return !autoLoginUser.isEmpty
        }
        return false
    }
}
