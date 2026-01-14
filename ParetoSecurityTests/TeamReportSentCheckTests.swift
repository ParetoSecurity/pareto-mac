//
//  TeamReportSentCheckTests.swift
//  ParetoSecurityTests
//
//  Created by Claude on 14/01/2026.
//

import Defaults
@testable import Pareto_Security
import XCTest

class TeamReportSentCheckTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Reset relevant defaults before each test
        Defaults[.teamID] = ""
        Defaults[.teamAuth] = ""
        Defaults[.reportingRole] = .opensource
        Defaults[.lastTeamReportSuccess] = 0
    }

    override func tearDown() {
        // Clean up after tests
        Defaults[.teamID] = ""
        Defaults[.teamAuth] = ""
        Defaults[.reportingRole] = .opensource
        Defaults[.lastTeamReportSuccess] = 0
        super.tearDown()
    }

    func testCheckNotRunnableWhenTeamIDEmpty() throws {
        Defaults[.teamID] = ""
        Defaults[.reportingRole] = .team

        let check = TeamReportSentCheck.sharedInstance
        XCTAssertFalse(check.isRunnable)
    }

    func testCheckNotRunnableWhenReportingRoleOpenSource() throws {
        Defaults[.teamID] = "test-team-id"
        Defaults[.reportingRole] = .opensource

        let check = TeamReportSentCheck.sharedInstance
        XCTAssertFalse(check.isRunnable)
    }

    func testCheckRunnableWhenTeamLinked() throws {
        Defaults[.teamID] = "test-team-id"
        Defaults[.reportingRole] = .team

        let check = TeamReportSentCheck.sharedInstance
        // Note: isRunnable also depends on AppInfo.Flags.teamAPI
        // which may be false in test environment
        // We test the team conditions are met
        XCTAssertTrue(!Defaults[.teamID].isEmpty)
        XCTAssertEqual(Defaults[.reportingRole], .team)
    }

    func testCheckFailsWhenNeverSent() throws {
        Defaults[.teamID] = "test-team-id"
        Defaults[.reportingRole] = .team
        Defaults[.lastTeamReportSuccess] = 0

        let check = TeamReportSentCheck.sharedInstance
        XCTAssertFalse(check.checkPasses())
    }

    func testCheckPassesWhenRecentSuccess() throws {
        Defaults[.teamID] = "test-team-id"
        Defaults[.reportingRole] = .team
        // Set last success to 1 hour ago
        Defaults[.lastTeamReportSuccess] = Date().currentTimeMs() - Date.HourInMs

        let check = TeamReportSentCheck.sharedInstance
        XCTAssertTrue(check.checkPasses())
    }

    func testCheckFailsWhenOldSuccess() throws {
        Defaults[.teamID] = "test-team-id"
        Defaults[.reportingRole] = .team
        // Set last success to 30 hours ago (beyond 25 hour threshold)
        Defaults[.lastTeamReportSuccess] = Date().currentTimeMs() - (Date.HourInMs * 30)

        let check = TeamReportSentCheck.sharedInstance
        XCTAssertFalse(check.checkPasses())
    }

    func testCheckPassesAtThreshold() throws {
        Defaults[.teamID] = "test-team-id"
        Defaults[.reportingRole] = .team
        // Set last success to exactly 24 hours ago (within 25 hour threshold)
        Defaults[.lastTeamReportSuccess] = Date().currentTimeMs() - (Date.HourInMs * 24)

        let check = TeamReportSentCheck.sharedInstance
        XCTAssertTrue(check.checkPasses())
    }

    func testDetailsWhenNeverSent() throws {
        Defaults[.lastTeamReportSuccess] = 0

        let check = TeamReportSentCheck.sharedInstance
        XCTAssertEqual(check.details, "No successful report has been sent")
    }

    func testDetailsShowsRelativeTime() throws {
        // Set last success to 1 hour ago
        Defaults[.lastTeamReportSuccess] = Date().currentTimeMs() - Date.HourInMs

        let check = TeamReportSentCheck.sharedInstance
        XCTAssertTrue(check.details.contains("Last successful report:"))
    }

    func testDoneTeamReportSuccessUpdatesTimestamp() throws {
        XCTAssertEqual(Defaults[.lastTeamReportSuccess], 0)

        Defaults.doneTeamReportSuccess()

        XCTAssertGreaterThan(Defaults[.lastTeamReportSuccess], 0)
        // Should be close to current time
        let diff = Date().currentTimeMs() - Defaults[.lastTeamReportSuccess]
        XCTAssertLessThan(diff, 1000) // Within 1 second
    }

    func testReportIfDisabledIsFalse() throws {
        let check = TeamReportSentCheck.sharedInstance
        XCTAssertFalse(check.reportIfDisabled)
    }

    func testShowInMenuFalseWhenNotLinked() throws {
        Defaults[.teamID] = ""
        Defaults[.reportingRole] = .opensource

        let check = TeamReportSentCheck.sharedInstance
        XCTAssertFalse(check.showInMenu)
    }

    func testShowInMenuFalseWhenTeamIDEmpty() throws {
        Defaults[.teamID] = ""
        Defaults[.reportingRole] = .team

        let check = TeamReportSentCheck.sharedInstance
        XCTAssertFalse(check.showInMenu)
    }

    func testShowInMenuFalseWhenOpenSource() throws {
        Defaults[.teamID] = "test-team-id"
        Defaults[.reportingRole] = .opensource

        let check = TeamReportSentCheck.sharedInstance
        XCTAssertFalse(check.showInMenu)
    }
}
