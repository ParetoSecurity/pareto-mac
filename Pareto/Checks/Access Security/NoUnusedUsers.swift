//
//  NoUnusedUsers.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/07/2021.
//

import Defaults
import Foundation
import OpenDirectory

class NoUnusedUsers: ParetoCheck {
    static let sharedInstance = NoUnusedUsers()
    override var UUID: String {
        "c6559a48-c7ad-450b-a9eb-765f031ef49e"
    }

    override var TitleON: String {
        "No unused user accounts are present"
    }

    override var TitleOFF: String {
        "Unused user accounts are present"
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
        let ignoredUsers = Defaults[.ignoredUserAccounts]
        return users.filter { u in
            !ignoredUsers.contains(u)
        }
    }

    override var details: String {
        let adminUsers = runCMD(app: "/usr/bin/dscl", args: [".", "-read", "/Groups/admin", "GroupMembership"]).replacingAllMatches(of: "\n", with: "").components(separatedBy: " ")
        let output = runCMD(app: "/usr/bin/dscl", args: [".", "-list", "/Users"]).components(separatedBy: "\n")
        let local = output.filter { u in
            !u.hasPrefix("_") && u.count > 1 && u != "root" && u != "nobody" && u != "daemon"
        }
        let allUnusedUsers = local.filter { u in
            !adminUsers.contains(u)
        }
        let ignoredUsers = Defaults[.ignoredUserAccounts]
        let activeAccounts = accounts

        var detailLines: [String] = []

        if !activeAccounts.isEmpty {
            detailLines.append("Active unused accounts:")
            detailLines.append(contentsOf: activeAccounts.map { "- \($0)" })
        }

        let ignoredButPresent = allUnusedUsers.filter { ignoredUsers.contains($0) }
        if !ignoredButPresent.isEmpty {
            if !detailLines.isEmpty {
                detailLines.append("")
            }
            detailLines.append("Ignored accounts:")
            detailLines.append(contentsOf: ignoredButPresent.map { "- \($0) (ignored)" })
        }

        if detailLines.isEmpty {
            return "None"
        }

        return detailLines.joined(separator: "\n")
    }

    var isAdmin: Bool {
        // Determine if the current user is in the local "admin" group using OpenDirectory
        do {
            let session = ODSession.default()
            let node = try ODNode(session: session, type: UInt32(kODNodeTypeLocalNodes))

            // Fetch the "admin" group record
            let groupQuery = try ODQuery(
                node: node,
                forRecordTypes: kODRecordTypeGroups,
                attribute: kODAttributeTypeRecordName,
                matchType: ODMatchType(kODMatchEqualTo),
                queryValues: "admin",
                returnAttributes: kODAttributeTypeAllAttributes,
                maximumResults: 1
            )

            guard let groups = try groupQuery.resultsAllowingPartial(false) as? [ODRecord],
                  let adminGroup = groups.first
            else {
                return false
            }

            let username = NSUserName()

            // First, check membership by short name
            if let shortNameMembers = try adminGroup.values(forAttribute: kODAttributeTypeGroupMembership) as? [String],
               shortNameMembers.contains(username)
            {
                return true
            }

            // Fallback: check membership by GUID if available
            if let guidMembers = try adminGroup.values(forAttribute: kODAttributeTypeGroupMembers) as? [String] {
                let userQuery = try ODQuery(
                    node: node,
                    forRecordTypes: kODRecordTypeUsers,
                    attribute: kODAttributeTypeRecordName,
                    matchType: ODMatchType(kODMatchEqualTo),
                    queryValues: username,
                    returnAttributes: [kODAttributeTypeGUID],
                    maximumResults: 1
                )

                if let users = try userQuery.resultsAllowingPartial(false) as? [ODRecord],
                   let userRecord = users.first,
                   let guids = try userRecord.values(forAttribute: kODAttributeTypeGUID) as? [String],
                   let guid = guids.first
                {
                    return guidMembers.contains(guid)
                }
            }
        } catch {
            // If OpenDirectory fails for any reason, treat as non-admin
            return false
        }

        return false
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

    override var isRunnable: Bool {
        if teamEnforced {
            return true
        }
        return isActive && isAdmin
    }
}
