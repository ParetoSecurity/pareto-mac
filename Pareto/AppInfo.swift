//
//  AppInfo.swift
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

// MARK: - SPHardwareWrapper

struct SPHardwareWrapper: Codable {
    let spHardwareDataType: [SPHardware]

    enum CodingKeys: String, CodingKey {
        case spHardwareDataType = "SPHardwareDataType"
    }
}

// MARK: - SPHardwareDataType

struct SPHardware: Codable {
    let machineModel, machineName, modelNumber: String?
    let serialNumber: String

    enum CodingKeys: String, CodingKey {
        case machineModel = "machine_model"
        case machineName = "machine_name"
        case modelNumber = "model_number"
        case serialNumber = "serial_number"
    }

    static func gather() -> SPHardware? {
        guard let jsonData = runCMD(app: "/usr/sbin/system_profiler", args: ["SPHardwareDataType", "-json"]).data(using: .utf8) else { return nil }
        let info: SPHardwareWrapper = try! JSONDecoder().decode(SPHardwareWrapper.self, from: jsonData)
        return info.spHardwareDataType.first
    }
}

enum AppInfo {
    static let appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
    static let buildVersion: String = Bundle.main.infoDictionary?["CFBundleVersion"] as! String
    static var machineName: String { Host.current().localizedName! }
    static let macOSVersion = ProcessInfo.processInfo.operatingSystemVersion
    static let macOSVersionString = "\(macOSVersion.majorVersion).\(macOSVersion.minorVersion).\(macOSVersion.patchVersion)"
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.arguments.contains("isRunningTests") || ProcessInfo.processInfo.environment["CI"] ?? "false" != "false"
    }

    static var secExp = false
    static let Flags = FlagsUpdater()
    static let HWInfo = SPHardware.gather()
    static let TeamSettings = TeamSettingsUpdater()
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
            if Defaults[.teamID].isEmpty {
                source += "-opensource"
            } else {
                source += "-team"
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
            diskConfig: DiskConfig(name: "Version+Bundles+v2", expiry: .seconds(3600 * 24)),
            memoryConfig: MemoryConfig(expiry: .seconds(3600)),
            transformer: TransformerFactory.forCodable(ofType: Version.self) // Storage<String, Version>
        )
    #endif

    static var hwModelName: String {
        if let modelNumber = HWInfo?.modelNumber {
            return "\(HWInfo?.machineName ?? "Unknown") (\(modelNumber))"
        }
        return "\(HWInfo?.machineName ?? "Unknown") (\(HWInfo?.machineModel ?? "Unknown"))"
    }

    static var hwSerial: String {
        HWInfo?.serialNumber ?? "Unknown"
    }

    static let teamsURL = { () -> URL in
        let baseURL = "https://cloud.paretosecurity.com/?utm_source=\(AppInfo.utmSource)&utm_medium=team-link"
        return URL(string: baseURL)!
    }

    static let docsURL = { () -> URL in
        let baseURL = "https://paretosecurity.com/docs/mac"
        return URL(string: baseURL)!
    }

    static let bugReportURL = { () -> URL in
        let baseURL = "https://paretosecurity.com/report-bug?"
        let versions = getVersions().addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
        if let url = URL(string: baseURL + "&version=" + versions!) {
            return url
        }

        return URL(string: baseURL)!
    }

    static let logEntries = { () -> [String] in
        var logs = [String]()

        logs.append("Location: \(Bundle.main.path)")
        logs.append("Build: \(AppInfo.utmSource)")
        logs.append("IsAdmin: \(SystemUser.current.isAdmin.description)")
        logs.append("\nLogs:")

        if #available(macOS 12.0, *) {
            let logStore = try OSLogStore(scope: .currentProcessIdentifier)
            // Get all the logs from the last hour.
            let oneHourAgo = logStore.position(date: Date().addingTimeInterval(-3600))

            // Fetch log objects.
            let allEntries = try logStore.getEntries(at: oneHourAgo)

            // Filter the log to be relevant for our specific subsystem
            // and remove other elements (signposts, etc).
            for log in allEntries
                .compactMap({ $0 as? OSLogEntryLog })
                .filter({ entry in
                    entry.subsystem == Bundle.main.bundleIdentifier
                }) {
                logs.append("\(log.subsystem): \(log.composedMessage)")
            }
        } else {
            logs.append("Please copy the logs from the Console app by searching for the ParetoSecurity.")
        }

        return logs
    }

    static let getVersions = { () -> String in
        "HW: \(AppInfo.hwModelName) macOS: \(AppInfo.macOSVersionString) App: Pareto Auditor App Version: \(AppInfo.appVersion) Build: \(AppInfo.buildVersion)"
    }

    static func getSystemUUID() -> String? {
        let dev = IOServiceMatching("IOPlatformExpertDevice")
        let platformExpert: io_service_t = IOServiceGetMatchingService(kIOMasterPortDefault, dev)
        let serialNumberAsCFString = IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0)
        IOObjectRelease(platformExpert)
        return serialNumberAsCFString!.takeUnretainedValue() as? String
    }
}
