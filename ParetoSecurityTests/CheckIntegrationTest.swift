//
//  CheckIntegrationTest.swift
//  CheckIntegrationTest
//
//  Created by Janez Troha on 12/08/2021.
//

@testable import Pareto_Security
import XCTest

class CheckIntegrationTest: XCTestCase {
    override class func setUp() {
        super.setUp()
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
    }

    func testInit() throws {
        let check = IntegrationCheck()
        XCTAssertEqual(check.UUID, "aaaaaaaa-bbbb-cccc-dddd-abcdef123456")
        XCTAssertEqual(check.Title, "Unit test mock")

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

    func testSnooze() throws {
        let claim = Claim(withTitle: "Test", withChecks: [IntegrationCheck()])
        claim.snoozeOneDay()
        XCTAssertEqual(claim.snoozeTime, 3600 * 24)
        claim.snoozeOneHour()
        XCTAssertEqual(claim.snoozeTime, 3600)
        claim.snoozeOneWeek()
        XCTAssertEqual(claim.snoozeTime, 3600 * 24 * 7)
        claim.unsnooze()
        XCTAssertEqual(claim.snoozeTime, 0)
    }

    func testDisableAndEnable() throws {
        let claim = Claim(withTitle: "Test", withChecks: [IntegrationCheck()])
        claim.disableCheck()
        XCTAssertEqual(claim.isActive, false)
        claim.enableCheck()
        XCTAssertEqual(claim.isActive, true)
    }

    func testThatInactiveCheckDoesNotRun() throws {
        let claim = Claim(withTitle: "Test", withChecks: [IntegrationCheck()])
        claim.disableCheck()
        claim.run()
        XCTAssert(!check.checkPassed, "Check should not run if disabled")
    }

    func testThatActiveCheckDoesRun() throws {
        let claim = Claim(withTitle: "Test", withChecks: [IntegrationCheck()])
        claim.enableCheck()
        claim.run()
        XCTAssert(check.checkPassed, "Check after run should pass")
    }
}
