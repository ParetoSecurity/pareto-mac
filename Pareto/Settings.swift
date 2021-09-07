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
    static let showBeta = Key<Bool>("showBeta", default: false)
    static let betaChannel = Key<Bool>("betaChannel", default: false)
    static let internalRunChecks = Key<Bool>("internalRunChecks", default: false)
    static let snoozeTime = Key<Int>("snoozeTime", default: 0)
    static let lastUpdateCheck = Key<Int>("lastUpdateCheck", default: Date().currentTimeMillis())
    static let machineUUID = Key<String>("machineUUID", default: AppInfo.getSystemUUID() ?? UUID().uuidString)
}

public extension Defaults {
    static func shouldDoUpdateCheck() -> Bool {
        return Defaults[.lastUpdateCheck] + Date.HourInMilis < Date().currentTimeMillis()
    }

    static func doneUpdateCheck() {
        Defaults[.lastUpdateCheck] = Date().currentTimeMillis()
    }
}
