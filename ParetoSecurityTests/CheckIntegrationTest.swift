//
//  CheckIntegrationTest.swift
//  CheckIntegrationTest
//
//  Created by Janez Troha on 12/08/2021.
//

@testable import Pareto_Security
import XCTest

class CheckIntegrationTest: XCTestCase {
    func testInit() {
        let check = IntegrationCheck()
        check.configure()
        XCTAssertEqual(check.UUID, "aaaaaaaa-bbbb-cccc-dddd-abcdef123456")

        // Ensure keys are not changed without migration
        XCTAssertEqual(check.PassesKey, "ParetoCheck-aaaaaaaa-bbbb-cccc-dddd-abcdef123456-Passes")
        XCTAssertEqual(check.EnabledKey, "ParetoCheck-aaaaaaaa-bbbb-cccc-dddd-abcdef123456-Enabled")
        XCTAssertEqual(check.TimestampKey, "ParetoCheck-aaaaaaaa-bbbb-cccc-dddd-abcdef123456-TS")
    }

    func testCheckPasses() {
        let check = IntegrationCheck()
        XCTAssertTrue(check.checkPasses())
    }

    func testClaimLogic() {
        let claim = Claim(withTitle: "Test", withChecks: [IntegrationCheck(), IntegrationCheckFails()])
        claim.configure()
        claim.run()
        XCTAssertEqual(claim.checks.count, 2)
        XCTAssertFalse(claim.checksPassed)
        XCTAssertNotEqual(claim.menu(), nil)
    }
}
