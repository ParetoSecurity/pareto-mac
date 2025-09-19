//
//  ParetoCheck.swift
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

    // Provide a concrete Identifiable id
    var id: String { UUID }

    // Indicate check has errored
    var hasError = false

    var showInMenu: Bool {
        isActive
    }

    var EnabledKey: String {
        "ParetoCheck-" + UUID + "-Enabled"
    }

    var PassesKey: String {
        "ParetoCheck-" + UUID + "-Passes"
    }

    var TimestampKey: String {
        "ParetoCheck-" + UUID + "-TS"
    }

    var CachedDetailsKey: String {
        "ParetoCheck-" + UUID + "-Details"
    }

    var DisabledReasonKey: String {
        "ParetoCheck-" + UUID + "-DisabledReason"
    }

    func debugInfo() -> String {
        ""
    }

    var Title: String {
        checkPassed ? TitleON : TitleOFF
    }

    var teamEnforced: Bool {
        if AppInfo.TeamSettings.enforcedChecks.isEmpty {
            return false
        }
        return AppInfo.TeamSettings.enforcedChecks.contains(where: { $0 == UUID })
    }

    var isActive: Bool {
        get {
            if teamEnforced {
                return true
            }
            return UserDefaults.standard.bool(forKey: EnabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: EnabledKey) }
    }

    // Underlying user preference regardless of team enforcement
    var storedIsActive: Bool {
        UserDefaults.standard.bool(forKey: EnabledKey)
    }

    var isRunnable: Bool {
        return isActive
    }

    var isInstalled: Bool {
        return true
    }

    var showSettings: Bool {
        return !teamEnforced
    }

    var reportIfDisabled: Bool {
        return true
    }

    var showSettingsWarnDiskAccess: Bool {
        return false
    }

    var showSettingsWarnEvents: Bool {
        return false
    }

    var requiresHelper: Bool {
        return false
    }

    var checkTimestamp: Int {
        get { UserDefaults.standard.integer(forKey: TimestampKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: TimestampKey)
        }
    }

    var checkPassed: Bool {
        get { UserDefaults.standard.bool(forKey: PassesKey) }
        set { UserDefaults.standard.set(newValue, forKey: PassesKey) }
    }

    var cachedDetails: String {
        get { UserDefaults.standard.string(forKey: CachedDetailsKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: CachedDetailsKey) }
    }

    var disabledReason: String {
        get {
            if !isActive {
                return "Manually disabled"
            } else if !isRunnable {
                // Check for specific Time Machine conditions
                if self is TimeMachineCheck {
                    // For the main Time Machine check
                    if let config = readDefaultsFile(path: "/Library/Preferences/com.apple.TimeMachine.plist") {
                        if config.isEmpty || config.count <= 1 {
                            return "Time Machine is not configured - no backup destination set"
                        }
                        // If AutoBackup is disabled, report explicitly that Time Machine is not enabled
                        if let autoBackupBool = config["AutoBackup"] as? Bool, autoBackupBool == false {
                            return "Time Machine is not enabled - automatic backups are disabled"
                        }
                        if let autoBackupInt = config["AutoBackup"] as? Int, autoBackupInt == 0 {
                            return "Time Machine is not enabled - automatic backups are disabled"
                        }
                    } else {
                        return "Cannot read Time Machine configuration - may need full disk access"
                    }
                } else if self is TimeMachineHasBackupCheck {
                    // For Time Machine backup check - it depends on the main Time Machine check
                    if !TimeMachineCheck.sharedInstance.isActive {
                        return "Depends on 'Time Machine is on' check being enabled"
                    } else if !TimeMachineCheck.sharedInstance.isRunnable {
                        return "Time Machine check cannot run - not configured"
                    } else if let config = readDefaultsFile(path: "/Library/Preferences/com.apple.TimeMachine.plist") {
                        if config.isEmpty || config.count <= 1 {
                            return "Time Machine is not configured - no backup destination"
                        }
                    } else {
                        return "Cannot read Time Machine configuration"
                    }
                } else if self is TimeMachineIsEncryptedCheck {
                    // For Time Machine encryption check - depends on main Time Machine check
                    if !TimeMachineCheck.sharedInstance.isActive {
                        return "Depends on 'Time Machine is on' check being enabled"
                    } else if !TimeMachineCheck.sharedInstance.isRunnable {
                        return "Time Machine check cannot run - not configured"
                    } else if let config = readDefaultsFile(path: "/Library/Preferences/com.apple.TimeMachine.plist") {
                        if config.isEmpty || config.count <= 1 {
                            return "Time Machine is not configured - no backup destination"
                        }
                    } else {
                        return "Cannot read Time Machine configuration"
                    }
                }

                if showSettingsWarnDiskAccess {
                    return "Requires full disk access permission to read system files"
                } else if showSettingsWarnEvents {
                    return "Requires system events access permission"
                } else if requiresHelper {
                    return "Requires privileged helper tool authorization in System Settings"
                }

                // Generic fallback with more context
                return UserDefaults.standard.string(forKey: DisabledReasonKey) ?? "Check prerequisites not met"
            }
            return ""
        }
        set { UserDefaults.standard.set(newValue, forKey: DisabledReasonKey) }
    }

    // Helper function for reading plist files returning a Swift dictionary
    func readDefaultsFile(path: String) -> [String: Any]? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        let plist = try? PropertyListSerialization.propertyList(from: data, format: nil)
        return plist as? [String: Any]
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
                if hasError {
                    item.image = NSImage.SF(name: "questionmark").tint(color: Defaults.FailColor())
                } else {
                    if checkPassed {
                        item.image = NSImage.SF(name: "checkmark").tint(color: Defaults.OKColor())
                    } else {
                        item.image = NSImage.SF(name: "xmark").tint(color: Defaults.FailColor())
                    }
                }
            }
        } else {
            // Show question mark for checks requiring helper when active but helper authorization is not enabled
            if requiresHelper && isActive {
                item.image = NSImage.SF(name: "questionmark.circle").tint(color: .systemOrange)
            } else {
                item.image = NSImage.SF(name: "seal")
            }
        }

        return item
    }

    var CIS: String {
        return "0"
    }

    func configure() {
        UserDefaults.standard.register(defaults: [
            EnabledKey: true,
            PassesKey: false,
            TimestampKey: 0,
        ])
    }

    var details: String { "None" }

    var report: String {
        return "\(UUID):\(checkPassed)"
    }

    var help: String? {
        nil
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

    func run() -> Bool {
        if !isRunnable {
            os_log("Disabled check %{public}s - %{public}s", log: Log.app, UUID, Title)
            return false
        }

        os_log("Running check for %{public}s - %{public}s", log: Log.app, UUID, Title)
        hasError = false
        let result = checkPasses()

        checkPassed = result
        checkTimestamp = Int(Date().currentTimeMs())

        // Cache the details after running the check
        cachedDetails = details

        // Notify UI observers that this check changed
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }

        return result
    }

    var infoURL: URL {
        // For checks requiring helper that are not runnable, direct to helper authorization docs
        if requiresHelper && !isRunnable && isActive {
            var components = URLComponents()
            components.scheme = "https"
            components.host = "paretosecurity.com"
            components.path = "/docs/mac/privileged-helper-authorization"
            components.queryItems = [
                URLQueryItem(name: "utm_source", value: AppInfo.utmSource),
            ]

            guard let url = components.url else {
                fatalError("Invalid URL constructed")
            }
            return url
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "paretosecurity.com"
        components.path = "/check/\(UUID)"
        components.queryItems = [
            URLQueryItem(name: "details", value: details),
            URLQueryItem(name: "utm_source", value: AppInfo.utmSource),
        ]

        guard let url = components.url else {
            fatalError("Invalid URL constructed")
        }
        return url
    }

    @objc func moreInfo() {
        NSWorkspace.shared.open(infoURL)
    }
}

extension ParetoCheck {
    func readDefaults(app: String, key: String) -> String? {
        let output = runCMD(app: "/usr/bin/defaults", args: ["-currentHost", "read", app, key])
        return output.contains("does not exist") ? nil : output
    }

    func readDefaultsNative(path: String, key: String) -> String? {
        let output = runCMD(app: "/usr/bin/defaults", args: ["read", path, key])
        return output.contains("does not exist") ? nil : output.trim()
    }

    func appVersion(path: String, key: String = "CFBundleShortVersionString") -> String? {
        guard let dictionary = NSDictionary(contentsOfFile: path) else {
            // os_log("Failed reading %{public}s", path)
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
