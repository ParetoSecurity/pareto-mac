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
    static let claims = [
        Claim(withTitle: "Login is secure", withChecks: [AutologinCheck(), RequirePasswordToUnlock()]),
        Claim(withTitle: "Firewall is on", withChecks: [FirewallCheck(), FileSharingCheck(), PrinterSharingCheck()]),
        Claim(withTitle: "System integrity", withChecks: [GatekeeperCheck(), FileVaultCheck(), BootCheck()]),
        Claim(withTitle: "Lock after inactivity", withChecks: [ScreensaverPasswordCheck(), ScreensaverCheck()])
        // Claim(withTitle: "Apps are up-to-date", withChecks: [IntegrationCheck(), IntegrationCheck()])
    ]

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
        logs.append("State:")
        for (k, v) in UserDefaults.standard.dictionaryRepresentation().sorted(by: { $0.key < $1.key }) {
            if k.starts(with: "ParetoCheck-") {
                logs.append("\(k)=\(v)")
            }
        }
        logs.append("\nLogs:")
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

    public static func getSystemUUID() -> String? {
        let dev = IOServiceMatching("IOPlatformExpertDevice")
        let platformExpert: io_service_t = IOServiceGetMatchingService(kIOMasterPortDefault, dev)
        let serialNumberAsCFString = IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0)
        IOObjectRelease(platformExpert)
        return serialNumberAsCFString!.takeUnretainedValue() as? String
    }
}
