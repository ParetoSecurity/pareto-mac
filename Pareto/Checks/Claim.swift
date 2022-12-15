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
import SwiftUI

class Claim: Hashable {
    static func == (lhs: Claim, rhs: Claim) -> Bool {
        lhs.title == rhs.title
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
    }

    public var title: String
    public var checks: [ParetoCheck]

    public var checksSorted: [ParetoCheck] {
        checks.sorted(by: { $0.Title.lowercased() < $1.Title.lowercased() })
    }

    init(withTitle title: String, withChecks checks: [ParetoCheck]) {
        self.title = title
        self.checks = checks
    }

    var checksPassed: Bool { checks.allSatisfy { $0.isRunnable ? $0.checkPassed : true } }

    func addSubmenu(withTitle: String, action: Selector?) -> NSMenuItem {
        let item = NSMenuItem(title: withTitle, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    func menu() -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for check in checksSorted {
            if check.isRunnable {
                submenu.addItem(check.menu())
                if Defaults[.snoozeTime] > 0 {
                    item.image = NSImage.SF(name: "shield.fill").tint(color: .systemGray)
                } else {
                    if checksPassed {
                        item.image = NSImage.SF(name: "checkmark.circle.fill").tint(color: .systemGreen)
                    } else {
                        item.image = NSImage.SF(name: "xmark.diamond.fill").tint(color: .systemOrange)
                    }
                }
            }
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
}

class ClaimWithNudge: Claim {
    override func menu() -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        var allPassed = true
        for check in checksSorted {
            if check.isRunnable {
                submenu.addItem(check.menu())
                if Defaults[.snoozeTime] > 0 {
                    item.image = NSImage.SF(name: "shield.fill").tint(color: .systemGray)
                } else {
                    let passed = checksPassed
                    allPassed = allPassed && passed
                    if passed {
                        item.image = NSImage.SF(name: "checkmark.circle.fill").tint(color: .systemGreen)
                    } else {
                        item.image = NSImage.SF(name: "xmark.diamond.fill").tint(color: .systemOrange)
                    }
                }
            }
        }
        if !allPassed {
            let nudge = NSMenuItem(title: "Enable one-click bulk updates of apps", action: #selector(AppDelegate.reportBug), keyEquivalent: "")

            nudge.image = NSImage.SF(name: "sparkles").tint(color: .systemYellow)
            submenu.addItem(nudge)
        }
        // item.submenu = submenu
        item.submenu = submenu
        return item
    }
}
