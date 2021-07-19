//
//  StatusBarController.swift
//  Pareto
//
//  Created by Janez Troha on 12/07/2021.
//

import AppKit
import SwiftUI

class StatusBarController: NSMenu, NSMenuDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    var workItem: DispatchWorkItem?

    let checks = [
        GatekeeperCheck(),
        FirewallCheck(),
        AutologinCheck(),
        ScreensaverCheck()
    ]

    required init(coder decoder: NSCoder) {
        super.init(coder: decoder)
    }

    init() {
        super.init(title: "")
        delegate = self
        statusItem.menu = self
        statusItem.button?.image = #imageLiteral(resourceName: "StatusBarIcon")
        statusItem.button?.image?.size = NSSize(width: 18.0, height: 18.0)
        statusItem.button?.image?.isTemplate = true
        statusItem.button?.target = self
        updateMenu()
    }

    func updateMenu() {
        removeAllItems()
        addChecksMenuItems()
        addApplicationItems()
    }

    func runChecks() {
        statusItem.button?.appearsDisabled = true
        workItem = DispatchWorkItem {
            for check in self.checks {
                check.run()
            }
        }

        // update mensu after checks have ran
        workItem?.notify(queue: .main) {
            self.updateMenu()
            self.statusItem.button?.appearsDisabled = false
            logger.info("Checks finished running")
        }

        // guard to prevent long running tasks
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(60)) {
            self.workItem?.cancel()
            self.statusItem.button?.appearsDisabled = false
            logger.warning("Checks took more than 60s to finish canceling")
        }

        // run tasks
        DispatchQueue.main.async(execute: workItem!)
        logger.info("Running check scheduler")
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
