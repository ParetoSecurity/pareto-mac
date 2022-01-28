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
#if !DEBUG
    import Sentry
#endif
import SwiftUI
import UserNotifications

class AppDelegate: AppHandlers, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        // Get the meeting ID from the original notification.
        let userInfo = response.notification.request.content.userInfo

        if response.notification.request.content.categoryIdentifier ==
            NotificationType.Check.rawValue {
            // Retrieve the meeting details.
            let checkID = userInfo["CHECK_ID"] as! String

            switch response.actionIdentifier {
            case NotificationAction.MoreInfo.rawValue:
                print(checkID)

            case UNNotificationDefaultActionIdentifier,
                 UNNotificationDismissActionIdentifier:
                break

            default:
                break
            }
        }
    }

    func applicationWillFinishLaunching(_: Notification) {
        if CommandLine.arguments.contains("-export") {
            var export: [String: [String: [String]]] = [:]

            for claim in Claims.sorted {
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

        if CommandLine.arguments.contains("-report") {
            // invalidate possible expired cache
            try! AppInfo.versionStorage.removeAll()

            for claim in Claims.sorted {
                for check in claim.checksSorted {
                    claim.configure()
                    print(check.report + "\n")
                }
            }
            for line in AppInfo.logEntries() {
                print(line)
            }
            exit(0)
        }

        if CommandLine.arguments.contains("-mdmTeam") {
            if !Defaults[.license].isEmpty {
                print("Team license already active")
                exit(0)
            }

            var token = CommandLine.arguments.last ?? ""

            if token.isEmpty {
                print("Missing team license parameter")
                exit(0)
            }

            if token.starts(with: "paretosecurity://") {
                let url = URL(string: token)!
                token = url.queryParams()["token"] ?? ""

                if token.isEmpty {
                    print("Missing team license token parameter")
                    exit(0)
                }
            }

            do {
                let ticket = try VerifyTeamTicket(withTicket: token)
                enrolledHandler = true
                Defaults[.license] = token
                Defaults[.userID] = ""
                Defaults[.teamAuth] = ticket.teamAuth
                Defaults[.teamID] = ticket.teamUUID
                AppInfo.Licensed = true
                Defaults[.reportingRole] = .team
                Defaults[.isTeamOwner] = ticket.isTeamOwner
                LaunchAtLogin.isEnabled = true

                print("Team ticket subscribing")
                Team.link(withDevice: ReportingDevice.current()).response { response in
                    switch response.result {
                    case .success:
                        print("Team ticket is linked")
                        Defaults[.lastCheck] = 1
                        exit(0)
                    case .failure:
                        print("Team ticket could not be linked")
                        Defaults.toFree()
                        exit(1)
                    }
                    exit(0)
                }
            } catch {
                print("Team ticket is not valid")
                Defaults.toFree()
                exit(1)
            }
        }

        #if !DEBUG
            #if !SETAPP_ENABLED
                if !Bundle.main.path.string.hasPrefix("/Applications/") {
                    let alert = NSAlert()
                    alert.messageText = "Please install application by moving it into the Applications folder."
                    alert.alertStyle = NSAlert.Style.critical
                    alert.addButton(withTitle: "Close")
                    alert.runModal()
                    NSApplication.shared.terminate(self)
                }
            #endif
        #endif
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
                SentrySDK.start { options in
                    options.dsn = "https://9caf590fe06b4f5b940adfb59623d457@o32789.ingest.sentry.io/6013471"
                    options.enableAutoSessionTracking = true
                    options.enableAutoPerformanceTracking = true
                    options.tracesSampleRate = 1.0

                    let user = User()
                    user.userId = Defaults[.machineUUID]
                    SentrySDK.setUser(user)
                }
                let procs = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier!)
                if procs.count > 1 {
                    procs.first?.forceTerminate()
                }
            }
        #endif

        // Verify license
        #if !SETAPP_ENABLED
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
        #else
            AppInfo.Licensed = true
        #endif

        statusBar = StatusBarController()
        statusBar?.configureChecks()
        statusBar?.updateMenu()
        updater = AppUpdater(owner: "ParetoSecurity", repo: "pareto-mac")

        // don't do anything else if running tests
        if AppInfo.isRunningTests {
            return
        }

        runApp()

        if Defaults[.showNotifications] {
            registerNotifications()
        }
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
