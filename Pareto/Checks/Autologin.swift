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
        let path = "/Library/Preferences/com.apple.loginwindow.plist"
        guard let dictionary = NSDictionary(contentsOfFile: path) else {
            return false
        }
        if let autoLoginUser = dictionary.object(forKey: "autoLoginUser") as? String {
            return autoLoginUser.isEmpty
        }
        return false
    }
}
