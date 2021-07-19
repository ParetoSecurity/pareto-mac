//
//  ParetoApp.swift
//  Pareto
//
//  Created by Janez Troha on 12/07/2021.
//

import Foundation
import os.log
import SwiftUI

let logger = Logger(subsystem: "com.dz0ny.dev.pareto", category: "main")

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_: Notification) {
        statusBar = StatusBarController()
        NSWindow.allowsAutomaticWindowTabbing = false
        statusBar?.updateMenu()
        let timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [self] _ in
            self.statusBar?.runChecks()
            logger.info("Running checks")
        }
        RunLoop.current.add(timer, forMode: .common)
        statusBar?.runChecks()
    }

    @objc func showPrefs() {
        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
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
