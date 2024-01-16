//
//  NoAdminUser.swift
//  Pareto Security
//
//  Created by Janez Troha on 19/07/2021.
//

class NoAdminUser: ParetoCheck {
    static let sharedInstance = NoAdminUser()
    override var UUID: String {
        "b092ab27-c513-43cc-8b52-e89c4cb30114"
    }

    override var TitleON: String {
        "Current user is not admin"
    }

    override var TitleOFF: String {
        "Current user is admin"
    }

    var isAdmin: Bool {
        return runCMD(app: "/usr/bin/id", args: ["-Gn"]).components(separatedBy: " ").contains("admin")
    }

    override func checkPasses() -> Bool {
        return !isAdmin
    }
}
