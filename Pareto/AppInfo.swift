//
//  ParetoApp.swift
//  Pareto
//
//  Created by Janez Troha on 12/07/2021.
//

import Cache
import Foundation
import os.log
import OSLog
import Regex
import SwiftUI
import Version

enum AppInfo {
    static let claims = [
        Claim(withTitle: "Access Security", withChecks: [
            AutologinCheck.sharedInstance,
            RequirePasswordToUnlock.sharedInstance,
            ScreensaverPasswordCheck.sharedInstance,
            ScreensaverCheck.sharedInstance
        ]),
        Claim(withTitle: "Firewall & Sharing", withChecks: [
            FirewallCheck.sharedInstance,
            FileSharingCheck.sharedInstance,
            PrinterSharingCheck.sharedInstance,
            RemoteManagmentCheck.sharedInstance,
            RemoteLoginCheck.sharedInstance,
            AirPlayCheck.sharedInstance,
            MediaShareCheck.sharedInstance
        ]),
        Claim(withTitle: "System Integrity", withChecks: [
            GatekeeperCheck.sharedInstance,
            FileVaultCheck.sharedInstance,
            BootCheck.sharedInstance,
            OpenWiFiCheck.sharedInstance
        ]),
        Claim(withTitle: "Software Updates", withChecks: [
            App1Password7Check.sharedInstance,
            AppBitwardenCheck.sharedInstance,
            AppCyberduckCheck.sharedInstance,
            AppDashlaneCheck.sharedInstance,
            AppDockerCheck.sharedInstance,
            AppEnpassCheck.sharedInstance,
            AppFirefoxCheck.sharedInstance,
            AppGoogleChromeCheck.sharedInstance,
            AppiTermCheck.sharedInstance,
            AppNordLayerCheck.sharedInstance,
            AppSlackCheck.sharedInstance,
            AppTailscaleCheck.sharedInstance,
            AppZoomCheck.sharedInstance,
            AppSignalCheck.sharedInstance,
            AppWireGuardCheck.sharedInstance,
            AppLibreOfficeCheck.sharedInstance

        ])
    ]

    static var claimsSorted: [Claim] {
        AppInfo.claims.sorted(by: { $0.title.lowercased() < $1.title.lowercased() })
    }

    static let appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
    static let buildVersion: String = Bundle.main.infoDictionary?["CFBundleVersion"] as! String
    static let machineName: String = Host.current().localizedName!
    static let macOSVersion = ProcessInfo.processInfo.operatingSystemVersion
    static let macOSVersionString = "\(macOSVersion.majorVersion).\(macOSVersion.minorVersion).\(macOSVersion.patchVersion)"
    static let isRunningTests = ProcessInfo.processInfo.arguments.contains("isRunningTests")
    static var Licensed = false
    static var secExp = false
    static let Flags = FlagsUpdater()
    #if DEBUG
        static let versionStorage = try! Storage<String, Version>(
            diskConfig: DiskConfig(name: "Version+Bundles+Debug", expiry: .seconds(1)),
            memoryConfig: MemoryConfig(expiry: .seconds(1)),
            transformer: TransformerFactory.forCodable(ofType: Version.self) // Storage<String, Version>
        )
    #else
        static let versionStorage = try! Storage<String, Version>(
            diskConfig: DiskConfig(name: "Version+Bundles", expiry: .seconds(3600)),
            memoryConfig: MemoryConfig(expiry: .seconds(3600)),
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
        let baseURL = "https://dash.paretosecurity.com/?utm_source=app&utm_medium=team-link"
        return URL(string: baseURL)!
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
        logs.append("Location: \(Bundle.main.path)")
        #if DEBUG
            logs.append("Build: debug")
        #else
            logs.append("Build: release")
        #endif
        #if SETAPP_ENABLED
            logs.append("Distribution: setapp")
        #else
            logs.append("Distribution: direct")
        #endif
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
        "HW: \(AppInfo.hwModel)\nmacOS: \(AppInfo.macOSVersionString)\nApp Version: \(AppInfo.appVersion)\nBuild: \(AppInfo.buildVersion)"
    }

    public static func getSystemUUID() -> String? {
        let dev = IOServiceMatching("IOPlatformExpertDevice")
        let platformExpert: io_service_t = IOServiceGetMatchingService(kIOMasterPortDefault, dev)
        let serialNumberAsCFString = IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0)
        IOObjectRelease(platformExpert)
        return serialNumberAsCFString!.takeUnretainedValue() as? String
    }
}
