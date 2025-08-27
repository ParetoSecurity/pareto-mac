//
//  ParetoApp.swift
//  Pareto
//
//  Created by Janez Troha on 12/07/2021.
//

import Cocoa
import Defaults
import Foundation
import LaunchAtLogin
import os.log
import OSLog
import SettingsAccess
import SwiftUI

class AppDelegate: AppHandlers, NSApplicationDelegate {
    func applicationDidBecomeActive(_: Notification) {
        if hideWhenNoFailures {
            statusBar?.statusItem?.isVisible = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [self] in
                if statusBar?.statusBarModel.state == .idle {
                    updateHiddenState()
                }
            }
        }
    }

    func moveToApplicationsFolderIfNeeded() {
        let fileManager = FileManager.default
        let bundlePath = Bundle.main.bundlePath
        let destinationPath = "/Applications/\(bundlePath.components(separatedBy: "/").last!)"

        // Ensure that the destination does not already exist
        if fileManager.fileExists(atPath: destinationPath) {
            try? fileManager.removeItem(atPath: destinationPath)
        }

        do {
            try fileManager.moveItem(atPath: bundlePath, toPath: destinationPath)
            print("Moved app to /Applications")
            AppUpdater.clearExtendedAttributes(at: destinationPath)

        } catch {
            print("Failed to move the app: \(error)")
        }
        exit(0) // Terminate old instance
    }

    func applicationWillFinishLaunching(_: Notification) {
        if CommandLine.arguments.contains("-export") {
            var export: [String: [String: [String]]] = [:]

            for claim in Claims.global.all {
                // skip empty claims
                if claim.checks.count == 0 {
                    continue
                }
                var claimExport: [String: [String]] = [:]
                for check in claim.checksSorted {
                    claimExport[check.UUID] = [check.TitleON, check.TitleOFF]
                }
                export[claim.title] = claimExport
            }

            let jsonEncoder = JSONEncoder()
            let jsonData = try! jsonEncoder.encode(export)
            let json = String(data: jsonData, encoding: String.Encoding.utf8)
            print(json! as String)
            exit(0)
        }

        if CommandLine.arguments.contains("-update") {
            moveToApplicationsFolderIfNeeded()
        }

        if CommandLine.arguments.contains("-report") {
            // invalidate possible expired cache
            try! AppInfo.versionStorage.removeAll()

            for claim in Claims.global.all {
                claim.configure()
                for check in claim.checksSorted {
                    check.run()
                    print(check.report + "\n")
                }
            }
            exit(0)
        }
        if CommandLine.arguments.contains("-report-json") {
            // invalidate possible expired cache
            try! AppInfo.versionStorage.removeAll()
            print("[")
            for claim in Claims.global.all {
                claim.configure()
                for check in claim.checksSorted {
                    check.run()
                    print(check.reportJSON + ",\n")
                }
            }
            print("]")
            exit(0)
        }

        if CommandLine.arguments.contains("-mdmTeam") {
            if !Defaults[.teamAuth].isEmpty {
                print("Team license already active")
                exit(0)
            }

            var inviteParam = CommandLine.arguments.last ?? ""

            if inviteParam.isEmpty {
                print("Missing team invite parameter")
                exit(0)
            }

            var inviteID = ""
            if inviteParam.starts(with: "paretosecurity://") {
                let url = URL(string: inviteParam)!
                inviteID = url.queryParams()["invite_id"] ?? ""

                if inviteID.isEmpty {
                    print("Missing invite_id parameter in URL")
                    exit(0)
                }
            } else {
                // Assume the parameter is the invite ID directly
                inviteID = inviteParam
            }

            print("Enrolling device with invite ID")
            enrolledHandler = true

            Team.enrollDevice(inviteID: inviteID) { result in
                switch result {
                case .success(let (authToken, teamID)):
                    Defaults[.teamAuth] = authToken
                    Defaults[.teamID] = teamID
                    Defaults[.reportingRole] = .team
                    Defaults[.userID] = ""
                    LaunchAtLogin.isEnabled = true

                    print("Device successfully enrolled and linked to team: \(teamID)")
                    Defaults[.lastCheck] = 1
                    exit(0)
                case let .failure(error):
                    print("Device enrollment failed: \(error.localizedDescription)")
                    Defaults.toOpenSource()
                    exit(1)
                }
            }
        }
    }

    func application(_: NSApplication, open urls: [URL]) {
        for url in urls {
            processAction(url)
        }
    }

    func applicationDidFinishLaunching(_: Notification) {
        #if DEBUG
            // disable any other code if in preview mode
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                return
            }

        #endif

        // Terminate any older versions of process if not running tests
        #if !DEBUG
            if !AppInfo.isRunningTests {
                let procs = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier!)
                if procs.count > 1 {
                    procs.first?.forceTerminate()
                }
            }
        #endif

        // Team ticket migration removed - no longer needed with new enrollment approach
        statusBar = StatusBarController()

        statusBar?.configureChecks()
        statusBar?.updateMenu()

        #if DEBUG
            // don't do anything else if running tests
            if AppInfo.isRunningTests {
                return
            }
        #endif

        updater = AppUpdater(owner: "ParetoSecurity", repo: "pareto-mac")

        runApp()
    }
}

@main
struct Pareto: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openSettings) private var openSettings

    var body: some Scene {
        Settings {
            SettingsView(selected: SettingsView.Tabs.general)
        }
    }
}
