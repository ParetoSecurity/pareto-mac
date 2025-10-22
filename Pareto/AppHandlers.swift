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
import os
import os.log
import OSLog
import ServiceManagement
import SwiftUI

class AppHandlers: NSObject, ObservableObject, NetworkHandlerObserver {
    // Replaces StatusBarController model usage for MenuBarExtra/StatusBarIcon
    let statusBarModel = StatusBarModel()

    // Removed: var statusBar: StatusBarController?
    var updater: AppUpdater?
    var enrolledHandler = false
    var networkHandler = NetworkHandler.sharedInstance()
    private var idleSink: AnyCancellable?
    var finishedLaunch: Bool = false

    // Track the current running work item to prevent race conditions
    // Using OSAllocatedUnfairLock for better performance and cleaner syntax
    private let currentWorkItemID = OSAllocatedUnfairLock(initialState: 0)

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

        // Snooze in effect
        if Defaults[.snoozeTime] >= Date().currentTimeMs() {
            os_log("Checks are snoozed until %{public}ld", log: Log.app, Defaults[.snoozeTime])
            return
        } else {
            // snooze expired
            if Defaults[.snoozeTime] > 0 {
                os_log("Snooze expired %{public}ld", log: Log.app, Defaults[.snoozeTime])
            }
            Defaults[.snoozeTime] = 0
        }

        // don't run checks if not in interactive mode and it was ran less than 5 minutes ago
        if (Defaults[.lastCheck] + (60 * 1000 * 5)) >= Date().currentTimeMs(), !interactive {
            os_log("Debounce detected, last check %{public}ldms ago", log: Log.app, Date().currentTimeMs() - Defaults[.lastCheck])
            return
        }

        // Increment work item ID and capture it for this run (atomic operation)
        let workItemID = currentWorkItemID.withLock { value -> Int in
            value += 1
            return value
        }

        os_log("Starting check run with workItemID=%{public}d", log: Log.app, workItemID)

        // Set running first so the status line flips instantly
        setRunning(true)
        NotificationCenter.default.post(name: .runChecksStarted, object: nil)
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
        workItem.notify(queue: .main) { [weak self] in
            guard let self else { return }

            // Only update state if this is still the current work item
            let (isCurrentWorkItem, currentID) = self.currentWorkItemID.withLock { value in
                (workItemID == value, value)
            }

            if !isCurrentWorkItem {
                os_log("Ignoring completion of old workItemID=%{public}d (current=%{public}d)", log: Log.app, workItemID, currentID)
                return
            }

            os_log("Completing check run workItemID=%{public}d", log: Log.app, workItemID)
            self.setRunning(false)
            NotificationCenter.default.post(name: .runChecksFinished, object: nil)

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
                                os_log("Team status update failed: %{public}@", log: Log.app, err.localizedDescription)

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
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 90) { [weak self] in
            Task { @MainActor in
                guard let self else { return }

                // Only cancel if this work item is still current
                let isCurrentWorkItem = self.currentWorkItemID.withLock { $0 == workItemID }

                if self.statusBarModel.isRunning && isCurrentWorkItem {
                    workItem.cancel()
                    os_log("Checks took more than 90s to finish, cancelling workItemID=%{public}d", log: Log.app, workItemID)
                    self.setRunning(false)
                    NotificationCenter.default.post(name: .runChecksFinished, object: nil)
                }
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
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 300) {
                Task { @MainActor in
                    self.runChecks(isInteractive: false)
                }
            }
        }

        #if !SETAPP_ENABLED
            // schedule update on startup
            if Defaults.shouldDoUpdateCheck() {
                os_log("Running update check from startup")
                DispatchQueue.global(qos: .userInteractive).async {
                    if Defaults.shouldDoUpdateCheck() {
                        Task { @MainActor in
                            let isConnected = (self.networkHandler.currentStatus == .satisfied)
                            if isConnected {
                                os_log("Running update check from startup")
                                Task { @MainActor in
                                    self.checkForRelease()
                                    Defaults.doneUpdateCheck()
                                }
                            } else {
                                os_log("Skipping update check from startup, no connection")
                            }
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
                Task { @MainActor in
                    self.runChecks(isInteractive: false)
                }
            }
            #if !SETAPP_ENABLED
                if Defaults.shouldDoUpdateCheck() {
                    Task { @MainActor in
                        let isConnected = (self.networkHandler.currentStatus == .satisfied)
                        if isConnected {
                            os_log("Running update check from wakeup")
                            Task { @MainActor in
                                self.checkForRelease()
                                Defaults.doneUpdateCheck()
                            }
                        } else {
                            os_log("Skipping update check from wakeup, no connection")
                        }
                    }
                }
            #endif
        }

        // Schedule hourly claim updates
        NSBackgroundActivityScheduler.repeating(withName: "ClaimRunner", withInterval: 60 * 60) { (completion: NSBackgroundActivityScheduler.CompletionHandler) in
            os_log("Running checks")
            Task { @MainActor in
                self.runChecks(isInteractive: false)
            }
            completion(.finished)
        }
        #if !SETAPP_ENABLED
            NSBackgroundActivityScheduler.repeating(withName: "UpdateRunner", withInterval: 60 * 60) { (completion: NSBackgroundActivityScheduler.CompletionHandler) in
                if Defaults.shouldDoUpdateCheck() {
                    Task { @MainActor in
                        let isConnected = (self.networkHandler.currentStatus == .satisfied)
                        if isConnected {
                            os_log("Running update check")
                            Task { @MainActor in
                                self.checkForRelease()
                                Defaults.doneUpdateCheck()
                            }
                        } else {
                            os_log("Skipping update check, no connection")
                        }
                    }
                }
                completion(.finished)
            }
        #else
            NSBackgroundActivityScheduler.repeating(withName: "UpdateRunnerSetapp", withInterval: 60 * 60 * Double(AppInfo.Flags.setappUpdate)) { (completion: NSBackgroundActivityScheduler.CompletionHandler) in
                Task { @MainActor in
                    let isConnected = (self.networkHandler.currentStatus == .satisfied)
                    if isConnected {
                        os_log("Running update check")
                        DispatchQueue.main.async {
                            self.checkForRelease()
                        }
                    } else {
                        os_log("Skipping update check, no connection")
                    }
                }

                completion(.finished)
            }
        #endif

        NSBackgroundActivityScheduler.repeating(withName: "TeamsRunner", withInterval: 60 * 59) { (completion: NSBackgroundActivityScheduler.CompletionHandler) in
            DispatchQueue.global(qos: .userInteractive).async {
                Task { @MainActor in
                    let isConnected = (self.networkHandler.currentStatus == .satisfied)
                    if isConnected {
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
            }
            completion(.finished)
        }

        // Watchdog: Restart app if checks haven't run in 1 day
        NSBackgroundActivityScheduler.repeating(withName: "CheckWatchdog", withInterval: 60 * 60) { (completion: NSBackgroundActivityScheduler.CompletionHandler) in
            let threeDayMs: Int64 = 3 * 24 * 60 * 60 * 1000
            let lastCheck = Defaults[.lastCheck]

            // Only check if we've run checks before (lastCheck > 0)
            if lastCheck > 0 {
                let currentTime = Date().currentTimeMs()
                let timeSinceLastCheck = currentTime - lastCheck

                if timeSinceLastCheck >= threeDayMs {
                    os_log("WATCHDOG: Checks stale for %{public}ldms (>1 day), restarting app...", log: Log.app, type: .fault, timeSinceLastCheck)
                    Task { @MainActor in
                        self.restartApp()
                    }
                } else {
                    let hoursAgo = timeSinceLastCheck / (60 * 60 * 1000)
                    os_log("WATCHDOG: Checks healthy, last run %{public}ld hours ago", log: Log.app, hoursAgo)
                }
            } else {
                os_log("WATCHDOG: No checks run yet, skipping", log: Log.app)
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
                Task { @MainActor in
                    self.runChecks(isInteractive: false)
                }
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

        Task { @MainActor in
            self.doUpdateCheck()
        }
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(self)
    }

    func restartApp() {
        #if DEBUG
            os_log("Restart disabled in DEBUG mode", log: Log.app)
            return
        #endif

        guard !AppInfo.isRunningTests else {
            os_log("Restart disabled during tests", log: Log.app)
            return
        }

        guard let executableURL = Bundle.main.executableURL else {
            os_log("Cannot restart: missing executable URL", log: Log.app, type: .error)
            return
        }

        os_log("Restarting app due to stale checks (last check: %{public}ld)", log: Log.app, type: .fault, Defaults[.lastCheck])

        let proc = Process()
        proc.executableURL = executableURL
        proc.launch()

        DispatchQueue.main.async {
            NSApp.terminate(self)
        }
    }

    @objc func showMenu() {
        // No-op with MenuBarExtra; kept for compatibility if invoked from UI
    }

    @objc func runChecksDelayed() {
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 2) {
            Task { @MainActor in
                self.runChecks(isInteractive: false)
            }
        }
    }

    @objc func runChecks() {
        Task { @MainActor in
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
                            Task { @MainActor in
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
