//
//  StatusBarController.swift
//  Pareto
//
//  Created by Janez Troha on 12/07/2021.
//

import AppKit
import Defaults
import os.log
import SwiftUI

#if SETAPP_ENABLED
    import Setapp
#endif

class StatusBarController: NSObject, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var statusItemMenu: NSMenu!
    var workItem: DispatchWorkItem?
    var statusBarModel = StatusBarModel()

    private enum Snooze {
        static let oneHour = 3600 * 1000
        static let oneDay = oneHour * 24
        static let oneWeek = oneDay * 7
    }

    public var snoozeTime: Int {
        get { Defaults[.snoozeTime] }
        set { Defaults[.snoozeTime] = newValue }
    }

    override
    init() {
        super.init()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItemMenu = NSMenu(title: "ParetoSecurity")
        statusItemMenu.delegate = self
        statusItem.menu = statusItemMenu
        let button: NSStatusBarButton = statusItem.button!
        let view = NSHostingView(rootView: StatusBarIcon(statusBarModel: statusBarModel))
        view.translatesAutoresizingMaskIntoConstraints = false
        button.setFrameSize(NSSize(width: 55, height: 32))
        button.addSubview(view)
        button.target = self
        button.isEnabled = true

        // Apply a series of Auto Layout constraints to its view:
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: button.topAnchor),
            view.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            view.widthAnchor.constraint(equalTo: button.widthAnchor),
            view.bottomAnchor.constraint(equalTo: button.bottomAnchor),
        ])

        if Defaults.firstLaunch() {
            showMenu()
        }
        statusItem.isVisible = true
    }

    var claimsPassed: Bool {
        var passed = true
        for claim in Claims.global.all {
            passed = passed && claim.checksPassed
        }
        return passed
    }

    func showMenu() {
        if let button = statusItem.button {
            _ = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                button.performClick(nil)
            }
        }
    }

    func updateMenu(partial: Bool = false) {
        DispatchQueue.main.async {
            if !partial {
                self.statusItemMenu.removeAllItems()
                if !self.statusBarModel.isRunning {
                    self.addChecksMenuItems()
                }
                self.addApplicationItems()
            }
            if self.snoozeTime > 0 {
                self.statusBarModel.state = .idle
            } else {
                if self.claimsPassed {
                    self.statusBarModel.state = .allOk
                } else {
                    self.statusBarModel.state = .warning
                }
            }
        }
    }

    func configureChecks() {
        for claim in Claims.global.all {
            claim.configure()
        }
    }

    func runChecks(isInteractive interactive: Bool = true) {
        if statusBarModel.isRunning {
            return
        }
        // invalidate possible expired cache
        try! AppInfo.versionStorage.removeExpiredObjects()

        // Snooze in effect
        if Defaults[.snoozeTime] >= Date().currentTimeMs() {
            os_log("Checks are snoozed until %s", log: Log.app, String(Defaults[.snoozeTime]))
            return
        } else {
            // snooze expired
            os_log("Snooze expired %s", log: Log.app, String(Defaults[.snoozeTime]))
            Defaults[.snoozeTime] = 0
        }

        // don't run checks if not in interactive mode and it was ran less than 5 minutes ago
        if (Defaults[.lastCheck] + (60 * 1000 * 5)) >= Date().currentTimeMs(), !interactive {
            os_log("Debounce detected, last check %sms ago", log: Log.app, String(Date().currentTimeMs() - Defaults[.lastCheck]))
            return
        }

        Defaults[.lastCheck] = Date().currentTimeMs()
        DispatchQueue.main.async {
            self.statusBarModel.isRunning = true
        }

        workItem = DispatchWorkItem {
            for claim in Claims.global.all {
                claim.run()
            }
        }

        // Update team configuration
        if !Defaults[.teamID].isEmpty {
            let lock = DispatchSemaphore(value: 0)
            AppInfo.TeamSettings.update {
                os_log("Updated teams settings")
                lock.signal()
            }
            lock.wait()
        }

        // update menus after checks have ran
        workItem?.notify(queue: .main) {
            self.statusBarModel.isRunning = false
            self.updateMenu()
            Defaults[.checksPassed] = self.claimsPassed

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
                            }
                        }
                    }
                    Defaults.doneTeamUpdate()
                }
            }

            os_log("Checks finished running", log: Log.app)
        }

        // guard to prevent long running tasks
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 90) {
            // checks are still running kill them
            if self.statusBarModel.isRunning {
                self.workItem?.cancel()
                os_log("Checks took more than 30s to finish canceling", log: Log.app)
            }
        }

        // run tasks
        DispatchQueue.global(qos: .userInteractive).async(execute: workItem!)
        os_log("Running check scheduler", log: Log.app)
    }

    func menuDidClose(_: NSMenu) {
        updateMenu(partial: true)
        #if SETAPP_ENABLED
            SetappManager.shared.reportUsageEvent(.userInteraction)
        #endif
    }

    func menuWillOpen(_: NSMenu) {
        updateMenu(partial: true)
        #if SETAPP_ENABLED
            SetappManager.shared.reportUsageEvent(.userInteraction)
        #endif
    }

    func addSubmenu(withTitle: String, action: Selector?) -> NSMenuItem {
        let item = NSMenuItem(title: withTitle, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc func snoozeOneHour() {
        snoozeTime = Date().currentTimeMs() + Snooze.oneHour
        updateMenu()
    }

    @objc func snoozeOneDay() {
        snoozeTime = Date().currentTimeMs() + Snooze.oneDay
        updateMenu()
    }

    @objc func snoozeOneWeek() {
        snoozeTime = Date().currentTimeMs() + Snooze.oneWeek
        updateMenu()
    }

    @objc func unsnooze() {
        snoozeTime = 0
        updateMenu()
    }

    func addApplicationItems() {
        if !statusBarModel.isRunning {
            if Defaults[.snoozeTime] == 0 {
                var title = "Last check \(Date.fromTimeStamp(timeStamp: Defaults[.lastCheck]).timeAgoDisplay())"
                if Defaults[.lastCheck] == 0 {
                    title = "Not checked yet"
                }
                let lastItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                lastItem.target = NSApp.delegate
                statusItemMenu.addItem(lastItem)
            } else {
                let lastItem = NSMenuItem(title: "Resumes \(Date.fromTimeStamp(timeStamp: snoozeTime).timeAgoDisplay())", action: nil, keyEquivalent: "")
                lastItem.target = NSApp.delegate
                statusItemMenu.addItem(lastItem)
            }
        } else {
            let lastItem = NSMenuItem(title: "Running checks ...", action: nil, keyEquivalent: "")
            lastItem.target = NSApp.delegate
            statusItemMenu.addItem(lastItem)
        }
        statusItemMenu.addItem(NSMenuItem.separator())
        if !statusBarModel.isRunning {
            if Defaults[.snoozeTime] == 0 {
                let runItem = NSMenuItem(title: "Run Checks", action: #selector(AppDelegate.runChecks), keyEquivalent: "r")
                runItem.target = NSApp.delegate
                statusItemMenu.addItem(runItem)

                let submenu = NSMenu()
                submenu.addItem(addSubmenu(withTitle: "for 1 hour", action: #selector(snoozeOneHour)))
                submenu.addItem(addSubmenu(withTitle: "for 1 day", action: #selector(snoozeOneDay)))
                submenu.addItem(addSubmenu(withTitle: "for 1 week", action: #selector(snoozeOneWeek)))

                let snoozeItem = NSMenuItem(title: "Snooze", action: nil, keyEquivalent: "")
                snoozeItem.submenu = submenu
                statusItemMenu.addItem(snoozeItem)
            } else {
                let unsnoozeItem = NSMenuItem(title: "Resume checks", action: #selector(unsnooze), keyEquivalent: "u")
                unsnoozeItem.target = self
                statusItemMenu.addItem(unsnoozeItem)
            }
        }
        #if !SETAPP_ENABLED
            if !Defaults[.teamID].isEmpty, Defaults[.isTeamOwner] {
                statusItemMenu.addItem(NSMenuItem.separator())
                let teamsItem = NSMenuItem(title: "Team Dashboard", action: #selector(AppDelegate.teamsDashboard), keyEquivalent: "t")
                teamsItem.target = NSApp.delegate
                statusItemMenu.addItem(teamsItem)
            }
        #endif
        let preferencesItem = NSMenuItem(title: "Preferences", action: #selector(AppDelegate.showPrefs), keyEquivalent: ",")
        preferencesItem.target = NSApp.delegate
        statusItemMenu.addItem(preferencesItem)

        let docsItem = NSMenuItem(title: "Documentation", action: #selector(AppDelegate.docs), keyEquivalent: "d")
        docsItem.target = NSApp.delegate
        statusItemMenu.addItem(docsItem)

        let reportItem = NSMenuItem(title: "Contact Support", action: #selector(AppDelegate.reportBug), keyEquivalent: "b")
        reportItem.target = NSApp.delegate
        statusItemMenu.addItem(reportItem)

        statusItemMenu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit Pareto", action: #selector(AppDelegate.quitApp), keyEquivalent: "q")
        quitItem.target = NSApp.delegate
        statusItemMenu.addItem(quitItem)
    }

    func addChecksMenuItems() {
        for claim in Claims.global.all {
            let menu = claim.menu()
            if !(menu.submenu?.items.isEmpty ?? false) {
                statusItemMenu.addItem(menu)
            }
        }
    }
}
