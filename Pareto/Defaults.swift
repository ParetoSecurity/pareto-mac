//
//  Settings.swift
//  Settings
//
//  Created by Janez Troha on 27/07/2021.
//

import Combine
import Defaults
import Foundation

enum ReportingRoles: String, Defaults.Serializable {
    case free
    case team
    case personal
}

#if DEBUG
    let extensionDefaults = UserDefaults(suiteName: "debug-paretosecurity")!
#else
    let extensionDefaults = UserDefaults.standard
#endif

extension Defaults.Keys {
    // Teams
    static let userID = Key<String>("userID", default: "", suite: extensionDefaults)
    static let userEmail = Key<String>("userEmail", default: "", suite: extensionDefaults)
    static let isTeamOwner = Key<Bool>("isTeamOwner", default: false, suite: extensionDefaults)
    static let teamID = Key<String>("teamID", default: "", suite: extensionDefaults)
    static let teamAuth = Key<String>("teamAuth", default: "", suite: extensionDefaults)
    static let machineUUID = Key<String>("machineUUID", default: AppInfo.getSystemUUID() ?? UUID().uuidString, suite: extensionDefaults)
    static let sendHWInfo = Key<Bool>("sendHWInfo", default: false, suite: extensionDefaults)

    // License
    static let license = Key<String>("license", default: "", suite: extensionDefaults)
    static let reportingRole = Key<ReportingRoles>("reportingRole", default: .free, suite: extensionDefaults)
    static let teamAPI = Key<String>("teamAPI", default: Team.defaultAPI, suite: extensionDefaults)
    static let lastTeamUpdate = Key<Int>("lastTeamUpdate", default: 0, suite: extensionDefaults)

    // Updates
    static let updateNag = Key<Bool>("updateNag", default: false, suite: extensionDefaults)
    static let showBeta = Key<Bool>("showBeta", default: false, suite: extensionDefaults)
    static let betaChannel = Key<Bool>("betaChannel", default: false, suite: extensionDefaults)
    static let lastUpdateCheck = Key<Int>("lastUpdateCheck", default: Date().currentTimeMillis(), suite: extensionDefaults)

    // Checks
    static let snoozeTime = Key<Int>("snoozeTime", default: 0, suite: extensionDefaults)
    static let lastCheck = Key<Int>("lastCheck", default: 0, suite: extensionDefaults)
    static let checksPassed = Key<Bool>("checksPassed", default: false, suite: extensionDefaults)
    static let lastNagShown = Key<Int>("lastNagShown", default: Date().currentTimeMillis(), suite: extensionDefaults)
    static let checkForUpdatesRecentOnly = Key<Bool>("checkForUpdatesRecentOnly", default: true, suite: extensionDefaults)
    static let showNotifications = Key<Bool>("showNotifications", default: false, suite: extensionDefaults)
}

public extension Defaults {
    static func firstLaunch() -> Bool {
        return Defaults[.lastCheck] == 0
    }

    static func shouldDoUpdateCheck() -> Bool {
        return Defaults[.lastUpdateCheck] + Date.HourInMilis < Date().currentTimeMillis()
    }

    static func doneUpdateCheck() {
        Defaults[.lastUpdateCheck] = Date().currentTimeMillis()
        Defaults[.updateNag] = false
    }

    static func shouldDoTeamUpdate() -> Bool {
        return Defaults[.lastTeamUpdate] + (AppInfo.Flags.slowerTeamUpdate ? Date.HourInMilis * 8 : Date.HourInMilis) < Date().currentTimeMillis()
    }

    static func doneTeamUpdate() {
        Defaults[.lastTeamUpdate] = Date().currentTimeMillis()
    }

    static func shouldShowNag() -> Bool {
        return Defaults[.lastNagShown] + (Date.HourInMilis * 24 * AppInfo.Flags.nagScreenDelayDays) < Date().currentTimeMillis()
    }

    static func shownNag() {
        Defaults[.lastNagShown] = Date().currentTimeMillis()
    }

    static func toFree() {
        Defaults[.license] = ""
        Defaults[.userEmail] = ""
        Defaults[.userID] = ""
        Defaults[.teamID] = ""
        AppInfo.Licensed = false
        Defaults[.reportingRole] = .free
    }
}
