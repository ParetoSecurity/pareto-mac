//
//  SystemIntegrityProtection.swift
//  Pareto Security
//
//  Created by Roberto Alfieri on 03/11/2026.
//

import Foundation
import os.log

class SystemIntegrityProtectionCheck: ParetoCheck {
    static let sharedInstance = SystemIntegrityProtectionCheck()

    let statusProvider: () -> String

    init(statusProvider: @escaping () -> String = {
        runCMD(app: "/usr/bin/csrutil", args: ["status"])
    }) {
        self.statusProvider = statusProvider
    }

    override var UUID: String {
        "68c882be-2525-4e72-9326-07d3fa666d8e"
    }

    override var TitleON: String {
        "System Integrity Protection is on"
    }

    override var TitleOFF: String {
        "System Integrity Protection is off"
    }

    override func checkPasses() -> Bool {
        let output = statusProvider()
        os_log("csrutil status: %{public}@", log: Log.check, output.trim())
        return output.contains("System Integrity Protection status: enabled")
    }
}
