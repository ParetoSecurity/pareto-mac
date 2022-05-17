//
//  MenuItemCheck.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/07/2021.
//

import AppKit
import Combine
import Defaults
import Foundation
import os.log
import SwiftSocket
import SwiftUI

class ParetoCheck: Hashable, ObservableObject, Identifiable {
    static func == (lhs: ParetoCheck, rhs: ParetoCheck) -> Bool {
        lhs.UUID == rhs.UUID
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(UUID)
    }

    private(set) var UUID = "UUID"
    private(set) var TitleON = "TitleON"
    private(set) var TitleOFF = "TitleOFF"

    var EnabledKey: String {
        "ParetoCheck-" + UUID + "-Enabled"
    }

    var PassesKey: String {
        "ParetoCheck-" + UUID + "-Passes"
    }

    var TimestampKey: String {
        "ParetoCheck-" + UUID + "-TS"
    }

    var Title: String {
        checkPassed ? TitleON : TitleOFF
    }

    public var teamDisabled: Bool {
        AppInfo.TeamSettings.disabledChecks.contains(where: { $0 == UUID })
    }

    public var teamEnforced: Bool {
        AppInfo.TeamSettings.enforcedChecks.contains(where: { $0 == UUID })
    }

    public var isActive: Bool {
        get {
            if teamEnforced {
                return true
            }
            let userEnabled = UserDefaults.standard.bool(forKey: EnabledKey)
            return userEnabled && !teamDisabled
        }
        set { UserDefaults.standard.set(newValue, forKey: EnabledKey) }
    }

    public var isRunnable: Bool {
        return isActive
    }

    public var showSettings: Bool {
        return !teamDisabled && !teamEnforced
    }

    public var reportIfDisabled: Bool {
        return true
    }

    public var showSettingsWarnDiskAccess: Bool {
        return false
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
        if isRunnable {
            if Defaults[.snoozeTime] > 0 {
                item.image = NSImage.SF(name: "seal.fill").tint(color: .systemGray)
            } else {
                if checkPassed {
                    item.image = NSImage.SF(name: "checkmark").tint(color: .systemGreen)
                } else {
                    item.image = NSImage.SF(name: "xmark").tint(color: .systemOrange)
                }
            }
        } else {
            item.image = NSImage.SF(name: "seal")
        }

        return item
    }

    public var isCritical: Bool {
        return false
    }

    public var CIS: String {
        return "0"
    }

    func configure() {
        UserDefaults.standard.register(defaults: [
            EnabledKey: true,
            PassesKey: false,
            TimestampKey: 0
        ])
    }

    var details: String { "None" }

    var report: String {
        return "\(UUID):\(checkPassed)"
    }

    var reportJSON: String {
        return """
        {
        "check": "\(Title)",
        "uuid": "\(UUID)",
        "isActive": "\(isActive)",
        "isRunnable": "\(isRunnable)",
        "checkPassed": "\(checkPassed)"
        }
        """
    }

    func run() {
        if AppInfo.TeamSettings.disabledChecks.contains(where: { $0 == UUID }) {
            os_log("Team disabled check %{public}s - %{public}s", log: Log.app, UUID, Title)
            return
        }

        if !isRunnable {
            os_log("Disabled check %{public}s - %{public}s", log: Log.app, UUID, Title)
            return
        }

        os_log("Running check for %{public}s - %{public}s", log: Log.app, UUID, Title)
        checkPassed = checkPasses()
        checkTimestamp = Int(Date().currentTimeMillis())

        if isCritical, !checkPassed {
            showNotification(check: self)
        }
    }

    @objc func moreInfo() {
        if let url = URL(string: "https://paretosecurity.com/check/" + UUID + "?utm_source=" + AppInfo.utmSource) {
            NSWorkspace.shared.open(url)
        }
    }
}

extension ParetoCheck {
    func readDefaults(app: String, key: String) -> String? {
        let output = runCMD(app: "/usr/bin/defaults", args: ["-currentHost", "read", app, key])
        return output.contains("does not exist") ? nil : output
    }

    func readDefaultsFile(path: String) -> NSDictionary? {
        guard let dictionary = NSDictionary(contentsOfFile: path) else {
            os_log("Failed reading %{public}s", path)
            return nil
        }
        return dictionary
    }

    func readDefaultsNative(path: String, key: String) -> String? {
        let output = runCMD(app: "/usr/bin/defaults", args: ["read", path, key])
        return output.contains("does not exist") ? nil : output.trim()
    }

    func appVersion(path: String, key: String = "CFBundleShortVersionString") -> String? {
        guard let dictionary = NSDictionary(contentsOfFile: path) else {
            os_log("Failed reading %{public}s", path)
            return nil
        }
        // print("\(app): \(dictionary as AnyObject)")
        return dictionary.value(forKey: key) as? String
    }

    func isNotListening(withPort port: Int) -> Bool {
        let client = TCPClient(address: "localhost", port: Int32(port))
        switch client.connect(timeout: 10) {
        case .success:
            return false
        case .failure:
            return true
        }
    }

    func isNotListening(withCommand cmd: String, withPort port: Int) -> Bool {
        return !lsof(withCommand: cmd, withPort: port)
    }
}
