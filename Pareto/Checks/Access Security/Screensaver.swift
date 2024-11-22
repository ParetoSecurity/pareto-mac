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
        "Screensaver or screen lock shows in under 20min"
    }

    override var TitleOFF: String {
        "Screensaver or screen lock shows in more than 20min"
    }

    override public var showSettingsWarnEvents: Bool {
        return true
    }
    
    func checkScreensaver() -> Bool {
        let script = "tell application \"System Events\" to tell screen saver preferences to get delay interval"
        let out = Int(runOSA(appleScript: script)?.trim() ?? "0") ?? 0
        return out >= 0 && out <= 60 * 20
    }
    
    // https://github.com/usnistgov/macos_security/blob/e22bb0bc02290c54cb968bc3749942fa37ad752b/rules/os/os_screensaver_timeout_loginwindow_enforce.yaml#L4
    func checkLock() -> Bool {
        let script = """
        function run() {
            let timeout = ObjC.unwrap($.NSUserDefaults.alloc.initWithSuiteName('com.apple.screensaver')\
          .objectForKey('loginWindowIdleTime'))
            return timeout;
          }
        """;
        let val = runOSAJS(appleScript: script)
        let out = Int(val?.trim() ?? "0") ?? 0
        return out >= 0 && out <= 60 * 20
    }

    override func checkPasses() -> Bool {
        return checkScreensaver() && checkLock()
    }
}
