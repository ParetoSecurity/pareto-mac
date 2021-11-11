//
//  Signal.swift
//  Pareto Security
//
//  Created by Janez Troha on 11/11/2021.
//

class AppSignalCheck: ParetoCheck {
    static let sharedInstance = AppSignalCheck()

    override var UUID: String {
        "32e31b6a-ffa5-5a34-8825-ea9550513f27"
    }

    override var TitleON: String {
        "Signal is up-to-date"
    }

    override var TitleOFF: String {
        "Signal has an available update"
    }

    override func checkPasses() -> Bool {
        return appVersion(app: "Signal") >= ""
    }
}
