//
//  NoAdminUser.swift
//  Pareto Security
//
//  Created by Janez Troha on 19/07/2021.
//

class NoAdminUser: ParetoCheck {
    static let sharedInstance = NoAdminUser()
    override var UUID: String {
        "0659aa04-b81f-7cb9-8000-f8e76dc9185a"
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
