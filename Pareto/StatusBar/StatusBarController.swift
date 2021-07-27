//
//  StatusBarController.swift
//  Pareto
//
//  Created by Janez Troha on 12/07/2021.
//

import AppKit
import os.log
import SwiftUI

class StatusBarController: NSMenu, NSMenuDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let imageRunning = NSImage(named: "IconGray")
    let imageDefault = NSImage(named: "IconGreen")
    let imageWarning = NSImage(named: "IconOrange")
    let imageError = NSImage(named: "IconRed")
    var isRunnig = false
    var workItem: DispatchWorkItem?

    let checks = [
        GatekeeperCheck(),
        FirewallCheck(),
        AutologinCheck(),
        ScreensaverCheck(),
        ScreensaverPasswordCheck(),
        ZoomCheck(),
        OnePasswordCheck(),
        VPNConnectionCheck()
    ]

    required init(coder decoder: NSCoder) {
        super.init(coder: decoder)
    }

    init() {
        super.init(title: "")
        delegate = self
        statusItem.menu = self
        statusItem.button?.image = imageDefault
        statusItem.button?.imagePosition = .imageRight
        statusItem.button?.target = self
        updateMenu()
    }

    func updateMenu() {
        var status = true
        var snoozed = 0
        removeAllItems()
        addChecksMenuItems()
        addApplicationItems()
        for check in checks where check.isActive {
            status = check.checkPassed && status
            snoozed += check.snoozeTime
        }
        if snoozed > 0 {
            statusItem.button?.image = imageWarning
        } else {
            if status {
                statusItem.button?.image = imageDefault
            } else {
                statusItem.button?.image = imageError
            }
        }
    }

    func runChecks() {
        if isRunnig {
            return
        }
        statusItem.button?.appearsDisabled = true
        statusItem.button?.image = imageRunning
        isRunnig = true
        workItem = DispatchWorkItem {
            for check in self.checks {
                check.run()
            }
        }

        // update menus after checks have ran
        workItem?.notify(queue: .main) {
            self.isRunnig = false
            self.updateMenu()
            self.statusItem.button?.appearsDisabled = false
            self.updateMenu()
            os_log("Checks finished running", log: Log.app)
        }

        // guard to prevent long running tasks
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(30)) {
            self.workItem?.cancel()

            // checks are still running kill them
            if self.isRunnig {
                self.statusItem.button?.appearsDisabled = false
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
    }

    func menuWillOpen(_: NSMenu) {
        updateMenu()
    }

    func addApplicationItems() {
        addItem(NSMenuItem.separator())

        let runItem = NSMenuItem(title: "Check", action: #selector(AppDelegate.runChecks), keyEquivalent: "c")
        runItem.target = NSApp.delegate
        addItem(runItem)

        let aboutItem = NSMenuItem(title: "Preferences", action: #selector(AppDelegate.showPrefs), keyEquivalent: "s")
        aboutItem.target = NSApp.delegate
        addItem(aboutItem)

        let quitItem = NSMenuItem(title: "Quit Pareto App", action: #selector(AppDelegate.quitApp), keyEquivalent: "q")
        quitItem.target = NSApp.delegate
        addItem(quitItem)
    }

    func addChecksMenuItems() {
        for check in checks {
            addItem(check.menu())
        }
    }
}
