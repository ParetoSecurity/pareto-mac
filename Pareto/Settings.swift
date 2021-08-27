//
//  Settings.swift
//  Settings
//
//  Created by Janez Troha on 27/07/2021.
//

import Combine
import Defaults

extension Defaults.Keys {
    static let runAfterSleep = Key<Bool>("runAfterSleep", default: true)
    static let teamID = Key<String>("teamID", default: "")
    static let userID = Key<String>("userID", default: "")
    static let showWelcome = Key<Bool>("showWelcome", default: false)
    static let betaChannel = Key<Bool>("betaChannel", default: false)
    static let internalRunChecks = Key<Bool>("internalRunChecks", default: false)
}
