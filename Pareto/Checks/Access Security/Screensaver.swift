//
//  Screensaver.swift
//  Pareto Security
//
//  Created by Janez Troha on 19/07/2021.
//

class ScreensaverCheck: ParetoCheck {
    static let sharedInstance = ScreensaverCheck()
    override var UUID: String {
        "13e4dbf1-f87f-4bd9-8a82-f62044f002f4"
    }

    override var TitleON: String {
        "Screensaver shows in under 20min"
    }

    override var TitleOFF: String {
        "Screensaver shows in more than 20min"
    }

    override public var showSettingsWarnEvents: Bool {
        return true
    }

    override func checkPasses() -> Bool {
        let script = "tell application \"System Events\" to tell screen saver preferences to get delay interval"
        let out = Int(runOSA(appleScript: script)?.trim() ?? "0") ?? 0
        return out > 0 && out <= 60 * 20
    }
}
