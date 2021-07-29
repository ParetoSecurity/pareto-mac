//
//  ParetoApp.swift
//  Pareto
//
//  Created by Janez Troha on 12/07/2021.
//

import AppUpdater
import Foundation
import os.log
import OSLog
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBar: StatusBarController?
    let updater = AppUpdater(owner: "ParetoSecurity", repo: "pareto-mac")
    let userSettings = UserSettings()

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
                                                              if self.userSettings.runAfterSleep {
                                                                  self.statusBar?.runChecks()
                                                              }
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

    @objc func reportBug() {
        if #available(macOS 12.0, *) {
            let logs = getLogEntries().joined(separator: "\n").addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
            if let url = URL(string: "https://github.com/ParetoSecurity/pareto-mac/issues/new?assignees=dz0ny&labels=bug%2Ctriage&template=report_bug.yml&title=%5BBug%5D%3A+&logs="+logs!) {
                NSWorkspace.shared.open(url)
            }
        } else {
            if let url = URL(string: "https://github.com/ParetoSecurity/pareto-mac/issues/new?assignees=dz0ny&labels=bug%2Ctriage&template=report_bug.yml&title=%5BBug%5D%3A+") {
                NSWorkspace.shared.open(url)
            }
        }

    }
    
    @available(macOS 12.0, *)
    func getLogEntries() -> [String] {
        var logs = [String]()
        do {
            let logStore = try OSLogStore(scope: .currentProcessIdentifier)
            let enumerator = try logStore.__entriesEnumerator(position: nil, predicate: nil)
            let allEntries = Array(enumerator)
            let osLogEntryObjects = allEntries.compactMap { $0 as? OSLogEntry }
            let osLogEntryLogObjects = osLogEntryObjects.compactMap { $0 as? OSLogEntryLog }
            let subsystem = Bundle.main.bundleIdentifier!
            for entry in osLogEntryLogObjects where entry.subsystem == subsystem {
                logs.append(entry.category+": "+entry.composedMessage)
            }
        } catch {
            logs.append("Error: \(error)")
        }
        return logs
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
