//
//  ParetoApp.swift
//  Pareto
//
//  Created by Janez Troha on 12/07/2021.
//

import Foundation
import os.log
import OSLog
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBar: StatusBarController?
    let userSettings = UserSettings()

    func applicationDidFinishLaunching(_: Notification) {
        // Don't init app if running unit tests
        if AppInfo.isRunningTests {
            return
        }

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
            let versions = getVersions().addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
            if let url = URL(string: "https://github.com/ParetoSecurity/pareto-mac/issues/new?labels=bug%2Ctriage&template=report_bug.yml&title=%5BBug%5D%3A+&logs=" + logs! + "&version=" + versions!) {
                NSWorkspace.shared.open(url)
            }
        } else {
            let versions = getVersions().addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
            if let url = URL(string: "https://github.com/ParetoSecurity/pareto-mac/issues/new?labels=bug%2Ctriage&template=report_bug.yml&title=%5BBug%5D%3A+&version=" + versions!) {
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
                logs.append(entry.category + ": " + entry.composedMessage)
            }
        } catch {
            logs.append("Error: \(error)")
        }
        return logs
    }

    func getVersions() -> String {
        return "HW: \(AppInfo.hwModel())\nmacOS: \(AppInfo.osVersion)\nApp Version: \(AppInfo.appVersion)\nBuild: \(AppInfo.buildVersion)"
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

enum AppInfo {
    static let appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
    static let buildVersion: String = Bundle.main.infoDictionary?["CFBundleVersion"] as! String
    static let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
    static let inSandbox = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    static let isRunningTests = UserDefaults.standard.bool(forKey: "isRunningTests")

    static let hwModel = { () -> String in
        let service = IOServiceGetMatchingService(kIOMasterPortDefault,
                                                  IOServiceMatching("IOPlatformExpertDevice"))
        var modelIdentifier: String?
        if let modelData = IORegistryEntryCreateCFProperty(service, "model" as CFString, kCFAllocatorDefault, 0).takeRetainedValue() as? Data {
            modelIdentifier = String(data: modelData, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters)
        }

        IOObjectRelease(service)
        return modelIdentifier!
    }
}
