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
    static let showWelcome = Key<Bool>("showWelcome", default: true)
}
