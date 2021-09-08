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

    init(withTitle title: String, withChecks checks: [ParetoCheck]) {
        self.title = title
        self.checks = AppInfo.inSandbox ? checks.filter { $0.canRunInSandbox } : checks
    }

    var checkPassed: Bool { checks.allSatisfy { $0.isActive ? $0.checkPassed : true } }
    var isActive: Bool { checks.allSatisfy { $0.isActive } }
    var isDisabled: Bool { checks.allSatisfy { !$0.isActive } }

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
            if !isDisabled {
                if Defaults[.snoozeTime] > 0 {
                    item.image = NSImage.SF(name: "powersleep").tint(color: .systemGray)
                } else {
                    if checkPassed {
                        item.image = NSImage.SF(name: "checkmark.shield.fill").tint(color: .systemGreen)
                    } else {
                        item.image = NSImage.SF(name: "xmark.shield.fill").tint(color: .systemOrange)
                    }
                }
            } else {
                item.image = NSImage.SF(name: "shield")
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
