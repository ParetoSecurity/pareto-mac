//
//  zoomus.swift
//  Pareto Security
//
//  Created by Janez Troha on 11/11/2021.
//

class AppzoomusCheck: ParetoCheck {
    static let sharedInstance = AppzoomusCheck()

    override var UUID: String {
        "4bf0249e-ba30-55ab-ab3a-7b58fdd40401"
    }

    override var TitleON: String {
        "zoom.us is up-to-date"
    }

    override var TitleOFF: String {
        "zoom.us has an available update"
    }

    override func checkPasses() -> Bool {
        return appVersion(app: "zoom.us") >= ""
    }
}
