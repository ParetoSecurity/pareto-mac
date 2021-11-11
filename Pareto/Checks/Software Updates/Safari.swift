//
//  Safari.swift
//  Pareto Security
//
//  Created by Janez Troha on 11/11/2021.
//

class AppSafariCheck: ParetoCheck {
    static let sharedInstance = AppSafariCheck()

    override var UUID: String {
        "f9f3c0ff-8628-5cf0-828e-ca579a3b6ab6"
    }

    override var TitleON: String {
        "Safari is up-to-date"
    }

    override var TitleOFF: String {
        "Safari has an available update"
    }

    override func checkPasses() -> Bool {
        return appVersion(app: "Safari") >= ""
    }
}
