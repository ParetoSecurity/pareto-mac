//
//  Settings.swift
//  Settings
//
//  Created by Janez Troha on 27/07/2021.
//

import Combine
import Defaults
import Foundation

extension Defaults.Keys {
    static let runAfterSleep = Key<Bool>("runAfterSleep", default: true)
    static let teamID = Key<String>("teamID", default: "")
    static let userID = Key<String>("userID", default: "")
    static let userEmail = Key<String>("userEmail", default: "")
    static let showBeta = Key<Bool>("showBeta", default: false)
    static let betaChannel = Key<Bool>("betaChannel", default: false)

    static let snoozeTime = Key<Int>("snoozeTime", default: 0)
    static let lastCheck = Key<Int>("lastCheck", default: 0)
    static let checksPassed = Key<Bool>("checksPassed", default: false)

    static let lastUpdateCheck = Key<Int>("lastUpdateCheck", default: Date().currentTimeMillis())
    static let machineUUID = Key<String>("machineUUID", default: AppInfo.getSystemUUID() ?? UUID().uuidString)
    static let license = Key<String>("license", default: "")
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
    }
}
