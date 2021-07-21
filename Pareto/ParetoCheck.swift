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

extension NSImage {
    static func SF(name: String) -> NSImage {
        let icon = NSImage(systemSymbolName: name, accessibilityDescription: nil)!
        icon.isTemplate = true
        return icon
    }

    func tint(color: NSColor) -> NSImage {
        if isTemplate == false {
            return self
        }

        guard let image = copy() as? NSImage else {
            return self
        }

        image.lockFocus()

        color.set()

        let imageRect = NSRect(origin: .zero, size: image.size)
        imageRect.fill(using: .sourceIn)

        image.unlockFocus()
        image.isTemplate = false

        return image
    }
}

extension Date {
    func currentTimeMillis() -> Int64 {
        return Int64(timeIntervalSince1970 * 1000)
    }

    func fromTimeStamp(timeStamp: Int) -> String {
        let date = NSDate(timeIntervalSince1970: TimeInterval(timeStamp / 1000))

        let dayTimePeriodFormatter = DateFormatter()
        dayTimePeriodFormatter.dateFormat = "dd MMM YY, hh:mm a"

        let dateString = dayTimePeriodFormatter.string(from: date as Date)
        return dateString
    }
}

extension String {
    func versionCompare(_ otherVersion: String) -> ComparisonResult {
        let versionDelimiter = "."

        var versionComponents = components(separatedBy: versionDelimiter) // <1>
        var otherVersionComponents = otherVersion.components(separatedBy: versionDelimiter)

        let zeroDiff = versionComponents.count - otherVersionComponents.count // <2>

        if zeroDiff == 0 { // <3>
            // Same format, compare normally
            return compare(otherVersion, options: .numeric)
        } else {
            let zeros = Array(repeating: "0", count: abs(zeroDiff)) // <4>
            if zeroDiff > 0 {
                otherVersionComponents.append(contentsOf: zeros) // <5>
            } else {
                versionComponents.append(contentsOf: zeros)
            }
            return versionComponents.joined(separator: versionDelimiter)
                .compare(otherVersionComponents.joined(separator: versionDelimiter), options: .numeric) // <6>
        }
    }
}

class ParetoCheck: ObservableObject {
    private enum Snooze {
        static let oneHour = 3600
        static let oneDay = oneHour * 24
        static let oneWeek = oneDay * 7
    }

    private let cancellable: Cancellable
    private let defaults: UserDefaults
    public let UUID: String
    private let title: String

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

    required init(defaults: UserDefaults = .standard, id: String! = "", title: String! = "") {
        self.defaults = defaults
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
    }

    @objc func enableCheck() {
        isActive = true
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

        submenu.addItem(addSubmenu(withTitle: "More Information", action: #selector(moreInfo)))
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
            os_log("Disabled for %{public}s - %{public}s", UUID, title)
            return
        }

        if snoozeTime != 0 {
            let nextCheck = checkTimestamp + (snoozeTime * 1000)
            let now = Int(Date().currentTimeMillis())
            if now >= nextCheck {
                os_log("Resetting snooze for %{public}s - %{public}s", UUID, title)
                snoozeTime = 0
            } else {
                os_log("Snooze in effect for %{public}s - %{public}s", UUID, title)
                return
            }
        }
        os_log("Running check for %{public}s - %{public}s", UUID, title)
        checkPassed = checkPasses()
        checkTimestamp = Int(Date().currentTimeMillis())
    }
}

extension ParetoCheck {
    func readDefaults(app: String, key: String) -> String? {
        let task = Process()
        let pipe = Pipe()

        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-currentHost", "read", app, key]
        task.launchPath = "/usr/bin/defaults"
        task.launch()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)!

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
