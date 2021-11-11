//
//  VisualStudioCode.swift
//  Pareto Security
//
//  Created by Janez Troha on 11/11/2021.
//

class AppVisualStudioCodeCheck: ParetoCheck {
    static let sharedInstance = AppVisualStudioCodeCheck()

    override var UUID: String {
        "6897f662-0a3a-56bc-a06a-82df5a7ee9e4"
    }

    override var TitleON: String {
        "Visual Studio Code is up-to-date"
    }

    override var TitleOFF: String {
        "Visual Studio Code has an available update"
    }

    override func checkPasses() -> Bool {
        return appVersion(app: "Visual Studio Code") >= ""
    }
}
