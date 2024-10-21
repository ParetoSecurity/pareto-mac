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
                        item.image = NSImage.SF(name: "checkmark.circle.fill").tint(color: Defaults.OKColor())
                    } else {
                        item.image = NSImage.SF(name: "xmark.diamond.fill").tint(color: Defaults.FailColor())
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
            let startTime = Date()
            check.run()
            let endTime = Date()
            let timeInterval = endTime.timeIntervalSince(startTime)
            Logger().log("uuid=\(check.UUID, privacy: .public) timeInterval=\(timeInterval, privacy: .public)")

        
        }
    }

    func configure() {
        for check in checks {
            check.configure()
        }
        UserDefaults.standard.synchronize()
    }
}
