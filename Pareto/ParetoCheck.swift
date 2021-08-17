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
    private(set) var UUID = "UUID"
    private(set) var Title = "Title"

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

    init() {
        UserDefaults.standard.register(defaults: [
            UUID + "-Enabled": true,
            UUID + "-Snooze": 0,
            UUID + "-Passes": false,
            UUID + "-TS": 0
        ])
    }

    public var isActive: Bool {
        get { UserDefaults.standard.bool(forKey: EnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: EnabledKey) }
    }

    public var snoozeTime: Int {
        get { UserDefaults.standard.integer(forKey: SnoozeKey) }
        set { UserDefaults.standard.set(newValue, forKey: SnoozeKey) }
    }

    var checkTimestamp: Int {
        get { UserDefaults.standard.integer(forKey: TimestampKey) }
        set { UserDefaults.standard.set(newValue, forKey: TimestampKey) }
    }

    var checkPassed: Bool {
        get { UserDefaults.standard.bool(forKey: PassesKey) }
        set { UserDefaults.standard.set(newValue, forKey: PassesKey) }
    }

    func checkPasses() -> Bool {
        fatalError("checkPasses() is not implemented")
    }

    func menu() -> NSMenuItem {
        let item = NSMenuItem(title: Title, action: #selector(moreInfo), keyEquivalent: "")
        item.target = self
        if isActive {
            if snoozeTime > 0 {
                item.image = NSImage.SF(name: "powersleep").tint(color: .systemGray)
            } else {
                if checkPassed {
                    item.image = NSImage.SF(name: "checkmark").tint(color: .systemBlue)
                } else {
                    item.image = NSImage.SF(name: "exclamationmark").tint(color: .systemRed)
                }
            }
        } else {
            item.image = NSImage.SF(name: "shield.slash")
        }

        return item
    }

    func run() {
        if !isActive {
            os_log("Disabled for %{public}s - %{public}s", log: Log.app, UUID, Title)
            return
        }

        if snoozeTime != 0 {
            let nextCheck = checkTimestamp + (snoozeTime * 1000)
            let now = Int(Date().currentTimeMillis())
            if now >= nextCheck {
                os_log("Resetting snooze for %{public}s - %{public}s", log: Log.app, UUID, Title)
                snoozeTime = 0
            } else {
                os_log("Snooze in effect for %{public}s - %{public}s", log: Log.app, UUID, Title)
                return
            }
        }
        os_log("Running check for %{public}s - %{public}s", log: Log.app, UUID, Title)
        checkPassed = checkPasses()
        checkTimestamp = Int(Date().currentTimeMillis())
    }

    @objc func moreInfo() {
        if let url = URL(string: "https://paretosecurity.app/check/" + UUID) {
            NSWorkspace.shared.open(url)
        }
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
