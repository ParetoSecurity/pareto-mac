//
//  ResilioSync.swift
//  Pareto Security
//
//  Created by Janez Troha on 11/11/2021.
//

class AppResilioSyncCheck: ParetoCheck {
    static let sharedInstance = AppResilioSyncCheck()

    override var UUID: String {
        "f778ec37-c113-5ac1-88bc-7aaa843adaf4"
    }

    override var TitleON: String {
        "Resilio Sync is up-to-date"
    }

    override var TitleOFF: String {
        "Resilio Sync has an available update"
    }

    override func checkPasses() -> Bool {
        return appVersion(app: "Resilio Sync") >= ""
    }
}
