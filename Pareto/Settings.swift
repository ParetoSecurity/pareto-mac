//
//  Settings.swift
//  Settings
//
//  Created by Janez Troha on 27/07/2021.
//

import Combine
import Foundation

class UserSettings: ObservableObject {
    @Published var runAfterSleep: Bool {
        didSet {
            UserDefaults.standard.set(runAfterSleep, forKey: "runAfterSleep")
        }
    }

    init() {
        runAfterSleep = UserDefaults.standard.object(forKey: "runAfterSleep") as? Bool ?? true
    }
}
