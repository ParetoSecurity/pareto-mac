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

extension Defaults.Keys {
    // Teams
    static let userID = Key<String>("userID", default: "")
    static let userEmail = Key<String>("userEmail", default: "")
    static let isTeamOwner = Key<Bool>("isTeamOwner", default: false)
    static let teamID = Key<String>("teamID", default: "")
    static let teamAuth = Key<String>("teamAuth", default: "")
    static let machineUUID = Key<String>("machineUUID", default: AppInfo.getSystemUUID() ?? UUID().uuidString)

    // License
    static let license = Key<String>("license", default: "")
    static let reportingRole = Key<ReportingRoles>("reportingRole", default: .free)
    static let teamAPI = Key<String>("teamAPI", default: Team.defaultAPI)
    static let lastTeamUpdate = Key<Int>("lastTeamUpdate", default: 0)

    // Updates
    static let updateNag = Key<Bool>("updateNag", default: false)
    static let showBeta = Key<Bool>("showBeta", default: false)
    static let betaChannel = Key<Bool>("betaChannel", default: false)
    static let lastUpdateCheck = Key<Int>("lastUpdateCheck", default: Date().currentTimeMillis())

    // Checks
    static let snoozeTime = Key<Int>("snoozeTime", default: 0)
    static let lastCheck = Key<Int>("lastCheck", default: 0)
    static let checksPassed = Key<Bool>("checksPassed", default: false)
    static let lastNagShown = Key<Int>("lastNagShown", default: Date().currentTimeMillis())
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
