//
//  AppHandlers.swift
//  AppHandlers
//
//  Created by Janez Troha on 20/09/2021.
//

import Defaults
import Foundation
import LaunchAtLogin
import Network
import os.log
import OSLog
import ServiceManagement
import SwiftUI

#if !DEBUG
    import Sentry
#endif

class AppHandlers: NSObject, NetworkHandlerObserver {
    var statusBar: StatusBarController?
    var updater: AppUpdater?
    var welcomeWindow: NSWindow?
    var enrolledHandler = false
    var networkHandler = NetworkHandler.sharedInstance()

    public indirect enum Error: Swift.Error {
        case teamLinkinFailed
    }

    func runApp() {
        networkHandler.addObserver(observer: self)

        if Defaults.firstLaunch() {
            #if !DEBUG
                LaunchAtLogin.isEnabled = true
            #endif
            NSApp.sendAction(#selector(showWelcome), to: nil, from: nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                self.statusBar?.runChecks(isIteractive: false)
            }
        }

        #if !SETAPP_ENABLED
            // schedule update on startup
            if Defaults.shouldDoUpdateCheck() {
                os_log("Running update check from startup")
                DispatchQueue.main.async {
                    if Defaults.shouldDoUpdateCheck() {
                        if self.networkHandler.currentStatus == .satisfied {
                            os_log("Running update check from startup")
                            DispatchQueue.main.async {
                                self.checkForRelease()
                                Defaults.doneUpdateCheck()
                            }
                        } else {
                            os_log("Skipping update check from startup, no connection")
                        }
                    }
                    Defaults.doneUpdateCheck()
                }
            }
        #endif
        // Update when waking up from sleep
        NSWorkspace.onWakeup { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                self.statusBar?.runChecks(isIteractive: false)
            }
            #if !SETAPP_ENABLED
                if Defaults.shouldDoUpdateCheck() {
                    if self.networkHandler.currentStatus == .satisfied {
                        os_log("Running update check from wakeup")
                        DispatchQueue.main.async {
                            self.checkForRelease()
                            Defaults.doneUpdateCheck()
                        }
                    } else {
                        os_log("Skipping update check from wakeup, no connection")
                    }
                }
            #endif
        }

        // Schedule hourly claim updates
        NSBackgroundActivityScheduler.repeating(withName: "ClaimRunner", withInterval: 60 * 60) { (completion: NSBackgroundActivityScheduler.CompletionHandler) in
            os_log("Running checks")
            DispatchQueue.main.async {
                self.statusBar?.runChecks(isIteractive: false)
            }
            completion(.finished)
        }
        #if !SETAPP_ENABLED
            NSBackgroundActivityScheduler.repeating(withName: "UpdateRunner", withInterval: 60 * 60) { (completion: NSBackgroundActivityScheduler.CompletionHandler) in
                if Defaults.shouldDoUpdateCheck() {
                    if self.networkHandler.currentStatus == .satisfied {
                        os_log("Running update check")
                        DispatchQueue.main.async {
                            self.checkForRelease()
                            Defaults.doneUpdateCheck()
                        }
                    } else {
                        os_log("Skipping update check, no connection")
                    }
                }
                completion(.finished)
            }
        #endif

        NSBackgroundActivityScheduler.repeating(withName: "FlagsRunner", withInterval: 60 * 5) { (completion: NSBackgroundActivityScheduler.CompletionHandler) in
            DispatchQueue.main.async {
                if self.networkHandler.currentStatus == .satisfied {
                    os_log("Running flags update")
                    AppInfo.Flags.update()
                } else {
                    os_log("Skipping flags update, no connection")
                }
            }
            completion(.finished)
        }
    }

    func statusDidChange(status: NWPath.Status) {
        if status == .satisfied {
            os_log("network condtions changed to: connected")
            // wait 30 second of stable conenction before running checks
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                self.statusBar?.runChecks(isIteractive: false)
            }
        } else {
            os_log("network condtions changed to: disconnected")
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
                        Defaults[.updateNag] = true
                    }
                }
            }
        }
    }

    @objc func doUpdate() {
        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showPrefs() {
        Defaults[.updateNag] = false
        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(self)
    }

    @objc func showMenu() {
        statusBar?.showMenu()
    }

    @objc func runChecksDelayed() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.statusBar?.runChecks(isIteractive: false)
        }
    }

    @objc func runChecks() {
        if !Defaults.firstLaunch(), !AppInfo.Licensed, !enrolledHandler, Defaults.shouldShowNag() {
            Defaults.shownNag()
            let alert = NSAlert()
            alert.messageText = "You are running the free version of the app. Please consider purchasing the Personal lifetime license for unlimited devices."
            alert.alertStyle = NSAlert.Style.informational
            alert.addButton(withTitle: "Purchase")
            alert.addButton(withTitle: "Later")
            switch alert.runModal() {
            case NSApplication.ModalResponse.alertFirstButtonReturn:
                NSWorkspace.shared.open(URL(string: "https://paretosecurity.com/pricing")!)
            case NSApplication.ModalResponse.alertSecondButtonReturn:
                DispatchQueue.main.async {
                    self.statusBar?.runChecks()
                }
            default:
                os_log("Unknown")
            }
        } else {
            DispatchQueue.main.async {
                self.statusBar?.runChecks()
            }
        }
    }

    @objc func reportBug() {
        NSWorkspace.shared.open(AppInfo.bugReportURL())
    }

    @objc func teamsDasboard() {
        NSWorkspace.shared.open(AppInfo.teamsURL())
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
        Defaults[.showBeta] = true
    }

    func processAction(_ url: URL) {
        #if !DEBUG
            let crumb = Breadcrumb()
            crumb.level = SentryLevel.info
            crumb.category = "processAction"
            crumb.message = url.debugDescription
            SentrySDK.addBreadcrumb(crumb: crumb)
        #endif
        switch url.host {
        #if !SETAPP_ENABLED
            case "enrollSingle":
                let jwt = url.queryParams()["token"] ?? ""
                do {
                    let license = try VerifyLicense(withLicense: jwt)
                    enrolledHandler = true
                    Defaults[.license] = jwt
                    Defaults[.userEmail] = license.subject
                    Defaults[.userID] = license.uuid
                    AppInfo.Licensed = true
                    Defaults[.reportingRole] = .personal

                    let alert = NSAlert()
                    alert.messageText = "Pareto Security is now licensed."
                    alert.alertStyle = NSAlert.Style.informational
                    alert.addButton(withTitle: "OK")
                    #if !DEBUG
                        alert.runModal()
                    #endif
                } catch {
                    Defaults.toFree()
                    let alert = NSAlert()
                    alert.messageText = "License is not valid. Please email support@paretosecurity.com."
                    alert.alertStyle = NSAlert.Style.informational
                    alert.addButton(withTitle: "OK")
                    #if !DEBUG
                        alert.runModal()
                    #endif
                }
        #endif
        case "enrollTeam":
            if AppInfo.Licensed || !Defaults[.teamAuth].isEmpty {
                return
            }

            let jwt = url.queryParams()["token"] ?? ""
            do {
                let ticket = try VerifyTeamTicket(withTicket: jwt)
                enrolledHandler = true
                Defaults[.license] = jwt
                Defaults[.userID] = ""
                Defaults[.teamAuth] = ticket.teamAuth
                Defaults[.teamID] = ticket.teamUUID
                AppInfo.Licensed = true
                Defaults[.reportingRole] = .team
                Defaults[.isTeamOwner] = ticket.isTeamOwner

                Team.link(withDevice: ReportingDevice.current()).responseJSON { response in
                    debugPrint(response.result)
                    switch response.result {
                    case .success:
                        let alert = NSAlert()
                        alert.messageText = "Pareto Security is linked to your team."
                        alert.alertStyle = NSAlert.Style.informational
                        alert.addButton(withTitle: "OK")
                        #if !DEBUG
                            alert.runModal()
                        #endif
                        if !Defaults.firstLaunch() {
                            DispatchQueue.main.async {
                                self.statusBar?.runChecks()
                            }
                        }
                    case .failure:
                        Defaults.toFree()
                        let alert = NSAlert()
                        alert.messageText = "Device has been linked already! Please unlink the device from team and try again!"
                        alert.alertStyle = NSAlert.Style.critical
                        alert.addButton(withTitle: "OK")
                        #if !DEBUG
                            alert.runModal()
                        #endif
                    }
                }

            } catch {
                Defaults.toFree()
                let alert = NSAlert()
                alert.messageText = "Team ticket is not valid. Please email support@paretosecurity.com."
                alert.alertStyle = NSAlert.Style.informational
                alert.addButton(withTitle: "OK")
                #if !DEBUG
                    alert.runModal()
                #endif
            }
        case "reset":
            resetSettings()
            if !AppInfo.isRunningTests {
                NSApplication.shared.terminate(self)
            }
        case "showMenu":
            NSApp.sendAction(#selector(showMenu), to: nil, from: nil)
            NSApp.activate(ignoringOtherApps: true)
        case "welcome":
            NSApp.sendAction(#selector(showWelcome), to: nil, from: nil)
            NSApp.activate(ignoringOtherApps: true)
        case "runChecks":
            NSApp.sendAction(#selector(runChecks), to: nil, from: nil)
            NSApp.activate(ignoringOtherApps: true)
        case "showPrefs":
            NSApp.sendAction(#selector(showPrefs), to: nil, from: nil)
            NSApp.activate(ignoringOtherApps: true)
        case "showBeta":
            Defaults[.showBeta] = true
        #if !SETAPP_ENABLED
            case "update":
                checkForRelease()
        #endif
        default:
            os_log("Unknown command \(url)")
        }
    }
}
