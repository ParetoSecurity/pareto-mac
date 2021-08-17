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
    let imageDefault = NSImage(named: "IconGray")
    let imageWarning = NSImage(named: "IconOrange")
    var isRunnig = false
    var workItem: DispatchWorkItem?

    let claims = [
        Claim(withTitle: "Login is secure", withChecks: [AutologinCheck(), RequirePasswordToUnlock()]),
        Claim(withTitle: "Firewall is on", withChecks: [FirewallCheck()]),
        Claim(withTitle: "System integrity", withChecks: [GatekeeperCheck(), FileVaultCheck()]),
        Claim(withTitle: "Lock after inactivity", withChecks: [ScreensaverPasswordCheck(), ScreensaverCheck()])
        // Claim(withTitle: "Apps are up-to-date", withChecks: [IntegrationCheck(), IntegrationCheck()])
    ]

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

    var claimsPassed: Bool { claims.reduce(true) {
        $0 && $1.checkPassed
    } }

    var claimsSnoozed: Int { claims.reduce(0) {
        $0 + $1.snoozeTime
    } }

    func updateMenu() {
        removeAllItems()
        addChecksMenuItems()
        addApplicationItems()
        if claimsSnoozed > 0 {
            statusItem.button?.image = imageWarning
        } else {
            if claimsPassed {
                statusItem.button?.image = imageDefault
            } else {
                statusItem.button?.image = imageWarning
            }
        }
    }

    func runChecks() {
        if isRunnig {
            return
        }
        statusItem.button?.image = imageDefault
        isRunnig = true
        workItem = DispatchWorkItem {
            for claim in self.claims {
                claim.run()
            }
        }

        // update menus after checks have ran
        workItem?.notify(queue: .main) {
            self.isRunnig = false
            self.updateMenu()
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
    }

    func menuWillOpen(_: NSMenu) {
        updateMenu()
    }

    func addApplicationItems() {
        addItem(NSMenuItem.separator())

        let runItem = NSMenuItem(title: "Update", action: #selector(AppDelegate.runChecks), keyEquivalent: "c")
        runItem.target = NSApp.delegate
        addItem(runItem)

        let aboutItem = NSMenuItem(title: "Preferences", action: #selector(AppDelegate.showPrefs), keyEquivalent: "s")
        aboutItem.target = NSApp.delegate
        addItem(aboutItem)

        let reportItem = NSMenuItem(title: "Report Bug", action: #selector(AppDelegate.reportBug), keyEquivalent: "b")
        reportItem.target = NSApp.delegate
        addItem(reportItem)

        addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit Pareto App", action: #selector(AppDelegate.quitApp), keyEquivalent: "q")
        quitItem.target = NSApp.delegate
        addItem(quitItem)
    }

    func addChecksMenuItems() {
        for claim in claims.sorted(by: { $0.title < $1.title }) {
            addItem(claim.menu())
        }
    }
}
