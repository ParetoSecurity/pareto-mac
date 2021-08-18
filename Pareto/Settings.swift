//
//  Settings.swift
//  Settings
//
//  Created by Janez Troha on 27/07/2021.
//

import Combine
import Foundation

class UserSettings: ObservableObject {
    var Datastore = UserDefaults(suiteName: "ParetoSecurity")!

    @Published var runAfterSleep: Bool {
        didSet {
            Datastore.set(runAfterSleep, forKey: "runAfterSleep")
        }
    }

    init() {
        runAfterSleep = Datastore.bool(forKey: "runAfterSleep")
    }
}
