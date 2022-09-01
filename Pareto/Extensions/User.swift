//
//  User.swift
//  Pareto Security
//
//  Created by Janez Troha on 25/08/2022.
//

import Foundation

struct SystemUser {
    static let current = SystemUser()
    var isAdmin: Bool {
        let groups = runCMD(app: "/usr/bin/id", args: ["-Gn", NSUserName()]).components(separatedBy: " ")
        return groups.contains("admin")
    }
}
