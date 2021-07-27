//
//  ParetoApp.swift
//  Pareto
//
//  Created by Janez Troha on 12/07/2021.
//

import Foundation
import os.log
import SwiftUI
import AppUpdater

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBar: StatusBarController?
    let updater = AppUpdater(owner: "ParetoSecurity", repo: "pareto-mac")
    
    func applicationDidFinishLaunching(_: Notification) {
        statusBar = StatusBarController()
        NSWindow.allowsAutomaticWindowTabbing = false
        statusBar?.updateMenu()
        let timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [self] _ in
            self.statusBar?.runChecks()
            os_log("Running checks")
        }
        RunLoop.current.add(timer, forMode: .common)
        statusBar?.runChecks()

        // Update when waking up from sleep
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification,
                                                          object: nil,
                                                          queue: nil,
                                                          using: { _ in
                                                              self.statusBar?.runChecks()
                                                          })
    }

    @objc func showPrefs() {
        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(self)
    }

    @objc func runChecks() {
        statusBar?.runChecks()
    }
}

@main
struct Pareto: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}
