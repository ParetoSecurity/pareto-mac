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
    static let teamID = Key<String>("teamID", default: "")
    static let deviceID = Key<String>("deviceID", default: "")
    static let userEmail = Key<String>("userEmail", default: "")
    static let machineUUID = Key<String>("machineUUID", default: AppInfo.getSystemUUID() ?? UUID().uuidString)
    static let license = Key<String>("license", default: "")
    static let reportingRole = Key<ReportingRoles>("reportingRole", default: .free)
    static let teamAPI = Key<String>("teamAPI", default: Team.defaultAPI)

    // Updates
    static let updateNag = Key<Bool>("updateNag", default: false)
    static let showBeta = Key<Bool>("showBeta", default: false)
    static let betaChannel = Key<Bool>("betaChannel", default: false)
    static let lastUpdateCheck = Key<Int>("lastUpdateCheck", default: Date().currentTimeMillis())

    // Checks
    static let snoozeTime = Key<Int>("snoozeTime", default: 0)
    static let lastCheck = Key<Int>("lastCheck", default: 0)
    static let checksPassed = Key<Bool>("checksPassed", default: false)
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

    static func toFree() {
        Defaults[.license] = ""
        Defaults[.userEmail] = ""
        Defaults[.userID] = ""
        Defaults[.teamID] = ""
        Defaults[.deviceID] = ""
        AppInfo.Licensed = false
        Defaults[.reportingRole] = .free
    }
}
