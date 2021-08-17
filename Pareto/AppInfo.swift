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

    @available(macOS 10.15, *)

    static let logEntries = { () -> [String] in
        var logs = [String]()
        do {
            let subsystem = Bundle.main.bundleIdentifier!
            let logStore = try OSLogStore.local()
            let lastBoot = logStore.position(timeIntervalSinceLatestBoot: 0)
            let matchingPredicate = NSPredicate(format: "subsystem == '\(subsystem)'")
            let enumerator = try logStore.getEntries(with: [],
                                                     at: lastBoot,
                                                     matching: matchingPredicate)
            let osLogEntryLogObjects = Array(enumerator).compactMap { $0 as? OSLogEntryLog }
            for entry in osLogEntryLogObjects where entry.subsystem == subsystem {
                logs.append(entry.category + ": " + entry.composedMessage)
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
