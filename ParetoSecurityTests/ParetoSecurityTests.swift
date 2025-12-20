//
//  ParetoSecurityTests.swift
//  ParetoSecurityTests
//
//  Created by Janez Troha on 11/08/2021.
//

import Defaults
@testable import Pareto_Security
import XCTest

class ParetoSecurityTests: XCTestCase {
    func testThatUUIDsAreUnique() throws {
        var uuids: [String] = []
        for claim in Claims.global.all {
            for check in claim.checksSorted {
                if uuids.contains(check.UUID) {
                    XCTFail("Duplicate UUID found \(check.UUID)")
                }
                uuids.append(check.UUID)
            }
        }
    }

    func testAppInfo() throws {
        XCTAssertTrue(AppInfo.bugReportURL().absoluteString.contains("paretosecurity.com"))
    }

    @MainActor
    func testSnooze() throws {
        let handlers = AppHandlers()

        // Reset snooze before testing
        Defaults[.snoozeTime] = 0

        // Tolerance in milliseconds (2 seconds to account for test execution time)
        let tolerance = 2000

        // Expected durations in milliseconds
        let oneHourMs = 3600 * 1000
        let oneDayMs = 3600 * 24 * 1000
        let oneWeekMs = 3600 * 24 * 7 * 1000

        // Test snoozeOneHour
        var beforeTime = Date().currentTimeMs()
        handlers.snoozeOneHour()
        var expectedMin = beforeTime + oneHourMs - tolerance
        var expectedMax = beforeTime + oneHourMs + tolerance
        XCTAssertGreaterThanOrEqual(Defaults[.snoozeTime], expectedMin,
            "snoozeOneHour should set time to approximately 1 hour in the future")
        XCTAssertLessThanOrEqual(Defaults[.snoozeTime], expectedMax,
            "snoozeOneHour should set time to approximately 1 hour in the future")

        // Test snoozeOneDay
        beforeTime = Date().currentTimeMs()
        handlers.snoozeOneDay()
        expectedMin = beforeTime + oneDayMs - tolerance
        expectedMax = beforeTime + oneDayMs + tolerance
        XCTAssertGreaterThanOrEqual(Defaults[.snoozeTime], expectedMin,
            "snoozeOneDay should set time to approximately 24 hours in the future")
        XCTAssertLessThanOrEqual(Defaults[.snoozeTime], expectedMax,
            "snoozeOneDay should set time to approximately 24 hours in the future")

        // Test snoozeOneWeek
        beforeTime = Date().currentTimeMs()
        handlers.snoozeOneWeek()
        expectedMin = beforeTime + oneWeekMs - tolerance
        expectedMax = beforeTime + oneWeekMs + tolerance
        XCTAssertGreaterThanOrEqual(Defaults[.snoozeTime], expectedMin,
            "snoozeOneWeek should set time to approximately 7 days in the future")
        XCTAssertLessThanOrEqual(Defaults[.snoozeTime], expectedMax,
            "snoozeOneWeek should set time to approximately 7 days in the future")

        // Test unsnooze
        handlers.unsnooze()
        XCTAssertEqual(Defaults[.snoozeTime], 0, "unsnooze should reset snooze time to 0")
    }
}
