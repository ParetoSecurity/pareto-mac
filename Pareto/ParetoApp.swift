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
    var updater: AppUpdater?

    func applicationDidFinishLaunching(_: Notification) {
        statusBar = StatusBarController()
        statusBar?.configureChecks()
        statusBar?.updateMenu()

        updater = AppUpdater(owner: "ParetoSecurity", repo: "pareto-mac")
        // stop running checks here
        if AppInfo.isRunningTests {
            return
        }
        statusBar?.runChecks()

        // Update when waking up from sleep
        NSWorkspace.onWakeup { _ in
            if Defaults[.runAfterSleep] {
                self.statusBar?.runChecks()
            }
        }

        // Schedule hourly claim updates
        NSBackgroundActivityScheduler.repeating(withName: "ClaimRunner", withInterval: 60 * 60) { (completion: NSBackgroundActivityScheduler.CompletionHandler) in
            os_log("Running checks")
            self.statusBar?.runChecks()
            completion(.finished)
        }

        NSBackgroundActivityScheduler.repeating(withName: "UpdateRunner", withInterval: 24 * 60 * 60) { (completion: NSBackgroundActivityScheduler.CompletionHandler) in
            os_log("Running update check")
            DispatchQueue.main.async { self.checkForRelease(isInteractive: false) }
            completion(.finished)
        }

        // if Defaults[.showWelcome] {
        //     Window.Welcome.show()
        //     Defaults[.showWelcome] = false
        // }
    }

    func checkForRelease(isInteractive interactive: Bool) {
        let currentVersion = Bundle.main.version
        if let release = try? updater!.getLatestRelease() {
            if currentVersion >= release.version {
                if interactive {
                    let alert = NSAlert()
                    alert.messageText = "You are running the latest version"
                    alert.informativeText = "No update is required."
                    alert.alertStyle = NSAlert.Style.informational
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }

            } else {
                if let dmgURL = release.assets.filter({ $0.browser_download_url.path.hasSuffix(".dmg") }).first {
                    let alert = NSAlert()
                    alert.messageText = "New version of Pareto Security \(release.version) is available"
                    alert.informativeText = release.body
                    alert.alertStyle = NSAlert.Style.informational
                    alert.addButton(withTitle: "Download")
                    alert.addButton(withTitle: "Skip")
                    if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
                        NSWorkspace.shared.open(dmgURL.browser_download_url)
                    }
                }
            }
        }
    }

    @objc func maybeUpdate() {
        checkForRelease(isInteractive: true)
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

        // WindowGroup(Window.Welcome.rawValue) {
        //    UpdateView()
        // }.handlesExternalEvents(matching: [Window.Welcome.rawValue])

        // WindowGroup(Window.Update.rawValue) {
        //     WelcomeView()
        // }.handlesExternalEvents(matching: Set([Window.Update.rawValue])).windowStyle(.hiddenTitleBar)
    }
}
