//
//  1Password7.swift
//  Pareto Security
//
//  Created by Janez Troha on 11/11/2021.
//

class App1Password7Check: ParetoCheck {
    static let sharedInstance = App1Password7Check()

    override var UUID: String {
        "541f82b2-db88-588f-9389-a41b81973b45"
    }

    override var TitleON: String {
        "1Password 7 is up-to-date"
    }

    override var TitleOFF: String {
        "1Password 7 has an available update"
    }

    override func checkPasses() -> Bool {
        return appVersion(app: "1Password 7") >= ""
    }
}
