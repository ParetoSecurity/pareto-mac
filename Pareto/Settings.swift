//
//  Settings.swift
//  Settings
//
//  Created by Janez Troha on 27/07/2021.
//

import Foundation
import Combine

class UserSettings: ObservableObject {

    @Published var runAfterSleep: Bool {
        didSet {
            UserDefaults.standard.set(runAfterSleep, forKey: "runAfterSleep")
        }
    }
    
    init() {
        self.runAfterSleep = UserDefaults.standard.object(forKey: "runAfterSleep") as? Bool ?? true
    }
}
