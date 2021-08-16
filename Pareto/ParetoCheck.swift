//
//  MenuItemCheck.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/07/2021.
//

import AppKit
import Combine
import Foundation
import os.log
import SwiftUI

class ParetoCheck: ObservableObject {
    private enum Snooze {
        static let oneHour = 3600
        static let oneDay = oneHour * 24
        static let oneWeek = oneDay * 7
    }

    private let cancellable: Cancellable
    private let defaults: UserDefaults
    public let UUID: String
    public let title: String
    public var canRunInSandbox = true

    let objectWillChange = PassthroughSubject<Void, Never>()

    var EnabledKey: String {
        UUID + "-Enabled"
    }

    var SnoozeKey: String {
        UUID + "-Snooze"
    }

    var PassesKey: String {
        UUID + "-Passes"
    }

    var TimestampKey: String {
        UUID + "-TS"
    }

    required init(id: String! = "", title: String! = "") {
        defaults = UserDefaults.standard
        UUID = id
        self.title = title

        defaults.register(defaults: [
            UUID + "-Enabled": true,
            UUID + "-Snooze": 0,
            UUID + "-Passes": false,
            UUID + "-TS": 0
        ])

        cancellable = NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification)
            .map { _ in () }
            .subscribe(objectWillChange)
    }

    var isActive: Bool {
        get { defaults.bool(forKey: EnabledKey) }
        set { defaults.set(newValue, forKey: EnabledKey) }
    }

    var snoozeTime: Int {
        get { defaults.integer(forKey: SnoozeKey) }
        set { defaults.set(newValue, forKey: SnoozeKey) }
    }

    var checkPassed: Bool {
        get { defaults.bool(forKey: PassesKey) }
        set { defaults.set(newValue, forKey: PassesKey) }
    }

    var checkTimestamp: Int {
        get { defaults.integer(forKey: TimestampKey) }
        set { defaults.set(newValue, forKey: TimestampKey) }
    }

    @objc func moreInfo() {
        if let url = URL(string: "https://paretosecurity.app/check/" + UUID) {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func disableCheck() {
        isActive = false
        checkPassed = false
        checkTimestamp = 0
    }

    @objc func enableCheck() {
        isActive = true
        checkPassed = false
        checkTimestamp = 0
    }

    @objc func snoozeOneHour() {
        snoozeTime = Snooze.oneHour
    }

    @objc func snoozeOneDay() {
        snoozeTime = Snooze.oneDay
    }

    @objc func snoozeOneWeek() {
        snoozeTime = Snooze.oneWeek
    }

    @objc func unsnooze() {
        snoozeTime = 0
    }

    func addSubmenu(withTitle: String, action: Selector?) -> NSMenuItem {
        let item = NSMenuItem(title: withTitle, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    func checkPasses() -> Bool {
        fatalError("checkPasses() is not implemented")
    }

    func menu() -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.setAccessibilityIdentifier("menu-\(UUID)")
        if isActive {
            if snoozeTime > 0 {
                item.image = NSImage.SF(name: "powersleep").tint(color: .systemGray)
            } else {
                if checkPassed {
                    item.image = NSImage.SF(name: "checkmark.shield").tint(color: .systemBlue)
                } else {
                    item.image = NSImage.SF(name: "exclamationmark.shield").tint(color: .systemRed)
                }
            }
        } else {
            item.image = NSImage.SF(name: "shield.slash")
        }

        let submenu = NSMenu()

        // submenu.addItem(addSubmenu(withTitle: "More Information", action: #selector(moreInfo)))
        submenu.addItem(addSubmenu(withTitle: "Last check: \(Date().fromTimeStamp(timeStamp: checkTimestamp))", action: nil))
        submenu.addItem(NSMenuItem.separator())
        if snoozeTime == 0 {
            submenu.addItem(addSubmenu(withTitle: "Snooze for 1 hour", action: #selector(snoozeOneHour)))
            submenu.addItem(addSubmenu(withTitle: "Snooze for 1 day", action: #selector(snoozeOneDay)))
            submenu.addItem(addSubmenu(withTitle: "Snooze for 1 week", action: #selector(snoozeOneWeek)))
        } else {
            if isActive {
                submenu.addItem(addSubmenu(withTitle: "Unsnooze", action: #selector(unsnooze)))
                submenu.addItem(addSubmenu(withTitle: "Resumes: \(Date().fromTimeStamp(timeStamp: checkTimestamp + (snoozeTime * 1000)))", action: nil))
            }
        }

        submenu.addItem(NSMenuItem.separator())
        if isActive {
            submenu.addItem(addSubmenu(withTitle: "Disable", action: #selector(disableCheck)))
        } else {
            submenu.addItem(addSubmenu(withTitle: "Enable", action: #selector(enableCheck)))
        }

        item.submenu = submenu
        return item
    }

    func run() {
        if !isActive {
            os_log("Disabled for %{public}s - %{public}s", log: Log.app, UUID, title)
            return
        }

        if snoozeTime != 0 {
            let nextCheck = checkTimestamp + (snoozeTime * 1000)
            let now = Int(Date().currentTimeMillis())
            if now >= nextCheck {
                os_log("Resetting snooze for %{public}s - %{public}s", log: Log.app, UUID, title)
                snoozeTime = 0
            } else {
                os_log("Snooze in effect for %{public}s - %{public}s", log: Log.app, UUID, title)
                return
            }
        }
        os_log("Running check for %{public}s - %{public}s", log: Log.app, UUID, title)
        checkPassed = checkPasses()
        checkTimestamp = Int(Date().currentTimeMillis())
    }
}

extension ParetoCheck {
    func runCMD(app: String, args: [String]) -> String {
        let task = Process()
        let pipe = Pipe()

        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = args
        task.launchPath = app
        task.launch()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)!
        return output
    }

    func readDefaults(app: String, key: String) -> String? {
        let output = runCMD(app: "/usr/bin/defaults", args: ["-currentHost", "read", app, key])
        return output.contains("does not exist") ? nil : output
    }

    func readDefaultsFile(path: String) -> NSDictionary? {
        guard let dictionary = NSDictionary(contentsOfFile: path) else {
            os_log("Failed reading %{public}s", path)
            return nil
        }
        // print("\(path): \(dictionary as AnyObject)")
        return dictionary
    }

    func runOSA(appleScript: String) -> String? {
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: appleScript) {
            if let outputString = scriptObject.executeAndReturnError(&error).stringValue {
                os_log("OSA: %{public}s", log: Log.check, type: .debug, outputString)
                return outputString
            } else if let error = error {
                os_log("Failed to execute script\n%{public}@", log: Log.check, type: .error, error.description)
            }
        }

        return nil
    }

    func appVersion(app: String) -> String? {
        let path = "/Applications/\(app).app/Contents/Info.plist"
        guard let dictionary = NSDictionary(contentsOfFile: path) else {
            os_log("Failed reading %{public}s", path)
            return nil
        }
        // print("\(app): \(dictionary as AnyObject)")
        return dictionary.value(forKey: "CFBundleShortVersionString") as? String
    }
}
