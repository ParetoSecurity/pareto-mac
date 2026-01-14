//
//  TeamReportSentCheck.swift
//  Pareto Security
//
//  Created by Claude on 14/01/2026.
//

import Defaults
import Foundation
import os.log

class TeamReportSentCheck: ParetoCheck {
    static let sharedInstance = TeamReportSentCheck()

    override var UUID: String {
        "e29dfff7-afe3-4800-8919-74be2d74c3be"
    }

    override var TitleON: String {
        "Pareto Cloud is receiving reports"
    }

    override var TitleOFF: String {
        "Pareto Cloud is not receiving reports"
    }

    // Only show in menu when device is linked to team
    override var showInMenu: Bool {
        return !Defaults[.teamID].isEmpty &&
            Defaults[.reportingRole] == .team &&
            AppInfo.Flags.teamAPI
    }

    override var isRunnable: Bool {
        if !isActive {
            return false
        }
        // Only run when device is linked to team
        return !Defaults[.teamID].isEmpty &&
            Defaults[.reportingRole] == .team &&
            AppInfo.Flags.teamAPI
    }

    // Don't report if disabled (only relevant when team is enabled)
    override var reportIfDisabled: Bool {
        return false
    }

    override func checkPasses() -> Bool {
        let lastSuccess = Defaults[.lastTeamReportSuccess]

        // Never sent successfully
        if lastSuccess == 0 {
            return false
        }

        // Check if last successful report was within 25 hours
        // (allows for 1-hour update cycle + some buffer)
        let threshold = Date.HourInMs * 25
        return lastSuccess + threshold > Date().currentTimeMs()
    }

    override var details: String {
        let lastSuccess = Defaults[.lastTeamReportSuccess]
        if lastSuccess == 0 {
            return "No successful report has been sent"
        }
        let date = Date(timeIntervalSince1970: TimeInterval(lastSuccess) / 1000)
        let formatter = RelativeDateTimeFormatter()
        return "Last successful report: \(formatter.localizedString(for: date, relativeTo: Date()))"
    }
}
