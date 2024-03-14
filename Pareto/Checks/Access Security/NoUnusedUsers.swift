//
//  NoUnusedUsers.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/07/2021.
//

import Foundation

class NoUnusedUsers: ParetoCheck {
    static let sharedInstance = NoUnusedUsers()
    override var UUID: String {
        "c6559a48-c7ad-450b-a9eb-765f031ef49e"
    }

    override var TitleON: String {
        "No unused user accounts are present"
    }

    override var TitleOFF: String {
        "Unused user accounts are present (" + accounts.joined(separator: ",") + ")"
    }

    var accounts: [String] {
        let adminUsers = runCMD(app: "/usr/bin/dscl", args: [".", "-read", "/Groups/admin", "GroupMembership"]).replacingAllMatches(of: "\n", with: "").components(separatedBy: " ")
        let output = runCMD(app: "/usr/bin/dscl", args: [".", "-list", "/Users"]).components(separatedBy: "\n")
        let local = output.filter { u in
            !u.hasPrefix("_") && u.count > 1 && u != "root" && u != "nobody" && u != "daemon"
        }
        let users = local.filter { u in
            !adminUsers.contains(u)
        }
        return users
    }

    var isAdmin: Bool {
        return runCMD(app: "/usr/bin/id", args: ["-Gn"]).components(separatedBy: " ").contains("admin")
    }

    func lastLoginRecent(user: String) -> Bool {
        let output = runCMD(app: "/usr/bin/last", args: ["-w", "-y", user]).components(separatedBy: "\n")
        let log = output.filter { u in
            u.contains(user)
        }

        let entry = log.first?.components(separatedBy: "   ").filter { i in
            i.count > 1
        }
        if (log.first?.contains("still logged in")) != nil {
            return true
        }
        // parse string to date
        if entry?.count ?? 0 > 1 {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX") // Use a POSIX locale
            dateFormatter.dateFormat = "EEE MMM d yyyy HH:mm"

            if let date = dateFormatter.date(from: entry![2]) {
                let currentDate = Date()
                let calendar = Calendar.current

                let components = calendar.dateComponents([.month], from: date, to: currentDate)

                if let monthDifference = components.month, monthDifference <= 1 {
                    return true
                } else {
                    return false
                }
            }
        }

        return false
    }

    override func checkPasses() -> Bool {
        if !isAdmin {
            return accounts.count == 1
        }
        return accounts.allSatisfy { u in
            lastLoginRecent(user: u)
        }
    }
}
