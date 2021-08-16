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
    final var TITLE = "Password after sleep or screen saver"

    required init(id _: String! = "", title _: String! = "") {
        super.init(id: ID, title: TITLE)
    }

    override func checkPasses() -> Bool {
        let script = "tell application \"System Events\" to tell security preferences to get require password to wake"
        let out = runOSA(appleScript: script) ?? "false"
        return out.contains("true")
    }
}
