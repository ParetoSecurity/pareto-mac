//
//  GateKeeper.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/07/2021.
//
import Foundation
import os.log

class ZoomCheck: ParetoCheck {
    final var ID = "1ee63d54-875c-4e72-aca2-81517d0c9e20"
    final var TITLE = "Zoom is up-to-date"

    required init(defaults: UserDefaults = .standard, id _: String! = "", title _: String! = "") {
        super.init(defaults: defaults, id: ID, title: TITLE)
    }

    override func checkPasses() -> Bool {
        return self.appVersion(app: "Zoom")?.versionCompare("1.0.0") == .orderedAscending
    }
}
