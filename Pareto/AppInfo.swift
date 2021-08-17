//
//  ParetoApp.swift
//  Pareto
//
//  Created by Janez Troha on 12/07/2021.
//

import Foundation
import os.log
import OSLog
import SwiftUI

enum AppInfo {
    static let appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
    static let buildVersion: String = Bundle.main.infoDictionary?["CFBundleVersion"] as! String
    static let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
    static let inSandbox = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    static let isRunningTests = UserDefaults.standard.bool(forKey: "isRunningTests")

    static let hwModel = { () -> String in
        let service = IOServiceGetMatchingService(kIOMasterPortDefault,
                                                  IOServiceMatching("IOPlatformExpertDevice"))
        var modelIdentifier: String?
        if let modelData = IORegistryEntryCreateCFProperty(service, "model" as CFString, kCFAllocatorDefault, 0).takeRetainedValue() as? Data {
            modelIdentifier = String(data: modelData, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters)
        }

        IOObjectRelease(service)
        return modelIdentifier!
    }

    static let bugReportURL = { () -> URL in
        let baseURL = "https://github.com/ParetoSecurity/pareto-mac/issues/new?labels=bug%2Ctriage&template=report_bug.yml&title=%5BBug%5D%3A+"
        if #available(macOS 12.0, *) {
            let logs = logEntries().joined(separator: "\n").addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
            let versions = getVersions().addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
            if let url = URL(string: baseURL + "&logs=" + logs! + "&version=" + versions!) {
                return url
            }
        } else {
            let versions = getVersions().addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
            if let url = URL(string: baseURL + "&version=" + versions!) {
                return url
            }
        }
        return URL(string: baseURL)!
    }

    static let logEntries = { () -> [String] in
        var logs = [String]()
        do {
            if #available(macOS 12.0, *) {
                let logStore = try OSLogStore(scope: .currentProcessIdentifier)
                let enumerator = try logStore.__entriesEnumerator(position: nil, predicate: nil)
                let allEntries = Array(enumerator)
                let osLogEntryObjects = allEntries.compactMap { $0 as? OSLogEntry }
                let osLogEntryLogObjects = osLogEntryObjects.compactMap { $0 as? OSLogEntryLog }
                let subsystem = Bundle.main.bundleIdentifier!
                for entry in osLogEntryLogObjects where entry.subsystem == subsystem {
                    logs.append(entry.category + ": " + entry.composedMessage)
                }
            } else {
                logs.append("Please copy the logs from the Konsole.app with the ParetoSecurity filter.")
            }
        } catch {
            logs.append("logEntries: \(error)")
        }
        return logs
    }

    static let getVersions = { () -> String in
        "HW: \(AppInfo.hwModel())\nmacOS: \(AppInfo.osVersion)\nApp Version: \(AppInfo.appVersion)\nBuild: \(AppInfo.buildVersion)"
    }
}
