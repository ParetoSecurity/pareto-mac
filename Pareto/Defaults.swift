//
//  Defaults.swift
//  Settings
//
//  Created by Janez Troha on 27/07/2021.
//

import AppKit
import Combine
import Defaults
import Foundation
import SwiftUI

enum ReportingRoles: String, Defaults.Serializable {
    case team
    case opensource
}

#if DEBUG
    let extensionDefaults = UserDefaults(suiteName: "debug-paretosecurity")!
#else
    let extensionDefaults = UserDefaults.standard
#endif

extension Defaults.Keys {
    static let reportingRole = Key<ReportingRoles>("reportingRole", default: .opensource, suite: extensionDefaults)
    // Teams
    static let license = Key<String>("license", default: "", suite: extensionDefaults)
    static let migrated = Key<Bool>("migrated", default: false, suite: extensionDefaults)
    static let userID = Key<String>("userID", default: "", suite: extensionDefaults)
    static let userEmail = Key<String>("userEmail", default: "", suite: extensionDefaults)
    static let isTeamOwner = Key<Bool>("isTeamOwner", default: false, suite: extensionDefaults)
    static let teamID = Key<String>("teamID", default: "", suite: extensionDefaults)
    static let teamAuth = Key<String>("teamAuth", default: "", suite: extensionDefaults)
    static let teamAPI = Key<String>("teamAPI", default: "https://cloud.paretosecurity.com/", suite: extensionDefaults)
    static let lastTeamUpdate = Key<Int>("lastTeamUpdate", default: 0, suite: extensionDefaults)
    static let machineUUID = Key<String>("machineUUID", default: AppInfo.getSystemUUID() ?? UUID().uuidString, suite: extensionDefaults)
    static let sendHWInfo = Key<Bool>("sendHWInfo", default: false, suite: extensionDefaults)
    static let lastHWAsk = Key<Int>("lastHWAsk", default: 0, suite: extensionDefaults)

    // Updates
    static let updateNag = Key<Bool>("updateNag", default: false, suite: extensionDefaults)
    static let showBeta = Key<Bool>("showBeta", default: false, suite: extensionDefaults)
    static let lastUpdateCheck = Key<Int>("lastUpdateCheck", default: Date().currentTimeMs(), suite: extensionDefaults)

    // Checks
    static let snoozeTime = Key<Int>("snoozeTime", default: 0, suite: extensionDefaults)
    static let lastCheck = Key<Int>("lastCheck", default: 0, suite: extensionDefaults)
    static let checksPassed = Key<Bool>("checksPassed", default: false, suite: extensionDefaults)
    static let hideWhenNoFailures = Key<Bool>("hideWhenNoFailures", default: false, suite: extensionDefaults)
    static let myChecks = Key<Bool>("myChecks", default: false, suite: extensionDefaults)
    static let myChecksURL = Key<URL?>("myChecksURL", default: nil, suite: extensionDefaults)
    static let disableChecksEvents = Key<Bool>("disableChecksEvents", default: false, suite: extensionDefaults)
    static let checkForUpdatesRecentOnly = Key<Bool>("checkForUpdatesRecentOnly", default: true, suite: extensionDefaults)
    static let alternativeColor = Key<Bool>("alternativeColor", default: false, suite: extensionDefaults)
    static let ignoredUserAccounts = Key<[String]>("ignoredUserAccounts", default: [], suite: extensionDefaults)
}

public extension Defaults {
    static func firstLaunch() -> Bool {
        return Defaults[.lastCheck] == 0
    }

    static var betaChannelComputed: Bool {
        return Defaults[.showBeta]
    }

    static func customChecksPath() -> URL {
        if let path = Defaults[.myChecksURL] {
            return path
        }

        return try! FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("ParetoAuditor", conformingTo: .directory)
    }

    static func shouldDoUpdateCheck() -> Bool {
        return Defaults[.lastUpdateCheck] + Date.HourInMs < Date().currentTimeMs()
    }

    static func doneUpdateCheck() {
        Defaults[.lastUpdateCheck] = Date().currentTimeMs()
        Defaults[.updateNag] = false
    }

    static func OKColor() -> NSColor {
        if Defaults[.alternativeColor] {
            let light = NSColor(red: 255, green: 179, blue: 64, alpha: 1)
            let dark = NSColor(red: 255, green: 179, blue: 64, alpha: 1)
            let isDark = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
            return isDark ? dark : light
        }
        return NSColor.systemGreen
    }

    static func FailColor() -> NSColor {
        if Defaults[.alternativeColor] {
            let light = NSColor(red: 64, green: 156, blue: 255, alpha: 1)
            let dark = NSColor(red: 64, green: 156, blue: 255, alpha: 1)
            let isDark = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
            return isDark ? dark : light
        }
        return NSColor.systemOrange
    }

    static func shouldAskForHWAllow() -> Bool {
        return Defaults[.lastHWAsk] + Date.HourInMs * 24 * 7 * 30 * 6 < Date().currentTimeMs()
    }

    static func shouldDoTeamUpdate() -> Bool {
        return Defaults[.lastTeamUpdate] + (AppInfo.Flags.slowerTeamUpdate ? Date.HourInMs * 8 : Date.HourInMs) < Date().currentTimeMs()
    }

    static func doneTeamUpdate() {
        Defaults[.lastTeamUpdate] = Date().currentTimeMs()
    }

    static func toOpenSource() {
        Defaults[.userEmail] = ""
        Defaults[.userID] = ""
        Defaults[.teamID] = ""
        Defaults[.reportingRole] = .opensource
    }
}
