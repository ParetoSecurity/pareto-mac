//
//  CheckIntegrationTest.swift
//  CheckIntegrationTest
//
//  Created by Janez Troha on 12/08/2021.
//

@testable import Pareto_Security
import XCTest

class CheckIntegrationTest: XCTestCase {
    func testInit() throws {
        let check = IntegrationCheck()
        XCTAssertEqual(check.UUID, "aaaaaaaa-bbbb-cccc-dddd-abcdef123456")
        XCTAssertEqual(check.TITLE, "Unit test mock")

        // Ensure keys are not changed without migration
        XCTAssertEqual(check.PassesKey, "aaaaaaaa-bbbb-cccc-dddd-abcdef123456-Passes")
        XCTAssertEqual(check.SnoozeKey, "aaaaaaaa-bbbb-cccc-dddd-abcdef123456-Snooze")
        XCTAssertEqual(check.EnabledKey, "aaaaaaaa-bbbb-cccc-dddd-abcdef123456-Enabled")
        XCTAssertEqual(check.TimestampKey, "aaaaaaaa-bbbb-cccc-dddd-abcdef123456-TS")
    }

    func testCheckPasses() throws {
        let check = IntegrationCheck()
        XCTAssert(check.checkPasses())
    }

    func testObservables() throws {
        let check = IntegrationCheck()
        XCTAssertEqual(check.isActive, true, "New check should be enabled")
        XCTAssertEqual(check.snoozeTime, 0, "New check should not be snoozed")
        XCTAssertEqual(check.checkPassed, false, "New check should not pass if not ran yet")
        XCTAssertEqual(check.checkTimestamp, 0, "New check should not have timestamp if not ran yet")
    }

    func testSnooze() throws {
        let check = IntegrationCheck()
        check.snoozeOneDay()
        XCTAssertEqual(check.snoozeTime, 3600 * 24)
        check.snoozeOneHour()
        XCTAssertEqual(check.snoozeTime, 3600)
        check.snoozeOneWeek()
        XCTAssertEqual(check.snoozeTime, 3600 * 24 * 7)
        check.unsnooze()
        XCTAssertEqual(check.snoozeTime, 0)
    }

    func testDisableAndEnable() throws {
        let check = IntegrationCheck()
        check.disableCheck()
        XCTAssertEqual(check.isActive, false)
        check.enableCheck()
        XCTAssertEqual(check.isActive, true)
    }

    func testThatInactiveCheckDoesNotRun() throws {
        let check = IntegrationCheck()
        check.disableCheck()
        check.run()
        XCTAssertEqual(check.checkTimestamp, 0, "Check should not have timestamp if not ran yet")
    }

    func testThatActiveCheckDoesRun() throws {
        let check = IntegrationCheck()
        check.disableCheck()
        check.run()
        XCTAssert(check.checkTimestamp > 0)
    }
}
