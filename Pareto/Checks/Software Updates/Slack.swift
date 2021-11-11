//
//  Slack.swift
//  Pareto Security
//
//  Created by Janez Troha on 11/11/2021.
//

class AppSlackCheck: ParetoCheck {
    static let sharedInstance = AppSlackCheck()

    override var UUID: String {
        "9894a05b-964d-5c19-bef7-53112207d271"
    }

    override var TitleON: String {
        "Slack is up-to-date"
    }

    override var TitleOFF: String {
        "Slack has an available update"
    }

    override func checkPasses() -> Bool {
        return appVersion(app: "Slack") >= ""
    }
}
