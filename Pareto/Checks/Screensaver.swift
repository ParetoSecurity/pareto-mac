//
//  Screensaver.swift
//  Pareto Security
//
//  Created by Janez Troha on 19/07/2021.
//

import Foundation

class ScreensaverCheck: ParetoCheck {
    final var ID = "13e4dbf1-f87f-4bd9-8a82-f62044f002f4"
    final var TITLE = "Screen locks in under 5 minutes"

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

