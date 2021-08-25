//
//  ParetoApp.swift
//  Pareto
//
//  Created by Janez Troha on 12/07/2021.
//

import Defaults
import Foundation
import os.log
import OSLog
import SwiftUI

enum Window: String, CaseIterable {
    case Welcome
    case Update

    func show() {
        if let url = URL(string: "paretosecurity://\(rawValue)") { // replace myapp with your app's name
            NSWorkspace.shared.open(url)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_: Notification) {
        statusBar = StatusBarController()
        statusBar?.configureChecks()
        statusBar?.updateMenu()
        statusBar?.runChecks()

        // Update when waking up from sleep
        NSWorkspace.onWakeup { _ in
            if Defaults[.runAfterSleep] {
                self.statusBar?.runChecks()
            }
        }

        // Schedule hourly claim updates
        NSBackgroundActivityScheduler.repeating(withInterval: 60 * 60) { (completion: NSBackgroundActivityScheduler.CompletionHandler) in
            self.statusBar?.runChecks()
            os_log("Running checks")
            completion(.finished)
        }

        if Defaults[.showWelcome] {
            Window.Welcome.show()
            Defaults[.showWelcome] = false
        }
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

    @objc func reportBug() {
        NSWorkspace.shared.open(AppInfo.bugReportURL())
    }
}

@main
struct Pareto: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }

        WindowGroup(Window.Welcome.rawValue) {
            WelcomeView()
        }.handlesExternalEvents(matching: Set(arrayLiteral: Window.Welcome.rawValue)).windowStyle(.hiddenTitleBar)

        WindowGroup(Window.Update.rawValue) {
            WelcomeView()
        }.handlesExternalEvents(matching: Set(arrayLiteral: Window.Update.rawValue)).windowStyle(.hiddenTitleBar)
    }
}
