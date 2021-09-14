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

    func application(_: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.host == "enroll" {
                Defaults[.license] = url.queryParams()["token"] ?? ""
            }
        }
    }

    #if !DEBUG
        func applicationWillFinishLaunching(_: Notification) {
            if !Bundle.main.path.string.hasPrefix("/Applications/") {
                let alert = NSAlert()
                alert.messageText = "Please install application by moving it into the Applications folder."
                alert.alertStyle = NSAlert.Style.critical
                alert.addButton(withTitle: "Close")
                alert.runModal()
                NSApplication.shared.terminate(self)
            }
        }
    #endif

    func applicationDidFinishLaunching(_: Notification) {
        statusBar = StatusBarController()
        statusBar?.configureChecks()
        statusBar?.updateMenu()
        Defaults[.updateRunning] = 0
        updater = AppUpdater(owner: "ParetoSecurity", repo: "pareto-mac")

        // stop running checks here and reset to defaults
        if AppInfo.isRunningTests {
            Defaults.removeAll()
            UserDefaults.standard.removeAll()
            UserDefaults.standard.synchronize()
            Defaults[.firstLaunch] = true
            return
        }
        statusBar?.runChecks()

        // Update when waking up from sleep
        NSWorkspace.onWakeup { _ in
            self.statusBar?.runChecks()
        }

        // Schedule hourly claim updates
        NSBackgroundActivityScheduler.repeating(withName: "ClaimRunner", withInterval: 60 * 60) { (completion: NSBackgroundActivityScheduler.CompletionHandler) in
            os_log("Running checks")
            self.statusBar?.runChecks()
            completion(.finished)
        }

        NSBackgroundActivityScheduler.repeating(withName: "UpdateRunner", withInterval: 60 * 60) { (completion: NSBackgroundActivityScheduler.CompletionHandler) in
            os_log("Running update checks")
            os_log("Doing checkForRelease \(Defaults[.updateRunning])")
            if Defaults[.updateRunning] > 0 {
                os_log("Skip checkForRelease Defaults[.updateRunning]=\(Defaults[.updateRunning])")
                return
            }
            if Defaults.shouldDoUpdateCheck() {
                os_log("Running update check")
                DispatchQueue.main.async { self.checkForRelease() }
                Defaults.doneUpdateCheck()
            }
            completion(.finished)
        }
    }

    func checkForRelease() {
        Defaults[.updateRunning] += 1
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
                    Defaults[.updateRunning] = 0
                    os_log("Defaults[.updateRunning] \(Defaults[.updateRunning])")
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
