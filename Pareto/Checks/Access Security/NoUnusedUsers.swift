//
//  NoUnusedUsers.swift
//  Pareto Security
//
//  Created by Janez Troha on 15/07/2021.
//

import Darwin
import Defaults
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
        "Unused user accounts are present"
    }

    // MARK: - Public computed properties

    // All non-admin, local, non-ignored user short names
    var accounts: [String] {
        let allUsers = Self.localUserShortNames()
        let adminSet = Self.adminUserShortNames()
        let ignoredUsers = Set(Defaults[.ignoredUserAccounts])

        return allUsers
            .filter { !adminSet.contains($0) }
            .filter { !ignoredUsers.contains($0) }
            .sorted()
    }

    override var details: String {
        let allUsers = Self.localUserShortNames()
        let adminSet = Self.adminUserShortNames()
        let allUnusedUsers = allUsers.filter { !adminSet.contains($0) }.sorted()
        let ignoredUsers = Set(Defaults[.ignoredUserAccounts])
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

    // Current user is member of local admin group (no privileges needed)
    var isAdmin: Bool {
        let username = NSUserName()
        return Self.adminUserShortNames().contains(username)
    }

    // MARK: - Check logic

    override func checkPasses() -> Bool {
        if !isAdmin {
            // For non-admins: pass when there is only one non-admin account (your own)
            return accounts.count == 1
        }

        // For admins (no privileged last-login available): be conservative and fail if any extra non-admin accounts exist
        return accounts.isEmpty
    }
}

// MARK: - Helpers (no admin privileges required)

private extension NoUnusedUsers {
    // Additional name-level filter to exclude system-style accounts by naming convention
    static func isValidUserName(_ u: String) -> Bool {
        return !u.hasPrefix("_") && u.count > 1 && u != "root" && u != "nobody" && u != "daemon"
    }

    // Returns local user short names for “real” users (UID >= 501)
    static func localUserShortNames() -> [String] {
        var result: [String] = []
        setpwent()
        defer { endpwent() }

        while let pw = getpwent() {
            let entry = pw.pointee
            let uid = entry.pw_uid

            // macOS convention: real users start at 501; exclude root/nobody/daemon implicitly
            guard uid >= 501 else { continue }

            if let cName = entry.pw_name {
                let name = String(cString: cName)
                // Extra sanity filtering: skip empty names and system-style names
                if !name.isEmpty, isValidUserName(name) {
                    result.append(name)
                }
            }
        }

        return result
    }

    // Returns set of admin user short names (supplemental members + primary group = admin)
    static func adminUserShortNames() -> Set<String> {
        var admins = Set<String>()

        guard let grpPtr = getgrnam("admin") else {
            return admins
        }

        let group = grpPtr.pointee
        let adminGID = group.gr_gid

        // Supplemental group members (gr_mem is a NULL-terminated array of C strings)
        if var memPtr = group.gr_mem {
            while let cStrPtr = memPtr.pointee {
                let name = String(cString: cStrPtr)
                if !name.isEmpty, isValidUserName(name) {
                    admins.insert(name)
                }
                memPtr = memPtr.advanced(by: 1)
            }
        }

        // Also include users whose primary group is admin
        setpwent()
        defer { endpwent() }

        while let pw = getpwent() {
            let entry = pw.pointee
            guard entry.pw_gid == adminGID else { continue }
            if let cName = entry.pw_name {
                let name = String(cString: cName)
                if !name.isEmpty, isValidUserName(name) {
                    admins.insert(name)
                }
            }
        }

        return admins
    }
}
