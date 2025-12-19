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

        handlers.snoozeOneDay()
        XCTAssertGreaterThan(Defaults[.snoozeTime], 0)

        handlers.snoozeOneHour()
        XCTAssertGreaterThan(Defaults[.snoozeTime], 0)

        handlers.snoozeOneWeek()
        XCTAssertGreaterThan(Defaults[.snoozeTime], 0)

        handlers.unsnooze()
        XCTAssertEqual(Defaults[.snoozeTime], 0)
    }
}
