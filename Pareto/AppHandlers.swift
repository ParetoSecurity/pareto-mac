//
//  AppHandlers.swift
//  AppHandlers
//
//  Created by Janez Troha on 20/09/2021.
//

import Alamofire
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

        if !Defaults[.teamID].isEmpty {
            AppInfo.TeamSettings.update { os_log("Updated teams settings") }
        }

        if Defaults.firstLaunch() {
            #if !DEBUG
                LaunchAtLogin.isEnabled = true
            #endif
            NSApp.sendAction(#selector(showWelcome), to: nil, from: nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 300) {
                self.statusBar?.runChecks(isInteractive: false)
            }
        }

        #if !SETAPP_ENABLED
            // schedule update on startup
            if Defaults.shouldDoUpdateCheck() {
                os_log("Running update check from startup")
                DispatchQueue.global(qos: .userInteractive).async {
                    if Defaults.shouldDoUpdateCheck() {
                        if self.networkHandler.currentStatus == .satisfied {
                            os_log("Running update check from startup")
                            DispatchQueue.global(qos: .userInteractive).async {
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
            if Defaults[.disableChecksEvents] {
                os_log("disableChecksEvents, skip running checks")
                return
            }
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 300) {
                self.statusBar?.runChecks(isInteractive: false)
            }
            #if !SETAPP_ENABLED
                if Defaults.shouldDoUpdateCheck() {
                    if self.networkHandler.currentStatus == .satisfied {
                        os_log("Running update check from wakeup")
                        DispatchQueue.global(qos: .userInteractive).async {
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
            DispatchQueue.global(qos: .userInteractive).async {
                self.statusBar?.runChecks(isInteractive: false)
            }
            completion(.finished)
        }
        #if !SETAPP_ENABLED
            NSBackgroundActivityScheduler.repeating(withName: "UpdateRunner", withInterval: 60 * 60) { (completion: NSBackgroundActivityScheduler.CompletionHandler) in
                if Defaults.shouldDoUpdateCheck() {
                    if self.networkHandler.currentStatus == .satisfied {
                        os_log("Running update check")
                        DispatchQueue.global(qos: .userInteractive).async {
                            self.checkForRelease()
                            Defaults.doneUpdateCheck()
                        }
                    } else {
                        os_log("Skipping update check, no connection")
                    }
                }
                completion(.finished)
            }
        #else
            NSBackgroundActivityScheduler.repeating(withName: "UpdateRunnerSetapp", withInterval: 60 * 60 * Double(AppInfo.Flags.setappUpdate)) { (completion: NSBackgroundActivityScheduler.CompletionHandler) in

                if self.networkHandler.currentStatus == .satisfied {
                    os_log("Running update check")
                    DispatchQueue.main.async {
                        self.checkForRelease()
                    }
                } else {
                    os_log("Skipping update check, no connection")
                }

                completion(.finished)
            }
        #endif

        NSBackgroundActivityScheduler.repeating(withName: "FlagsRunner", withInterval: 60 * 5) { (completion: NSBackgroundActivityScheduler.CompletionHandler) in
            DispatchQueue.global(qos: .userInteractive).async {
                if self.networkHandler.currentStatus == .satisfied {
                    os_log("Running flags update")
                    AppInfo.Flags.update()
                } else {
                    os_log("Skipping flags update, no connection")
                }
            }
            completion(.finished)
        }
        NSBackgroundActivityScheduler.repeating(withName: "TeamsRunner", withInterval: 60 * 59) { (completion: NSBackgroundActivityScheduler.CompletionHandler) in
            DispatchQueue.global(qos: .userInteractive).async {
                if self.networkHandler.currentStatus == .satisfied {
                    if !Defaults[.teamID].isEmpty {
                        os_log("Running flags update")
                        AppInfo.TeamSettings.update {
                            os_log("Updated teams settings")
                        }
                    } else {
                        os_log("Skipping flags update, no team")
                    }
                } else {
                    os_log("Skipping flags update, no connection")
                }
            }
            completion(.finished)
        }
    }

    func statusDidChange(status: NWPath.Status) {
        if Defaults[.disableChecksEvents] {
            os_log("disableChecksEvents, skip running checks")
            return
        }

        if status == .satisfied {
            os_log("network condtions changed to: connected")
            // wait 30 second of stable connection before running checks
            DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 30) {
                self.statusBar?.runChecks(isInteractive: false)
            }
        } else {
            os_log("network conditions changed to: disconnected")
        }
    }

    func checkForRelease() {
        DispatchQueue.global(qos: .userInteractive).async { [self] in
            let currentVersion = Bundle.main.version
            if let release = try? updater!.getLatestRelease() {
                if currentVersion < release.version {
                    if !SystemUser.current.isAdmin {
                        Defaults[.updateNag] = true
                        return
                    }
                    #if !SETAPP_ENABLED
                        if let zipURL = release.assets.filter({ $0.browser_download_url.path.hasSuffix(".zip") }).first {
                            let done = updater!.downloadAndUpdate(withAsset: zipURL)
                            // Failed to update
                            if !done {
                                Defaults[.updateNag] = true
                            }
                        }
                    #endif
                }
            }
        }
    }

    @objc func doUpdate() {
        if #available(macOS 13.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showPrefs() {
        Defaults[.updateNag] = false
        if #available(macOS 13.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(self)
    }

    @objc func showMenu() {
        statusBar?.showMenu()
    }

    @objc func runChecksDelayed() {
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 2) {
            self.statusBar?.runChecks(isInteractive: false)
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
                DispatchQueue.global(qos: .userInteractive).async {
                    self.statusBar?.runChecks()
                }
            default:
                os_log("Unknown")
            }
        } else {
            DispatchQueue.global(qos: .userInteractive).async {
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

    func copyLogs() {
        NSPasteboard.general.clearContents()
        if let data = try? AppInfo.logEntries().joined(separator: "\n") {
            NSPasteboard.general.setString(data, forType: .string)
        }
        let alert = NSAlert()
        alert.messageText = "Logs have been copied to the clipboard."
        alert.alertStyle = NSAlert.Style.informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func copyDebug(_ onlyCheck: String) {
        var data = ""
        for claim in Claims.sorted {
            for check in claim.checksSorted.filter({ check in
                check.hasDebug || (!onlyCheck.isEmpty && check.hasDebug && check.UUID == onlyCheck)
            }) {
                data.append("Check \(check.Title):\n\(check.debugInfo())\n\n")
            }
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(data, forType: .string)
        let alert = NSAlert()
        alert.messageText = "Debug info has been copied to the clipboard."
        alert.alertStyle = NSAlert.Style.informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
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

    public func processAction(_ url: URL) {
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

                    // If we don't need to verify license return early
                    if license.role != "verify" {
                        return
                    }
                    let parameters: [String: String] = [
                        "uuid": license.uuid,
                        "machineUUID": Defaults[.machineUUID]
                    ]
                    let verifyURL = "https://dash.paretosecurity.com/api/v1/enroll/verify"
                    AF.request(verifyURL, method: .post, parameters: parameters, encoder: JSONParameterEncoder.default).responseString(queue: AppCheck.queue, completionHandler: { response in
                        if response.error == nil {
                            DispatchQueue.main.async {
                                let alert = NSAlert()
                                alert.messageText = "Pareto Security is now licensed."
                                alert.alertStyle = NSAlert.Style.informational
                                alert.addButton(withTitle: "OK")
                                #if !DEBUG
                                    alert.runModal()
                                #endif
                            }
                        } else {
                            Defaults.toFree()
                            DispatchQueue.main.async {
                                let alert = NSAlert()
                                alert.messageText = "No more licenses available for this account!"
                                alert.alertStyle = NSAlert.Style.critical
                                alert.addButton(withTitle: "OK")
                                #if !DEBUG
                                    alert.runModal()
                                #endif
                            }
                        }
                    })

                } catch {
                    Defaults.toFree()
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "License is not valid. Please email support@paretosecurity.com."
                        alert.alertStyle = NSAlert.Style.informational
                        alert.addButton(withTitle: "OK")
                        #if !DEBUG
                            alert.runModal()
                        #endif
                    }
                }

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

                    Team.link(withDevice: ReportingDevice.current()).response { response in
                        switch response.result {
                        case .success:
                            Defaults[.appliedIgnoredChecks] = false
                            DispatchQueue.main.async {
                                let alert = NSAlert()
                                alert.messageText = "Pareto Security is activated and linked."
                                alert.alertStyle = NSAlert.Style.informational
                                alert.addButton(withTitle: "OK")
                                #if !DEBUG
                                    alert.runModal()
                                #endif
                            }
                            if !Defaults.firstLaunch() {
                                DispatchQueue.global(qos: .userInteractive).async {
                                    self.statusBar?.runChecks()
                                }
                            }
                        case .failure:
                            Defaults.toFree()
                            DispatchQueue.main.async {
                                let alert = NSAlert()
                                alert.messageText = "Device has been linked already! Please unlink the device and try again!"
                                alert.alertStyle = NSAlert.Style.critical
                                alert.addButton(withTitle: "OK")
                                #if !DEBUG
                                    alert.runModal()
                                #endif
                            }
                        }
                    }

                } catch {
                    Defaults.toFree()
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "Team ticket is not valid. Please email support@paretosecurity.com."
                        alert.alertStyle = NSAlert.Style.informational
                        alert.addButton(withTitle: "OK")
                        #if !DEBUG
                            alert.runModal()
                        #endif
                    }
                }
        #endif
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
        case "debug":
            let check = url.queryParams()["check"] ?? ""
            copyDebug(check)
        case "logs":
            copyLogs()
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
