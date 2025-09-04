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

    // Indicate check has errored
    var hasError = false

    // Add these properties to your ParetoCheck class:
    private var cachedIsRunnableValue: Bool?
    private var cachedIsRunnableTimestamp: Date?

    // This function caches the result of isRunnable for 5 minutes (300 seconds).
    func isRunnableCached() -> Bool {
        let cacheDuration: TimeInterval = 300 // 5 minutes in seconds
        let now = Date()

        // If a cached value exists and is still valid, return it.
        if let timestamp = cachedIsRunnableTimestamp,
           let value = cachedIsRunnableValue,
           now.timeIntervalSince(timestamp) < cacheDuration
        {
            return value
        }

        // Otherwise, compute the current state, cache it, and update the timestamp.
        let currentValue = isRunnable
        cachedIsRunnableValue = currentValue
        cachedIsRunnableTimestamp = now
        return currentValue
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

    var hasDebug: Bool {
        false
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
            cachedIsRunnableValue = nil
            cachedIsRunnableTimestamp = nil
        }
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

    var isCritical: Bool {
        return false
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
        // Check if Command key is pressed
        if NSEvent.modifierFlags.contains(.command), hasDebug {
            showDebugWindow()
        } else {
            NSWorkspace.shared.open(infoURL)
        }
    }

    @objc func showDebugWindow() {
        guard hasDebug else { return }

        DispatchQueue.main.async { [self] in
            let debugInfo = self.debugInfo()
            let hostingController = NSHostingController(rootView: CheckDebugView(checkTitle: self.Title, debugInfo: debugInfo))
            hostingController.preferredContentSize = NSSize(width: 640, height: 480)
            if #available(macOS 13.0, *) {
                hostingController.sizingOptions = .preferredContentSize
            }
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Debug Info - \(self.Title)"
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.center()
            window.setContentSize(NSSize(width: 640, height: 480))

            let windowController = NSWindowController(window: window)
            windowController.showWindow(nil)
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
            // os_log("Failed reading %{public}s", path)
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
