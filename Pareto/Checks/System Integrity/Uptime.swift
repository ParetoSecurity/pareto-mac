//
//  Uptime.swift
//  Pareto Security
//
//  Created by Codex on 18/05/2026.
//

import Foundation

class UptimeCheck: ParetoCheck {
    static let sharedInstance = UptimeCheck()

    let systemUptimeProvider: () -> TimeInterval

    init(systemUptimeProvider: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.systemUptimeProvider = systemUptimeProvider
    }

    override var UUID: String {
        "9ffd4870-4451-48ac-8d1f-09b044f314ba"
    }

    override var TitleON: String {
        "Uptime is less than 14 days"
    }

    override var TitleOFF: String {
        "Uptime is more than 14 days"
    }

    override var details: String {
        "Uptime: \(uptimeDays) days"
    }

    override func checkPasses() -> Bool {
        return uptimeDays < 14
    }

    private var uptimeDays: Int {
        Int(systemUptimeProvider() / TimeInterval(Date.DayInMs / 1000))
    }
}
