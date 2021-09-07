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
        for claim in AppInfo.claims where claim.isActive && claim.isNotSnoozed {
            passed = passed && claim.checkPassed
        }
        return passed
    }

    var claimsSnoozed: Int {
        var snoozedTime = 0
        for claim in AppInfo.claims where claim.isActive {
            snoozedTime += claim.snoozeTime
        }
        return snoozedTime
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

    func addApplicationItems() {
        addItem(NSMenuItem.separator())

        let runItem = NSMenuItem(title: "Run Checks", action: #selector(AppDelegate.runChecks), keyEquivalent: "r")
        runItem.target = NSApp.delegate
        addItem(runItem)

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
