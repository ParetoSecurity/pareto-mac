//
//  Claim.swift
//  Claim
//
//  Created by Janez Troha on 16/08/2021.
//

import AppKit
import Defaults
import Foundation
import os.log
import OSLog
import SwiftUI

class Claim: Hashable {
    static func == (lhs: Claim, rhs: Claim) -> Bool {
        lhs.title == rhs.title
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
    }

    var title: String
    var checks: [ParetoCheck]

    var checksSorted: [ParetoCheck] {
        // Sort by a stable title (TitleON) so order doesn't jump
        checks.sorted(by: { $0.TitleON.lowercased() < $1.TitleON.lowercased() })
    }

    init(withTitle title: String, withChecks checks: [ParetoCheck]) {
        self.title = title
        self.checks = checks
    }

    var checksPassed: Bool { checks.allSatisfy { $0.isRunnable ? $0.checkPassed : true } }
    var checksNoError: Bool { checks.allSatisfy { $0.isRunnable ? !$0.hasError : true } }

    func addSubmenu(withTitle: String, action: Selector?) -> NSMenuItem {
        let item = NSMenuItem(title: withTitle, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    func menu() -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for check in checksSorted {
            let checkMenuItem = check.menu()

            // Always add the check to the menu
            submenu.addItem(checkMenuItem)
        }

        // Set the claim icon based on overall status
        if Defaults[.snoozeTime] > 0 {
            item.image = NSImage.SF(name: "shield.fill").tint(color: .systemGray)
        } else {
            if checksPassed && checksNoError {
                item.image = NSImage.SF(name: "checkmark.circle.fill").tint(color: Defaults.OKColor())
            } else {
                item.image = NSImage.SF(name: "xmark.diamond.fill").tint(color: Defaults.FailColor())
            }
        }

        // item.submenu = submenu
        item.submenu = submenu
        return item
    }

    func run() {
        for check in checks {
            if shouldRun(check) {
                let startTime = Date()
                check.run()
                let endTime = Date()
                let timeInterval = endTime.timeIntervalSince(startTime)
                Logger().log("uuid=\(check.UUID, privacy: .public) timeInterval=\(timeInterval, privacy: .public)")
            } else {
                os_log("Skipping check %{public}s due to visibility/run rules", log: Log.check, check.UUID)
            }
        }

        // Notify observers that aggregated status for this claim may have changed
        DispatchQueue.main.async {
            Claims.global.objectWillChange.send()
        }
    }

    func configure() {
        for check in checks {
            check.configure()
        }
        UserDefaults.standard.synchronize()
    }
}

private extension Claim {
    func shouldRun(_ check: ParetoCheck) -> Bool {
        // Special dependency rule: Time Machine dependents hidden if base off/unrunnable
        let isTimeMachineDependent = (check is TimeMachineHasBackupCheck) || (check is TimeMachineIsEncryptedCheck)
        let timeMachineUnavailable = (!TimeMachineCheck.sharedInstance.isActive || !TimeMachineCheck.sharedInstance.isRunnable)
        if isTimeMachineDependent && timeMachineUnavailable {
            return false
        }

        // Team-enforced checks always run unless explicitly exempt
        if check.teamEnforced && !check.teamEnforcedButExempt {
            return true
        }

        // App checks: run only if installed, recently used (when applicable), and not manually disabled
        if let app = check as? AppCheck {
            let appInstalled = app.isInstalled
            let appRecentlyUsed = !app.supportsRecentlyUsed || app.usedRecently
            let notManuallyDisabled = app.storedIsActive
            return appInstalled && appRecentlyUsed && notManuallyDisabled
        }

        // Non-app checks: run unless manually disabled
        return check.storedIsActive
    }
}
