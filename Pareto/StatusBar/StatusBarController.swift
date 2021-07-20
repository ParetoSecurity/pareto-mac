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
    let imageRunning = NSImage.SF(name: "bolt.horizontal.circle.fill").tint(color: .systemTeal)
    let imageDefault = NSImage.SF(name: "icloud.fill")
    var workItem: DispatchWorkItem?

    let checks = [
        GatekeeperCheck(),
        FirewallCheck(),
        AutologinCheck(),
        ScreensaverCheck(),
        ScreensaverPasswordCheck(),
        ZoomCheck(),
        OnePasswordCheck(),
    ]

    required init(coder decoder: NSCoder) {
        super.init(coder: decoder)
    }

    init() {
        super.init(title: "")
        delegate = self
        statusItem.menu = self
        statusItem.button?.image = imageDefault
        statusItem.button?.target = self
        updateMenu()
    }

    func updateMenu() {
        var status = true
        
        removeAllItems()
        addChecksMenuItems()
        addApplicationItems()
        for check in self.checks {
            status = check.checkPassed && status
        }
        if status {
            self.statusItem.button?.image = self.imageDefault.tint(color: .systemBlue)
        }else{
            self.statusItem.button?.image = self.imageDefault.tint(color: .systemRed)
        }
        
    }

    func runChecks() {

        statusItem.button?.appearsDisabled = true
        self.statusItem.button?.image = self.imageRunning.tint(color: .systemOrange)
        workItem = DispatchWorkItem {
            for check in self.checks {
                check.run()
            }
        }

        // update menus after checks have ran
        workItem?.notify(queue: .main) {
            self.updateMenu()
            self.statusItem.button?.appearsDisabled = false
            self.statusItem.button?.image = self.imageDefault
            self.updateMenu()
            os_log("Checks finished running")
            
        }

        // guard to prevent long running tasks
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(60)) {
            self.workItem?.cancel()
            self.statusItem.button?.appearsDisabled = false
            self.statusItem.button?.image = self.imageDefault
            self.updateMenu()
            os_log("Checks took more than 60s to finish canceling")
        }

        // run tasks
        DispatchQueue.main.async(execute: workItem!)
        os_log("Running check scheduler")
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
