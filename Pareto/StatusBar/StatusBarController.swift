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
            view.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])

        if Defaults.firstLaunch() {
            showMenu()
        }
    }

    var claimsPassed: Bool {
        var passed = true
        for claim in Claims.sorted {
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

    func updateMenu() {
        DispatchQueue.main.async {
            self.statusItemMenu.removeAllItems()
            if !self.statusBarModel.isRunning {
                self.addChecksMenuItems()
            }
            self.addApplicationItems()

            if self.claimsPassed {
                self.statusBarModel.state = .ok
            } else {
                self.statusBarModel.state = .warning
            }
        }
    }

    func configureChecks() {
        for claim in Claims.sorted {
            claim.configure()
        }
    }

    func runChecks(isIteractive interactive: Bool = true) {
        if statusBarModel.isRunning {
            return
        }

        // invalidate possible expired cache
        try! AppInfo.versionStorage.removeExpiredObjects()

        // Snooze in effect
        if Defaults[.snoozeTime] >= Date().currentTimeMillis() {
            os_log("Checks are snoozed until %s", log: Log.app, String(Defaults[.snoozeTime]))
            return
        } else {
            // snoze expired
            os_log("Snooze expired %s", log: Log.app, String(Defaults[.snoozeTime]))
            Defaults[.snoozeTime] = 0
        }

        // dont run chekcs if not in interactive mode and it was ran less than 5 mintues ago
        if (Defaults[.lastCheck] + (60 * 1000 * 5)) >= Date().currentTimeMillis(), !interactive {
            os_log("Debounce detected, last check %sms ago", log: Log.app, String(Date().currentTimeMillis() - Defaults[.lastCheck]))
            return
        }

        Defaults[.lastCheck] = Date().currentTimeMillis()
        DispatchQueue.main.sync {
            statusBarModel.state = .ok
        }

        DispatchQueue.main.sync {
            self.statusBarModel.isRunning = true
        }

        workItem = DispatchWorkItem {
            for claim in Claims.sorted {
                claim.run()
            }
        }

        // update menus after checks have ran
        workItem?.notify(queue: .main) {
            self.statusBarModel.isRunning = false
            self.updateMenu()
            Defaults[.checksPassed] = self.claimsPassed

            if Defaults[.reportingRole] == .team, AppInfo.Flags.teamAPI {
                if Defaults.shouldDoTeamUpdate() || interactive {
                    let report = Report.now()
                    DispatchQueue.global(qos: .utility).async {
                        Team.update(withReport: report).response { response in
                            switch response.result {
                            case .success:
                                os_log("Check status was updated", log: Log.app)
                            case let .failure(err):
                                os_log("Check status update failed: %s", log: Log.app, err.localizedDescription)
                            }
                        }
                    }
                    Defaults.doneTeamUpdate()
                }
            }

            os_log("Checks finished running", log: Log.app)
        }

        // guard to prevent long running tasks
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 30) {
            // checks are still running kill them
            if self.statusBarModel.isRunning {
                self.workItem?.cancel()
                os_log("Checks took more than 30s to finish canceling", log: Log.app)
            }
        }

        // run tasks
        DispatchQueue.global(qos: .background).async(execute: workItem!)
        os_log("Running check scheduler", log: Log.app)
    }

    func menuDidClose(_: NSMenu) {
        if claimsPassed {
            statusBarModel.state = .ok
        } else {
            statusBarModel.state = .warning
        }
    }

    func menuWillOpen(_: NSMenu) {
        updateMenu()
        #if SETAPP_ENABLED
            SCReportUsageEvent("user-interaction", nil)
        #endif
    }

    func addSubmenu(withTitle: String, action: Selector?) -> NSMenuItem {
        let item = NSMenuItem(title: withTitle, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc func snoozeOneHour() {
        snoozeTime = Date().currentTimeMillis() + Snooze.oneHour
        updateMenu()
    }

    @objc func snoozeOneDay() {
        snoozeTime = Date().currentTimeMillis() + Snooze.oneDay
        updateMenu()
    }

    @objc func snoozeOneWeek() {
        snoozeTime = Date().currentTimeMillis() + Snooze.oneWeek
        updateMenu()
    }

    @objc func unsnooze() {
        snoozeTime = 0
        updateMenu()
    }

    func addApplicationItems() {
        if !statusBarModel.isRunning {
            if Defaults[.snoozeTime] == 0 {
                let lastItem = NSMenuItem(title: "Last check \(Date.fromTimeStamp(timeStamp: Defaults[.lastCheck]).timeAgoDisplay())", action: nil, keyEquivalent: "")
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

        if (!Defaults[.teamID].isEmpty && AppInfo.Flags.dashboardMenu) || Defaults[.isTeamOwner] {
            statusItemMenu.addItem(NSMenuItem.separator())
            let teamsItem = NSMenuItem(title: "Team Dashboard", action: #selector(AppDelegate.teamsDasboard), keyEquivalent: "t")
            teamsItem.target = NSApp.delegate
            statusItemMenu.addItem(teamsItem)
        }

        let preferencesItem = NSMenuItem(title: "Preferences", action: #selector(AppDelegate.showPrefs), keyEquivalent: ",")
        preferencesItem.target = NSApp.delegate
        statusItemMenu.addItem(preferencesItem)

        if Defaults[.updateNag] {
            let updateItem = NSMenuItem(title: "Update to latest version", action: #selector(AppDelegate.doUpdate), keyEquivalent: "u")
            updateItem.target = NSApp.delegate
            statusItemMenu.addItem(updateItem)
        }

        let reportItem = NSMenuItem(title: "Report a Bug", action: #selector(AppDelegate.reportBug), keyEquivalent: "b")
        reportItem.target = NSApp.delegate
        statusItemMenu.addItem(reportItem)

        statusItemMenu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit Pareto", action: #selector(AppDelegate.quitApp), keyEquivalent: "q")
        quitItem.target = NSApp.delegate
        statusItemMenu.addItem(quitItem)
    }

    func addChecksMenuItems() {
        for claim in Claims.sorted {
            let menu = claim.menu()
            if !(menu.submenu?.items.isEmpty ?? false) {
                statusItemMenu.addItem(menu)
            }
        }
    }
}
