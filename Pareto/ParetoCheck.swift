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

class ParetoCheck {
    private(set) var UUID = "UUID"
    private(set) var Title = "Title"
    private(set) var moreURL = "/"
    private(set) var canRunInSandbox = true

    var EnabledKey: String {
        "ParetoCheck-" + UUID + "-Enabled"
    }

    var SnoozeKey: String {
        "ParetoCheck-" + UUID + "-Snooze"
    }

    var PassesKey: String {
        "ParetoCheck-" + UUID + "-Passes"
    }

    var TimestampKey: String {
        "ParetoCheck-" + UUID + "-TS"
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
                    item.image = NSImage.SF(name: "checkmark").tint(color: .systemGreen)
                } else {
                    item.image = NSImage.SF(name: "exclamationmark").tint(color: .systemRed)
                }
            }
        } else {
            item.image = NSImage.SF(name: "shield.slash")
        }

        return item
    }

    func configure() {
        UserDefaults.standard.register(defaults: [
            EnabledKey: true,
            SnoozeKey: 0,
            PassesKey: false,
            TimestampKey: 0
        ])
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
        if let url = URL(string: "https://paretosecurity.app" + moreURL) {
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

    func isListening(withPort port: Int) -> Bool {
        let port = UInt16(port)
        let socketFileDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        if socketFileDescriptor == -1 {
            return false
        }

        var addr = sockaddr_in()
        let sizeOfSockkAddr = MemoryLayout<sockaddr_in>.size
        addr.sin_len = __uint8_t(sizeOfSockkAddr)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = Int(OSHostByteOrder()) == OSLittleEndian ? _OSSwapInt16(port) : port
        addr.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
        addr.sin_zero = (0, 0, 0, 0, 0, 0, 0, 0)
        var bind_addr = sockaddr()
        memcpy(&bind_addr, &addr, Int(sizeOfSockkAddr))

        if Darwin.bind(socketFileDescriptor, &bind_addr, socklen_t(sizeOfSockkAddr)) == -1 {
            return false
        }
        let isOpen = listen(socketFileDescriptor, SOMAXCONN) != -1
        Darwin.close(socketFileDescriptor)
        return isOpen
    }
}
