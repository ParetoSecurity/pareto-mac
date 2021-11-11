//
//  Dropbox.swift
//  Pareto Security
//
//  Created by Janez Troha on 11/11/2021.
//

class AppDropboxCheck: ParetoCheck {
    static let sharedInstance = AppDropboxCheck()

    override var UUID: String {
        "ec78ce1b-2c3b-5bb7-93ae-dcfaf15cd2cd"
    }

    override var TitleON: String {
        "Dropbox is up-to-date"
    }

    override var TitleOFF: String {
        "Dropbox has an available update"
    }

    override func checkPasses() -> Bool {
        return appVersion(app: "Dropbox") >= ""
    }
}
