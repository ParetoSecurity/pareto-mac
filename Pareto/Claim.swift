//
//  Claim.swift
//  Claim
//
//  Created by Janez Troha on 16/08/2021.
//

import AppKit
import Foundation
import os.log
import SwiftUI

class Claim {
    private enum Snooze {
        static let oneHour = 3600
        static let oneDay = oneHour * 24
        static let oneWeek = oneDay * 7
    }

    public var title: String
    public var checks: [ParetoCheck]

    init(withTitle title: String, withChecks checks: [ParetoCheck]) {
        self.title = title
        self.checks = AppInfo.inSandbox ? checks.filter { $0.canRunInSandbox } : checks
    }

    var checkPassed: Bool { checks.allSatisfy { $0.checkPassed } }

    var snoozeTime: Int { checks.reduce(0) {
        $0 + $1.snoozeTime
    } }

    var isActive: Bool { checks.allSatisfy { $0.isActive } }

    var lastCheck: Int {
        return checks.first!.checkTimestamp
    }

    func addSubmenu(withTitle: String, action: Selector?) -> NSMenuItem {
        let item = NSMenuItem(title: withTitle, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    func menu() -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for check in checks.sorted(by: { $0.Title < $1.Title }) {
            submenu.addItem(check.menu())
            if isActive {
                if snoozeTime > 0 {
                    item.image = NSImage.SF(name: "powersleep").tint(color: .systemGray)
                } else {
                    if checkPassed {
                        item.image = NSImage.SF(name: "checkmark.shield").tint(color: .systemBlue)
                    } else {
                        item.image = NSImage.SF(name: "exclamationmark.shield").tint(color: .systemRed)
                    }
                }
            } else {
                item.image = NSImage.SF(name: "shield.slash")
            }
        }
        submenu.addItem(addSubmenu(withTitle: "Last check: \(Date().fromTimeStamp(timeStamp: lastCheck))", action: nil))
        submenu.addItem(NSMenuItem.separator())

        if snoozeTime == 0 {
            if isActive {
                submenu.addItem(addSubmenu(withTitle: "Snooze for 1 hour", action: #selector(snoozeOneHour)))
                submenu.addItem(addSubmenu(withTitle: "Snooze for 1 day", action: #selector(snoozeOneDay)))
                submenu.addItem(addSubmenu(withTitle: "Snooze for 1 week", action: #selector(snoozeOneWeek)))
            }
        } else {
            if isActive {
                submenu.addItem(addSubmenu(withTitle: "Unsnooze", action: #selector(unsnooze)))
                submenu.addItem(addSubmenu(withTitle: "Resumes: \(Date().fromTimeStamp(timeStamp: lastCheck + (snoozeTime * 1000)))", action: nil))
            }
        }

        submenu.addItem(NSMenuItem.separator())
        if isActive {
            submenu.addItem(addSubmenu(withTitle: "Disable", action: #selector(disableCheck)))
        } else {
            submenu.addItem(addSubmenu(withTitle: "Enable", action: #selector(enableCheck)))
        }

        // item.submenu = submenu
        item.submenu = submenu
        return item
    }

    func run() {
        for check in checks {
            check.run()
        }
    }

    func configure() {
        for check in checks {
            check.configure()
        }
        UserDefaults.standard.synchronize()
    }

    @objc func disableCheck() {
        os_log("Disabling claim for %{public}s", log: Log.app, title)
        for check in checks {
            check.isActive = false
            check.checkPassed = false
            check.checkTimestamp = 0
        }
        UserDefaults.standard.synchronize()
    }

    @objc func enableCheck() {
        os_log("Enabling claim for %{public}s", log: Log.app, title)
        for check in checks {
            check.isActive = true
            check.checkPassed = false
            check.checkTimestamp = 0
        }
        UserDefaults.standard.synchronize()
    }

    @objc func snoozeOneHour() {
        for check in checks {
            check.snoozeTime = Snooze.oneHour
        }
        UserDefaults.standard.synchronize()
    }

    @objc func snoozeOneDay() {
        for check in checks {
            check.snoozeTime = Snooze.oneDay
        }
        UserDefaults.standard.synchronize()
    }

    @objc func snoozeOneWeek() {
        for check in checks {
            check.snoozeTime = Snooze.oneWeek
        }
        UserDefaults.standard.synchronize()
    }

    @objc func unsnooze() {
        for check in checks {
            check.snoozeTime = 0
        }
        UserDefaults.standard.synchronize()
    }
}
