//
//  Docker.swift
//  Pareto Security
//
//  Created by Janez Troha on 11/11/2021.
//

class AppDockerCheck: ParetoCheck {
    static let sharedInstance = AppDockerCheck()

    override var UUID: String {
        "ee11fe36-a372-5cba-a1b4-151748fc2fa7"
    }

    override var TitleON: String {
        "Docker is up-to-date"
    }

    override var TitleOFF: String {
        "Docker has an available update"
    }

    override func checkPasses() -> Bool {
        return appVersion(app: "Docker") >= ""
    }
}
