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
    let checks = [
        GatekeeperCheck(),
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

    func menuDidClose(_: NSMenu) {
        updateMenu()
    }

    func menuWillOpen(_: NSMenu) {
        updateMenu()
    }

    func addApplicationItems() {
        addItem(NSMenuItem.separator())

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
