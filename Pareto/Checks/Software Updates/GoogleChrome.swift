//
//  GoogleChrome.swift
//  Pareto Security
//
//  Created by Janez Troha on 11/11/2021.
//

class AppGoogleChromeCheck: ParetoCheck {
    static let sharedInstance = AppGoogleChromeCheck()

    override var UUID: String {
        "d34ee340-67a7-5e3e-be8b-aef4e3133de0"
    }

    override var TitleON: String {
        "Google Chrome is up-to-date"
    }

    override var TitleOFF: String {
        "Google Chrome has an available update"
    }

    override func checkPasses() -> Bool {
        return appVersion(app: "Google Chrome") >= ""
    }
}
