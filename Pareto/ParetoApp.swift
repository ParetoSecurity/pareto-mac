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

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBar: StatusBarController?
    var updater: AppUpdater?
    var updateWindow: NSWindow!

    func application(_: NSApplication, open urls: [URL]) {
        for url in urls {
            os_log("url:\(url)")
        }
    }

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
        doUpdateCheck()

        // Update when waking up from sleep
        NSWorkspace.onWakeup { _ in
            if Defaults[.runAfterSleep] {
                self.statusBar?.runChecks()
                self.doUpdateCheck()
            }
        }

        // Schedule hourly claim updates
        NSBackgroundActivityScheduler.repeating(withName: "ClaimRunner", withInterval: 60 * 60) { (completion: NSBackgroundActivityScheduler.CompletionHandler) in
            os_log("Running checks")
            self.statusBar?.runChecks()
            completion(.finished)
        }

        NSBackgroundActivityScheduler.repeating(withName: "UpdateRunner", withInterval: 60 * 60) { (completion: NSBackgroundActivityScheduler.CompletionHandler) in
            self.doUpdateCheck()
            completion(.finished)
        }
    }

    func doUpdateCheck() {
        if Defaults.shouldDoUpdateCheck() {
            os_log("Running update check")
            DispatchQueue.main.async { self.checkForRelease() }
            Defaults.doneUpdateCheck()
        }
    }

    func checkForRelease() {
        let currentVersion = Bundle.main.version
        if let release = try? updater!.getLatestRelease() {
            if currentVersion < release.version {
                if let zipURL = release.assets.filter({ $0.browser_download_url.path.hasSuffix(".zip") }).first {
                    let alert = NSAlert()
                    alert.messageText = "New version of Pareto Security \(release.version) is available"
                    alert.informativeText = release.body
                    alert.alertStyle = NSAlert.Style.informational
                    alert.addButton(withTitle: "Download")
                    alert.addButton(withTitle: "Skip")
                    if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
                        DispatchQueue.main.async {
                            let done = self.updater!.downloadAndUpdate(withAsset: zipURL)
                            if !done {
                                if let dmgURL = release.assets.filter({ $0.browser_download_url.path.hasSuffix(".dmg") }).first {
                                    NSWorkspace.shared.open(dmgURL.browser_download_url)
                                }
                            }
                        }
                    }
                }
            }
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
    }
}
