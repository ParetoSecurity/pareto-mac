//
//  PasswordFromLock.swift.swift
//  PasswordFromLock.swift
//
//  Created by Janez Troha on 17/08/2021.
//

class RequirePasswordToUnlock: ParetoCheck {
    override var UUID: String {
        "f962c423-fdf5-428a-a57a-816abc9b252d"
    }

    override var Title: String {
        "Require password to unlock"
    }

    override func checkPasses() -> Bool {
        // possible:{require password to wake:false, class:security preferences object, secure virtual memory:false, require password to unlock:false, automatic login:false, log out when inactive:false, log out when inactive interval:60}
        let script = "tell application \"System Events\" to tell security preferences to get require password to unlock"
        let out = runOSA(appleScript: script) ?? "true"
        return out.contains("false")
    }
}
