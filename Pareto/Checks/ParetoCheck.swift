//
//  MenuItemCheck.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/07/2021.
//

import AppKit
import Combine
import Foundation
import OSLog
import SwiftUI

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

class ParetoCheck: ObservableObject {
    private enum Snooze {
        static let oneHour = 3600
        static let oneDay = oneHour * 24
        static let oneWeek = oneDay * 7
    }

    private let cancellable: Cancellable
    private let defaults: UserDefaults
    private let UUID: String
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
            UUID + "-TS": 0,
        ])

        cancellable = NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification)
            .map { _ in () }
            .subscribe(objectWillChange)
    }

    var isActive: Bool {
        set { defaults.set(newValue, forKey: EnabledKey) }
        get { defaults.bool(forKey: EnabledKey) }
    }

    var snoozeTime: Int {
        set { defaults.set(newValue, forKey: SnoozeKey) }
        get { defaults.integer(forKey: SnoozeKey) }
    }

    var checkPassed: Bool {
        set { defaults.set(newValue, forKey: PassesKey) }
        get { defaults.bool(forKey: PassesKey) }
    }

    var checkTimestamp: Int {
        set { defaults.set(newValue, forKey: TimestampKey) }
        get { defaults.integer(forKey: TimestampKey) }
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
        let status = isActive ? snoozeTime == 0 ? checkPassed ? "✅ " : "❌ " : "🕒 " : ""
        let item = NSMenuItem(title: status + title, action: nil, keyEquivalent: "")
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
            logger.info("Disabled \(self.UUID) - \(self.title)")
            return
        }
        logger.info("Running check \(self.UUID) - \(self.title)")
        if snoozeTime != 0 {
            if checkTimestamp + (snoozeTime * 1000) >= Int(Date().currentTimeMillis()) {
                logger.info("Resetting snooze for \(self.UUID) - \(self.title)")
                snoozeTime = 0
            } else {
                logger.info("Snooze in effect for \(self.UUID) - \(self.title)")
                return
            }
        }

        checkPassed = checkPasses()
        checkTimestamp = Int(Date().currentTimeMillis())
    }
    
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
            return nil
        }
        return dictionary
    }
}
