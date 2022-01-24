//
//  ParetoApp.swift
//  Pareto
//
//  Created by Janez Troha on 12/07/2021.
//

import Cache
import Defaults
import Foundation
import os.log
import OSLog
import Regex
import SwiftUI
import Version

enum AppInfo {
    static let appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
    static let buildVersion: String = Bundle.main.infoDictionary?["CFBundleVersion"] as! String
    static let machineName: String = Host.current().localizedName!
    static let macOSVersion = ProcessInfo.processInfo.operatingSystemVersion
    static let macOSVersionString = "\(macOSVersion.majorVersion).\(macOSVersion.minorVersion).\(macOSVersion.patchVersion)"
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.arguments.contains("isRunningTests") || ProcessInfo.processInfo.environment["CI"] ?? "false" != "false"
    }

    static var Licensed = false
    static var secExp = false
    static let Flags = FlagsUpdater()

    static var utmSource: String {
        var source = "app"

        #if DEBUG
            source += "-debug"
        #else

            if Defaults[.showBeta] {
                source += "-pre"
            } else {
                source += "-live"
            }

        #endif

        #if SETAPP_ENABLED
            source += "-setapp"
        #else
            if Licensed {
                if Defaults[.teamID].isEmpty {
                    source += "-personal"
                } else {
                    source += "-team"
                }
            } else {
                source += "-opensource"
            }
        #endif

        return source
    }

    #if DEBUG
        static let versionStorage = try! Storage<String, Version>(
            diskConfig: DiskConfig(name: "Version+Bundles+Debug", expiry: .seconds(1)),
            memoryConfig: MemoryConfig(expiry: .seconds(1)),
            transformer: TransformerFactory.forCodable(ofType: Version.self) // Storage<String, Version>
        )
    #else
        static let versionStorage = try! Storage<String, Version>(
            diskConfig: DiskConfig(name: "Version+Bundles", expiry: .seconds(3600 * 24)),
            memoryConfig: MemoryConfig(expiry: .seconds(3600 * 24 * 2)),
            transformer: TransformerFactory.forCodable(ofType: Version.self) // Storage<String, Version>
        )
    #endif

    static var hwModel: String {
        HWInfo(forKey: "model")
    }

    static var hwModelName: String {
        // Depending on if your serial number is 11 or 12 characters long take the last 3 or 4 characters, respectively, and feed that to the following URL after the ?cc=XXXX part.
        let nameRegex = Regex("<configCode>(.+)</configCode>")
        let cc = AppInfo.hwSerial.count <= 11 ? AppInfo.hwSerial.suffix(3) : AppInfo.hwSerial.suffix(4)
        let url = URL(string: "https://support-sp.apple.com/sp/product?cc=\(cc)")!
        let data = try? String(contentsOf: url)
        if data != nil {
            let nameResult = nameRegex.firstMatch(in: data ?? "")
            return nameResult?.groups.first?.value ?? AppInfo.hwModel
        }

        return AppInfo.hwModel
    }

    static var hwSerial: String {
        HWInfo(forKey: "IOPlatformSerialNumber")
    }

    static let teamsURL = { () -> URL in
        let baseURL = "https://dash.paretosecurity.com/?utm_source=\(AppInfo.utmSource)&utm_medium=team-link"
        return URL(string: baseURL)!
    }

    static let bugReportURL = { () -> URL in
        let baseURL = "https://paretosecurity.com/report-bug?"
        let logs = logEntries().joined(separator: "\n").addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
        let versions = getVersions().addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
        if let url = URL(string: baseURL + "&logs=" + logs! + "&version=" + versions!) {
            return url
        }

        return URL(string: baseURL)!
    }

    static let logEntries = { () -> [String] in
        var logs = [String]()

        logs.append("Location: \(Bundle.main.path)")
        logs.append("Build: \(AppInfo.utmSource)")

        logs.append("\nLogs:")
        logs.append("Please copy the logs from the Console app by searching for the ParetoSecurity.")
        return logs
    }

    static let getVersions = { () -> String in
        "HW: \(AppInfo.hwModelName)\nmacOS: \(AppInfo.macOSVersionString)\nApp Version: \(AppInfo.appVersion)\nBuild: \(AppInfo.buildVersion)"
    }

    public static func getSystemUUID() -> String? {
        let dev = IOServiceMatching("IOPlatformExpertDevice")
        let platformExpert: io_service_t = IOServiceGetMatchingService(kIOMasterPortDefault, dev)
        let serialNumberAsCFString = IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0)
        IOObjectRelease(platformExpert)
        return serialNumberAsCFString!.takeUnretainedValue() as? String
    }
}
