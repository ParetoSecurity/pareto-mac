//
//  1Password.swift
//  Pareto Security
//
//  Created by Janez Troha on 20/07/2021.
//

import Foundation

class OnePasswordCheck: ParetoCheck {
    final var ID = "1ee63d54-875c-4e72-aca2-81517d0c9e20"
    final var TITLE = "1Password is up-to-date"

    required init(defaults: UserDefaults = .standard, id _: String! = "", title _: String! = "") {
        super.init(defaults: defaults, id: ID, title: TITLE)
    }

    override func checkPasses() -> Bool {
        return appVersion(app: "1Password 7")?.versionCompare("7.8.0") == .orderedDescending
    }
}
