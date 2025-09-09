//
//  AppHandlers.swift
//  AppHandlers
//
//  Created by Janez Troha on 20/09/2021.
//

import Alamofire
import Combine
import CoreGraphics
import Defaults
import Foundation
import LaunchAtLogin
import Network
import os.log
import OSLog
import ServiceManagement
import SwiftUI

class AppHandlers: NSObject, ObservableObject, NetworkHandlerObserver {
    // Replaces StatusBarController model usage for MenuBarExtra/StatusBarIcon
    let statusBarModel = StatusBarModel()

    // Removed: var statusBar: StatusBarController?
    var updater: AppUpdater?
    var welcomeWindow: NSWindowController?
    var preferencesWindow: NSWindowController?
    var enrolledHandler = false
    var networkHandler = NetworkHandler.sharedInstance()
    private var idleSink: AnyCancellable?
    var finishedLaunch: Bool = false

    @Default(.hideWhenNoFailures) var hideWhenNoFailures

    // With MenuBarExtra there is no NSStatusItem visibility to toggle.
    // Keep method for compatibility; adapt if you later bind MenuBarExtra(isInserted:) to a property.
    func updateHiddenState() {
        if hideWhenNoFailures {
            // Implement MenuBarExtra visibility binding here if desired.
            // e.g., isMenuBarInserted = !(claimsPassed)
        }
    }

    indirect enum Error: Swift.Error {
        case teamLinkinFailed
    }

    // New: configure all checks (replaces StatusBarController.configureChecks())
    func configureChecks() {
        for claim in Claims.global.all {
            claim.configure()
        }
    }

    // Ensure UI state changes occur on the main thread and immediately reflect in the menu
    private func setRunning(_ running: Bool) {
        let apply: () -> Void = {
            self.statusBarModel.isRunning = running
            // Show neutral/gray indicator while running
            if running {
                self.statusBarModel.state = .idle
            }
            self.statusBarModel.refreshNonce &+= 1
        }
        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.sync(execute: apply)
        }
    }

    // New: Snooze helpers (replaces StatusBarController snooze methods)
    @objc func snoozeOneHour() {
        Defaults[.snoozeTime] = Date().currentTimeMs() + 3600 * 1000
        // Update icon state if needed
        statusBarModel.state = .idle
    }

    @objc func snoozeOneDay() {
        Defaults[.snoozeTime] = Date().currentTimeMs() + 3600 * 24 * 1000
        statusBarModel.state = .idle
    }

    @objc func snoozeOneWeek() {
        Defaults[.snoozeTime] = Date().currentTimeMs() + 3600 * 24 * 7 * 1000
        statusBarModel.state = .idle
    }

    @objc func unsnooze() {
        Defaults[.snoozeTime] = 0
        // Recompute state on next run
    }

    // Ported run logic from StatusBarController.runChecks(isInteractive:)
    func runChecks(isInteractive interactive: Bool = true) {
        if statusBarModel.isRunning {
            return
        }

        // invalidate possible expired cache
        try? AppInfo.versionStorage.removeExpiredObjects()

        // Clear UpdateService cache when user manually runs checks
        if interactive {
            UpdateService.shared.clearCache()
        }

        // Snooze in effect
        if Defaults[.snoozeTime] >= Date().currentTimeMs() {
            os_log("Checks are snoozed until %s", log: Log.app, String(Defaults[.snoozeTime]))
            return
        } else {
            // snooze expired
            if Defaults[.snoozeTime] > 0 {
                os_log("Snooze expired %s", log: Log.app, String(Defaults[.snoozeTime]))
            }
            Defaults[.snoozeTime] = 0
        }

        // don't run checks if not in interactive mode and it was ran less than 5 minutes ago
        if (Defaults[.lastCheck] + (60 * 1000 * 5)) >= Date().currentTimeMs(), !interactive {
            os_log("Debounce detected, last check %sms ago", log: Log.app, String(Date().currentTimeMs() - Defaults[.lastCheck]))
            return
        }

        // Set running first so the status line flips instantly
        setRunning(true)
        // Then record the timestamp (this may trigger view refresh too, but isRunning already shows)
        Defaults[.lastCheck] = Date().currentTimeMs()

        // Update team configuration (blocking until done)
        if !Defaults[.teamID].isEmpty {
            let lock = DispatchSemaphore(value: 0)
            AppInfo.TeamSettings.update {
                os_log("Updated teams settings")
                lock.signal()
            }
            lock.wait()
        }

        // Run the checks
        let workItem = DispatchWorkItem {
            for claim in Claims.global.all {
                claim.run()
            }
        }

        // After checks finish
        workItem.notify(queue: .main) {
            self.setRunning(false)

            // Determine overall state
            let claimsPassed = Claims.global.all.allSatisfy { $0.checksPassed }
            Defaults[.checksPassed] = claimsPassed

            if Defaults[.snoozeTime] > 0 {
                self.statusBarModel.state = .idle
            } else {
                self.statusBarModel.state = claimsPassed ? .allOk : .warning
            }

            // Team reporting if enabled
            if Defaults[.reportingRole] == .team, AppInfo.Flags.teamAPI {
                if Defaults.shouldDoTeamUpdate() || interactive {
                    let report = Report.now()
                    if !Defaults[.sendHWInfo], AppInfo.TeamSettings.forceSerialPush, Defaults.shouldAskForHWAllow() {
                        DispatchQueue.main.async {
                            let alert = NSAlert()
                            alert.messageText = "Send device model and serial"
                            alert.informativeText = "Your team policy enables collection of serial number and hardware model name from this device. Do you allow it?"
                            alert.alertStyle = NSAlert.Style.warning
                            alert.addButton(withTitle: "OK")
                            alert.addButton(withTitle: "Don't Allow")
                            if alert.runModal() == .alertFirstButtonReturn {
                                Defaults[.sendHWInfo] = true
                                Defaults[.lastHWAsk] = Date().currentTimeMs()
                            } else {
                                Defaults[.sendHWInfo] = false
                                Defaults[.lastHWAsk] = Date().currentTimeMs()
                            }
                        }
                    }

                    DispatchQueue.global(qos: .userInteractive).async {
                        Team.update(withReport: report).response { response in
                            switch response.result {
                            case .success:
                                os_log("Team status was updated", log: Log.app)
                            case let .failure(err):
                                os_log("Team status update failed: %s", log: Log.app, err.localizedDescription)

                                // Check if the error is a 404 (device/team not found)
                                if let statusCode = response.response?.statusCode, statusCode == 404 {
                                    Team.showDeviceRemovedAlert()
                                    os_log("Device disconnected from Cloud. Got team update response with 404 error", log: Log.app)
                                }
                            }
                        }
                    }
                    Defaults.doneTeamUpdate()
                }
            }

            // Notify views observing Claims to refresh menu content and force a re-render
            Claims.global.objectWillChange.send()
            self.statusBarModel.refreshNonce &+= 1

            os_log("Checks finished running", log: Log.app)
        }

        // guard to prevent long running tasks
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 90) {
            if self.statusBarModel.isRunning {
                workItem.cancel()
                os_log("Checks took more than 30s to finish canceling", log: Log.app)
                self.setRunning(false)
            }
        }

        // run tasks
        DispatchQueue.global(qos: .userInteractive).async(execute: workItem)
        os_log("Running check scheduler", log: Log.app)
    }

    func runApp() {
        // Apply last saved state (if any) to the status icon immediately
        // so the app reflects the previous run before the next scheduled run.
        if Defaults[.lastCheck] > 0 {
            let claimsPassed = Claims.global.all.allSatisfy { $0.checksPassed }
            Defaults[.checksPassed] = claimsPassed
            if Defaults[.snoozeTime] > 0 {
                statusBarModel.state = .idle
            } else {
                statusBarModel.state = claimsPassed ? .allOk : .warning
            }
            // Nudge views that depend on this state
            statusBarModel.refreshNonce &+= 1
        }

        networkHandler.addObserver(observer: self)

        // When model goes idle, update hidden state if needed
        idleSink = statusBarModel.$state.sink { [weak self] state in
            guard let self else { return }
            if state == .idle {
                updateHiddenState()
            }
        }

        Task {
            for await hideWhenNoFailures in Defaults.updates(.hideWhenNoFailures) {
                if !hideWhenNoFailures {
                    // Always show MenuBarExtra if you add binding support later
                } else {
                    updateHiddenState()
                }
            }
        }

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
                self.runChecks(isInteractive: false)
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
                self.runChecks(isInteractive: false)
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
                self.runChecks(isInteractive: false)
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

        NSBackgroundActivityScheduler.repeating(withName: "TeamsRunner", withInterval: 60 * 59) { (completion: NSBackgroundActivityScheduler.CompletionHandler) in
            DispatchQueue.global(qos: .userInteractive).async {
                if self.networkHandler.currentStatus == .satisfied {
                    if !Defaults[.teamID].isEmpty {
                        os_log("Running team flags update")
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
                self.runChecks(isInteractive: false)
            }
        } else {
            os_log("network conditions changed to: disconnected")
        }
    }

    func doUpdateCheck() {
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
                        if !done, !SystemUser.current.isAdmin {
                            Defaults[.updateNag] = true
                        }
                    }
                #endif
            }
        }
    }

    func checkForRelease() {
        if !SystemUser.current.isAdmin {
            os_log("non-admin user cannot update the app")
            return
        }

        DispatchQueue.global(qos: .userInteractive).async { [self] in
            doUpdateCheck()
        }
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(self)
    }

    @objc func showMenu() {
        // No-op with MenuBarExtra; kept for compatibility if invoked from UI
    }

    @objc func runChecksDelayed() {
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 2) {
            self.runChecks(isInteractive: false)
        }
    }

    @objc func runChecks() {
        DispatchQueue.global(qos: .userInteractive).async {
            self.runChecks(isInteractive: true)
        }
    }

    @objc func reportBug() {
        NSWorkspace.shared.open(AppInfo.bugReportURL())
    }

    @objc func docs() {
        NSWorkspace.shared.open(AppInfo.docsURL())
    }

    @objc func teamsDashboard() {
        NSWorkspace.shared.open(AppInfo.teamsURL())
    }

    @MainActor
    @objc func showWelcome() {
        DispatchQueue.main.async { [self] in
            if welcomeWindow == nil {
                let hostingController = NSHostingController(rootView: WelcomeView())
                let welcomeSize = NSSize(width: 380, height: 520)
                hostingController.preferredContentSize = welcomeSize
                let window = NSWindow(contentViewController: hostingController)
                window.title = "Welcome"
                window.standardWindowButton(.zoomButton)?.isHidden = true
                window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                window.setContentSize(welcomeSize)
                window.contentMinSize = welcomeSize
                window.center()

                welcomeWindow = NSWindowController(window: window)
            }
            welcomeWindow!.showWindow(nil)
        }
    }

    func copyLogs() {
        if !SystemUser.current.isAdmin {
            let alert = NSAlert()
            alert.messageText = "Logs cannot be copied to the clipboard because you are using a non-admin account. Please use the Console app to capture the application logs by searching for \"Pareto Security\" and copying them to the clipboard."
            alert.informativeText = "Visit our guide at paretosecurity.com/docs/mac/logs for help."
            alert.alertStyle = NSAlert.Style.informational
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Open Guide")
            if alert.runModal() == NSApplication.ModalResponse.alertSecondButtonReturn {
                NSWorkspace.shared.open(URL(string: "https://paretosecurity.com/docs/mac/logs")!)
            }
        }

        if let data = try? AppInfo.logEntries().joined(separator: "\n") {
            if !data.isEmpty {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(data, forType: .string)
                let alert = NSAlert()
                alert.messageText = "Logs have been copied to the clipboard."
                alert.alertStyle = NSAlert.Style.informational
                alert.addButton(withTitle: "OK")
                alert.runModal()
                return
            }
        }

        let alert = NSAlert()
        alert.messageText = "Thre are no logs to copy. App logs are only available after the application has been running for a while."
        alert.alertStyle = NSAlert.Style.informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func copyDebug(_ onlyCheck: String) {
        var data = ""
        for claim in Claims.global.all {
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

    func processAction(_ url: URL) {
        switch url.host {
        #if !SETAPP_ENABLED
            case "linkDevice":
                let inviteID = url.queryParams()["invite_id"] ?? ""
                let host = url.queryParams()["host"] ?? ""

                // Set teamAPI based on host parameter
                if host.isEmpty {
                    Defaults[.teamAPI] = "https://cloud.paretosecurity.com"
                } else {
                    Defaults[.teamAPI] = host
                }

                if inviteID.isEmpty {
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "Invalid linking URL. Please use a valid invitation link."
                        alert.alertStyle = NSAlert.Style.critical
                        alert.addButton(withTitle: "OK")
                        #if !DEBUG
                            alert.runModal()
                        #endif
                    }
                    return
                }

                enrolledHandler = true

                Team.enrollDevice(inviteID: inviteID) { result in
                    switch result {
                    case .success(let (authToken, teamID)):
                        // Store the auth token and team ID directly
                        Defaults[.teamAuth] = authToken
                        Defaults[.teamID] = teamID
                        Defaults[.reportingRole] = .team
                        Defaults[.userID] = ""

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
                                self.runChecks()
                            }
                        }
                    case let .failure(error):
                        Defaults.toOpenSource()
                        DispatchQueue.main.async {
                            let alert = NSAlert()
                            alert.messageText = "Device linking failed: \(error.localizedDescription). Please email support@paretosecurity.com."
                            alert.alertStyle = NSAlert.Style.critical
                            alert.addButton(withTitle: "OK")
                            #if !DEBUG
                                alert.runModal()
                            #endif
                        }
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
