//
//  MenuItemCheck.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/07/2021.
//

import AppKit
import Combine
import Foundation
import OSLog
import SwiftUI

class ParetoCheck: ObservableObject {
    private enum Snooze {
        static let oneHour = 3600
        static let oneDay = oneHour * 24
        static let oneWeek = oneDay * 7
    }

    private let cancellable: Cancellable
    private let defaults: UserDefaults
    private let UUID: String
    private let title: String

    let objectWillChange = PassthroughSubject<Void, Never>()

    var EnabledKey: String {
        UUID + "-Enabled"
    }

    var SnoozeKey: String {
        UUID + "-Snooze"
    }

    required init(defaults: UserDefaults = .standard, id: String! = "", title: String! = "") {
        self.defaults = defaults
        UUID = id
        self.title = title

        defaults.register(defaults: [
            UUID + "-Enabled": true,
            UUID + "-Snooze": 0,
        ])

        cancellable = NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification)
            .map { _ in () }
            .subscribe(objectWillChange)
    }

    var isActive: Bool {
        set { defaults.set(newValue, forKey: EnabledKey) }
        get { defaults.bool(forKey: EnabledKey) }
    }

    var snoozeTime: Int {
        set { defaults.set(newValue, forKey: SnoozeKey) }
        get { defaults.integer(forKey: SnoozeKey) }
    }

    @objc func moreInfo() {
        if let url = URL(string: "https://paretosecurity.app/check/" + UUID) {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func disableCheck() {
        isActive = false
    }

    @objc func enableCheck() {
        isActive = true
    }

    @objc func snoozeOneHour() {
        snoozeTime = Snooze.oneHour
    }

    @objc func snoozeOneDay() {
        snoozeTime = Snooze.oneDay
    }

    @objc func snoozeOneWeek() {
        snoozeTime = Snooze.oneWeek
    }

    @objc func unsnooze() {
        snoozeTime = 0
    }

    func addSubmenu(withTitle: String, action: Selector?) -> NSMenuItem {
        let item = NSMenuItem(title: withTitle, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    func checkPasses() -> Bool {
        fatalError("checkPasses() is not implemented")
    }

    func menu() -> NSMenuItem {
        let status = snoozeTime == 0 ? checkPasses() ? "✅ " : "❌ " : "🕒 "
        let item = NSMenuItem(title: status + title, action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        submenu.addItem(addSubmenu(withTitle: "More Information", action: #selector(moreInfo)))
        submenu.addItem(NSMenuItem.separator())
        if snoozeTime == 0 {
            submenu.addItem(addSubmenu(withTitle: "Snooze for 1 hour", action: #selector(snoozeOneHour)))
            submenu.addItem(addSubmenu(withTitle: "Snooze for 1 day", action: #selector(snoozeOneDay)))
            submenu.addItem(addSubmenu(withTitle: "Snooze for 1 week", action: #selector(snoozeOneWeek)))
        } else {
            submenu.addItem(addSubmenu(withTitle: "Resume", action: #selector(unsnooze)))
        }

        submenu.addItem(NSMenuItem.separator())
        if isActive {
            submenu.addItem(addSubmenu(withTitle: "Disable", action: #selector(disableCheck)))
        } else {
            submenu.addItem(addSubmenu(withTitle: "Enable", action: #selector(enableCheck)))
        }

        item.submenu = submenu
        return item
    }
}
