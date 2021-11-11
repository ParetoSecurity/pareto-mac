//
//  SublimeText.swift
//  Pareto Security
//
//  Created by Janez Troha on 11/11/2021.
//

class AppSublimeTextCheck: ParetoCheck {
    static let sharedInstance = AppSublimeTextCheck()

    override var UUID: String {
        "6bea9e72-d310-52a6-880d-f05cc925ec66"
    }

    override var TitleON: String {
        "Sublime Text is up-to-date"
    }

    override var TitleOFF: String {
        "Sublime Text has an available update"
    }

    override func checkPasses() -> Bool {
        return appVersion(app: "Sublime Text") >= ""
    }
}
