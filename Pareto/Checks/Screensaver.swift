//
//  Screensaver.swift
//  Pareto Security
//
//  Created by Janez Troha on 19/07/2021.
//

class ScreensaverCheck: ParetoCheck {
    override var UUID: String {
        "13e4dbf1-f87f-4bd9-8a82-f62044f002f4"
    }

    override var TitleON: String {
        "Screen saver shows in under 5min"
    }

    override var TitleOFF: String {
        "Screen saver shows in more than 5min"
    }

    override func checkPasses() -> Bool {
        let script = "tell application \"System Events\" to tell screen saver preferences to get delay interval"
        let out = runOSA(appleScript: script) ?? "0"
        return Int(out) ?? 0 <= 300
    }
}
