//
//  Claim.swift
//  Claim
//
//  Created by Janez Troha on 16/08/2021.
//

import Foundation
import SwiftUI

class Claim {
    public var title: String
    public var checks: [ParetoCheck]

    init(withTitle title: String, withChecks checks: [ParetoCheck]) {
        self.title = title
        self.checks = checks
    }

    var checkPassed: Bool { checks.reduce(true) {
        $0 && $1.isActive ? $1.checkPassed : true
    } }

    var snoozeTime: Int { checks.reduce(0) {
        $0 + $1.snoozeTime
    } }

    var isActive: Bool { checks.reduce(true) {
        $0 && $1.isActive
    } }

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
        item.submenu = submenu
        return item
    }

    func run() {
        for check in checks {
            check.run()
        }
    }
}
