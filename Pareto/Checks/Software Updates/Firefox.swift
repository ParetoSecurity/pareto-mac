//
//  Firefox.swift
//  Pareto Security
//
//  Created by Janez Troha on 11/11/2021.
//

class AppFirefoxCheck: ParetoCheck {
    static let sharedInstance = AppFirefoxCheck()

    override var UUID: String {
        "768a574c-75a2-536d-8785-ef9512981184"
    }

    override var TitleON: String {
        "Firefox is up-to-date"
    }

    override var TitleOFF: String {
        "Firefox has an available update"
    }

    override func checkPasses() -> Bool {
        return appVersion(app: "Firefox") >= ""
    }
}
