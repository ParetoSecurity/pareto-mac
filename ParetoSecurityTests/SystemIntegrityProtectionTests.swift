//
//  SystemIntegrityProtectionTests.swift
//  ParetoSecurityTests
//
//  Created by Roberto Alfieri on 03/11/2026.
//

@testable import Pareto_Security
import XCTest

class SystemIntegrityProtectionTests: XCTestCase {
    func testPassesWhenSIPIsEnabled() {
        let check = SystemIntegrityProtectionCheck(statusProvider: {
            "System Integrity Protection status: enabled."
        })

        XCTAssertTrue(check.checkPasses())
    }

    func testFailsWhenSIPIsDisabled() {
        let check = SystemIntegrityProtectionCheck(statusProvider: {
            "System Integrity Protection status: disabled."
        })

        XCTAssertFalse(check.checkPasses())
    }
}
