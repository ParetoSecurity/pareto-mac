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

    // All non-admin, local, non-ignored user short names with no recent login
    var accounts: [String] {
        let allUsers = Self.localUserShortNames()
        let adminSet = Self.adminUserShortNames()
        let ignoredUsers = Set(Defaults[.ignoredUserAccounts])

        let thresholdDays = Self.recentLoginDays
        let cutoff = Date().addingTimeInterval(-TimeInterval(thresholdDays) * 24 * 60 * 60)

        return allUsers
            .filter { !adminSet.contains($0) }
            .filter { !ignoredUsers.contains($0) }
            // Keep only users that have NOT logged in recently (or have no record)
            .filter { username in
                guard let last = Self.lastLoginDate(for: username) else {
                    // No login record -> treat as unused (include)
                    return true
                }
                // Include only if last login is older than cutoff
                return last < cutoff
            }
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
    // Threshold for "recent" login
    static let recentLoginDays: Int = 7

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

    // MARK: - Recent login detection via `last`

    // Returns the last login date for a user, if any, using /usr/bin/last -1 <user>
    static func lastLoginDate(for user: String) -> Date? {
        let output = runCMD(app: "/usr/bin/last", args: ["-1", user])

        // The `last` command prints nothing useful if there is no entry for the user,
        // or it may include lines like "wtmp begins ..." but not a user line.
        // We look for a line that begins with the username (allowing spaces after).
        guard let line = output
            .components(separatedBy: CharacterSet.newlines)
            .first(where: { $0.hasPrefix(user + " ") || $0.hasPrefix(user + "\t") })
        else {
            return nil
        }

        // Extract a date/time substring like: "Sep 11 10:23" and optional year "Sep 11 10:23 2024"
        // Example line:
        // janez    console  Wed Sep 11 10:23   - 11:00  (00:37)
        // or with year if not current: ... Sep 11 10:23 2024
        guard let dateString = extractDateSubstring(from: line) else {
            return nil
        }

        // Try parse with year first, then without
        let posix = Locale(identifier: "en_US_POSIX")
        let tz = TimeZone.current

        let fmtWithYear = DateFormatter()
        fmtWithYear.locale = posix
        fmtWithYear.timeZone = tz
        fmtWithYear.dateFormat = "MMM d HH:mm yyyy"

        let fmtNoYear = DateFormatter()
        fmtNoYear.locale = posix
        fmtNoYear.timeZone = tz
        fmtNoYear.dateFormat = "MMM d HH:mm"

        if let dt = fmtWithYear.date(from: dateString) {
            return dt
        }

        if let partial = fmtNoYear.date(from: dateString) {
            // If no year in the string, assume current year; if that ends up in the future (e.g., Dec when today is Jan), subtract one year.
            let cal = Calendar(identifier: .gregorian)
            var comps = cal.dateComponents([.month, .day, .hour, .minute], from: partial)
            comps.year = cal.component(.year, from: Date())
            if let assumed = cal.date(from: comps) {
                if assumed > Date() {
                    if let adjusted = cal.date(byAdding: .year, value: -1, to: assumed) {
                        return adjusted
                    }
                }
                return assumed
            }
        }

        return nil
    }

    // Pull out "MMM d HH:mm" optionally followed by " yyyy"
    static func extractDateSubstring(from line: String) -> String? {
        // Regex for month names and time, with optional year
        // (Jan|Feb|...|Dec) <space> 1-2 digit day (allow extra space), space, HH:MM, optional space+YYYY
        let pattern = #"(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{1,2}\s+\d{2}:\d{2}(?:\s+\d{4})?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }
        let range = NSRange(line.startIndex ..< line.endIndex, in: line)
        if let match = regex.firstMatch(in: line, options: [], range: range) {
            if let r = Range(match.range, in: line) {
                return String(line[r])
            }
        }
        return nil
    }
}
