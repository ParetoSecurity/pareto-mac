//
//  ParetoApp.swift
//  Pareto
//
//  Created by Janez Troha on 12/07/2021.
//

import Defaults
import Foundation
import LaunchAtLogin
import os.log
import OSLog
import SwiftUI

class AppDelegate: AppHandlers, NSApplicationDelegate {
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
            processAction(url)
        }
    }

    func applicationDidFinishLaunching(_: Notification) {
        // Verify license
        do {
            switch Defaults[.reportingRole] {
            case .personal:
                _ = try VerifyLicense(withLicense: Defaults[.license])
                AppInfo.Licensed = true
            case .team:
                _ = try VerifyTeamTicket(withTicket: Defaults[.license])
                AppInfo.Licensed = true
            default:
                Defaults.toFree()
            }
        } catch {
            Defaults.toFree()
        }

        statusBar = StatusBarController()
        statusBar?.configureChecks()
        statusBar?.updateMenu()

        updater = AppUpdater(owner: "ParetoSecurity", repo: "pareto-mac")

        // stop running checks here and reset to defaults
        if AppInfo.isRunningTests {
            resetSettings()
            return
        }

        runApp()
    }
}

@main
struct Pareto: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(selected: SettingsView.Tabs.general)
        }
    }
}
