//
//  StatusBarController.swift
//  Pareto
//
//  Created by Janez Troha on 12/07/2021.
//

import AppKit
import Defaults
import os.log
import SwiftUI

class StatusBarController: NSMenu, NSMenuDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let imageDefault = NSImage(named: "IconGray")
    let imageWarning = NSImage(named: "IconOrange")
    var isRunnig = false
    var workItem: DispatchWorkItem?

    private enum Snooze {
        static let oneHour = 3600 * 1000
        static let oneDay = oneHour * 24
        static let oneWeek = oneDay * 7
    }

    public var snoozeTime: Int {
        get { Defaults[.snoozeTime] }
        set { Defaults[.snoozeTime] = newValue }
    }

    required init(coder decoder: NSCoder) {
        super.init(coder: decoder)
    }

    init() {
        super.init(title: "")
        delegate = self
        setAccessibilityIdentifier("paretoMenu")
        statusItem.menu = self
        statusItem.button?.image = imageDefault
        statusItem.button?.imagePosition = .imageRight
        statusItem.button?.imageScaling = .scaleProportionallyDown
        statusItem.button?.target = self
    }

    var claimsPassed: Bool {
        var passed = true
        for claim in AppInfo.claims where claim.isActive && Defaults[.snoozeTime] == 0 {
            passed = passed && claim.checkPassed
        }
        return passed
    }

    func updateMenu() {
        removeAllItems()
        addChecksMenuItems()
        addApplicationItems()

        if claimsPassed {
            statusItem.button?.image = imageDefault
        } else {
            statusItem.button?.image = imageWarning
        }
    }

    func configureChecks() {
        for claim in AppInfo.claims {
            claim.configure()
        }
    }

    func runChecks() {
        if isRunnig {
            return
        }

        // Snooze in effect
        if Defaults[.snoozeTime] >= Date().currentTimeMillis() {
            os_log("Checks are snoozed until %s", log: Log.app, String(Defaults[.snoozeTime]))
            return
        } else {
            // snoze expired
            os_log("Snooze expired %s", log: Log.app, String(Defaults[.snoozeTime]))
            Defaults[.snoozeTime] = 0
        }

        Defaults[.lastCheck] = Date().currentTimeMillis()

        statusItem.button?.image = imageDefault
        isRunnig = true
        workItem = DispatchWorkItem {
            for claim in AppInfo.claims {
                claim.run()
            }
        }

        // update menus after checks have ran
        workItem?.notify(queue: .main) {
            self.isRunnig = false
            self.updateMenu()
            os_log("Checks finished running", log: Log.app)
        }

        // guard to prevent long running tasks
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(30)) {
            // checks are still running kill them
            if self.isRunnig {
                self.workItem?.cancel()
                self.updateMenu()
                os_log("Checks took more than 30s to finish canceling", log: Log.app)
            }
        }

        // run tasks
        DispatchQueue.main.async(execute: workItem!)
        os_log("Running check scheduler", log: Log.app)
    }

    func menuDidClose(_: NSMenu) {
        updateMenu()
        if Defaults[.internalRunChecks] {
            Defaults[.internalRunChecks] = false
            runChecks()
        }
    }

    func menuWillOpen(_: NSMenu) {
        updateMenu()
    }

    func addSubmenu(withTitle: String, action: Selector?) -> NSMenuItem {
        let item = NSMenuItem(title: withTitle, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc func snoozeOneHour() {
        snoozeTime = Date().currentTimeMillis() + Snooze.oneHour
    }

    @objc func snoozeOneDay() {
        snoozeTime = Date().currentTimeMillis() + Snooze.oneDay
    }

    @objc func snoozeOneWeek() {
        snoozeTime = Date().currentTimeMillis() + Snooze.oneWeek
    }

    @objc func unsnooze() {
        snoozeTime = 0
    }

    func addApplicationItems() {
        let lastItem = NSMenuItem(title: "Last check: \(Date().fromTimeStamp(timeStamp: Defaults[.lastCheck]))", action: nil, keyEquivalent: "")
        lastItem.target = NSApp.delegate
        addItem(lastItem)

        addItem(NSMenuItem.separator())

        let runItem = NSMenuItem(title: "Run Checks", action: #selector(AppDelegate.runChecks), keyEquivalent: "r")
        runItem.target = NSApp.delegate
        addItem(runItem)

        let submenu = NSMenu()
        if Defaults[.snoozeTime] == 0 {
            submenu.addItem(addSubmenu(withTitle: "Snooze for 1 hour", action: #selector(snoozeOneHour)))
            submenu.addItem(addSubmenu(withTitle: "Snooze for 1 day", action: #selector(snoozeOneDay)))
            submenu.addItem(addSubmenu(withTitle: "Snooze for 1 week", action: #selector(snoozeOneWeek)))

        } else {
            submenu.addItem(addSubmenu(withTitle: "Resume", action: #selector(unsnooze)))
            submenu.addItem(addSubmenu(withTitle: "Resumes: \(Date().fromTimeStamp(timeStamp: snoozeTime))", action: nil))
        }

        let snoozeItem = NSMenuItem(title: "Snooze", action: nil, keyEquivalent: "")
        snoozeItem.submenu = submenu
        addItem(snoozeItem)

        let preferencesItem = NSMenuItem(title: "Preferences", action: #selector(AppDelegate.showPrefs), keyEquivalent: "p")
        preferencesItem.target = NSApp.delegate
        addItem(preferencesItem)

        let reportItem = NSMenuItem(title: "Report Bug", action: #selector(AppDelegate.reportBug), keyEquivalent: "b")
        reportItem.target = NSApp.delegate
        addItem(reportItem)

        addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit Pareto App", action: #selector(AppDelegate.quitApp), keyEquivalent: "q")
        quitItem.target = NSApp.delegate
        addItem(quitItem)
    }

    func addChecksMenuItems() {
        for claim in AppInfo.claims.sorted(by: { $0.title < $1.title }) {
            addItem(claim.menu())
        }
    }
}
