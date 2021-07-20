//
//  Screensaver.swift
//  Pareto Security
//
//  Created by Janez Troha on 19/07/2021.
//

import Foundation
import os.log

class ScreensaverCheck: ParetoCheck {
    final var ID = "13e4dbf1-f87f-4bd9-8a82-f62044f002f4"
    final var TITLE = "Screen locks in under 5 minutes"
    
    required init(defaults: UserDefaults = .standard, id _: String! = "", title _: String! = "") {
        super.init(defaults: defaults, id: ID, title: TITLE)
    }
    
    override func checkPasses() -> Bool {
        //if let idleTime = CFPreferencesCopyAppValue("idleTime" as CFString, "com.apple.screensaver" as CFString) as? String {
        if let idleTime = self.readDefaults(app: "com.apple.screensaver", key: "idleTime") {
            os_log("idleTime: %{public}s", idleTime)
            return Int(idleTime) ?? 0 <= 300
        }
        
        return false
    }
}

