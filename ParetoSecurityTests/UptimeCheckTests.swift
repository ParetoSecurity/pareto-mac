//
//  UptimeCheckTests.swift
//  ParetoSecurityTests
//
//  Created by Codex on 18/05/2026.
//

@testable import Pareto_Security
import XCTest

class UptimeCheckTests: XCTestCase {
    func testPassesWhenUptimeIsLessThanFourteenDays() {
        let check = UptimeCheck(systemUptimeProvider: { TimeInterval(Date.DayInMs * 13 / 1000) })

        XCTAssertTrue(check.checkPasses())
        XCTAssertEqual(check.details, "Uptime: 13 days")
    }

    func testFailsWhenUptimeIsFourteenDays() {
        let check = UptimeCheck(systemUptimeProvider: { TimeInterval(Date.DayInMs * 14 / 1000) })

        XCTAssertFalse(check.checkPasses())
        XCTAssertEqual(check.details, "Uptime: 14 days")
    }
}
