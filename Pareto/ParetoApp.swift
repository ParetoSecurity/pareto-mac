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
    var welcomeWindow: NSWindow?

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

    func application(_: NSApplication, open urls: [URL]) {
        for url in urls {
            switch url.host {
            case "reset":
                resetSettings()
                NSApplication.shared.terminate(self)
            case "showMenu":
                NSApp.sendAction(#selector(showMenu), to: nil, from: nil)
                NSApp.activate(ignoringOtherApps: true)
            case "welcome":
                NSApp.sendAction(#selector(showWelcome), to: nil, from: nil)
                NSApp.activate(ignoringOtherApps: true)
            case "update":
                checkForRelease()
            default:
                os_log("Unknown command \(url)")
            }
        }
    }

    func applicationDidFinishLaunching(_: Notification) {
        statusBar = StatusBarController()
        statusBar?.configureChecks()
        statusBar?.updateMenu()

        updater = AppUpdater(owner: "ParetoSecurity", repo: "pareto-mac")

        // stop running checks here and reset to defaults
        if AppInfo.isRunningTests {
            Defaults.removeAll()
            UserDefaults.standard.removeAll()
            UserDefaults.standard.synchronize()
            return
        }

        if Defaults.firstLaunch() {
            NSApp.sendAction(#selector(showWelcome), to: nil, from: nil)
            NSApp.activate(ignoringOtherApps: true)
            Timer.scheduledTimer(timeInterval: 2.0, target: self, selector: #selector(runChecks), userInfo: nil, repeats: false)
        } else {
            Timer.scheduledTimer(timeInterval: 2.0, target: self, selector: #selector(runChecks), userInfo: nil, repeats: false)
        }

        // schedule update on startup
        if Defaults.shouldDoUpdateCheck() {
            os_log("Running update check from startup")
            DispatchQueue.main.async {
                self.checkForRelease()
                Defaults.doneUpdateCheck()
            }
        }
        // Update when waking up from sleep
        NSWorkspace.onWakeup { _ in
            self.statusBar?.runChecks()
            if Defaults.shouldDoUpdateCheck() {
                os_log("Running update check from wakeup")
                DispatchQueue.main.async {
                    self.checkForRelease()
                    Defaults.doneUpdateCheck()
                }
            }
        }

        // Schedule hourly claim updates
        NSBackgroundActivityScheduler.repeating(withName: "ClaimRunner", withInterval: 60 * 60) { (completion: NSBackgroundActivityScheduler.CompletionHandler) in
            os_log("Running checks")
            DispatchQueue.main.async {
                self.statusBar?.runChecks()
            }
            completion(.finished)
        }

        NSBackgroundActivityScheduler.repeating(withName: "UpdateRunner", withInterval: 60 * 60) { (completion: NSBackgroundActivityScheduler.CompletionHandler) in
            if Defaults.shouldDoUpdateCheck() {
                os_log("Running update check")
                DispatchQueue.main.async {
                    self.checkForRelease()
                    Defaults.doneUpdateCheck()
                }
            }
            completion(.finished)
        }
    }

    func checkForRelease() {
        let currentVersion = Bundle.main.version
        if let release = try? updater!.getLatestRelease() {
            if currentVersion < release.version {
                if let zipURL = release.assets.filter({ $0.browser_download_url.path.hasSuffix(".zip") }).first {
                    let done = updater!.downloadAndUpdate(withAsset: zipURL)
                    // Failed to update
                    if !done {
                        if let dmgURL = release.assets.filter({ $0.browser_download_url.path.hasSuffix(".dmg") }).first {
                            let alert = NSAlert()
                            alert.messageText = "New version of Pareto Security \(release.version) is available"
                            alert.informativeText = release.body
                            alert.alertStyle = NSAlert.Style.informational
                            alert.addButton(withTitle: "Download")
                            if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
                                NSWorkspace.shared.open(dmgURL.browser_download_url)
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
        DispatchQueue.main.async {
            self.statusBar?.runChecks()
        }
    }

    @objc func showMenu() {
        statusBar?.showMenu()
    }

    @objc func reportBug() {
        NSWorkspace.shared.open(AppInfo.bugReportURL())
    }

    @objc func showWelcome() {
        if welcomeWindow == nil {
            let welcome = WelcomeView()
            // Create the preferences window and set content
            welcomeWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
                styleMask: [.closable, .titled],
                backing: .buffered,
                defer: false
            )
            welcomeWindow!.titlebarAppearsTransparent = true
            welcomeWindow!.center()
            welcomeWindow!.setFrameAutosaveName("welcomeView")
            welcomeWindow!.isReleasedWhenClosed = false
            let hosting = NSHostingView(rootView: welcome)
            hosting.autoresizingMask = [NSView.AutoresizingMask.width, NSView.AutoresizingMask.height]
            welcomeWindow!.contentView = hosting
        }

        welcomeWindow!.makeKeyAndOrderFront(nil)
    }

    func resetSettings() {
        Defaults.removeAll()
        UserDefaults.standard.removeAll()
        UserDefaults.standard.synchronize()
    }

    @objc func resetSettingsClick() {
        resetSettings()
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
