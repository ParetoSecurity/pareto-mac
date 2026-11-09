//
//  HelperAuthorizationTests.swift
//  ParetoSecurityTests
//
//  Created by Janez Troha on 07/11/2026.
//

@testable import Pareto_Security
import XCTest

private class HelperGatedCheck: IntegrationCheck {
    override var requiresHelper: Bool {
        true
    }

    override var isRunnable: Bool {
        false
    }
}

class HelperAuthorizationTests: XCTestCase {
    func testMenuOpensAuthorizationWhenHelperMissing() {
        let check = HelperGatedCheck()
        check.configure()
        check.isActive = true
        XCTAssertTrue(check.needsHelperAuthorization)
        XCTAssertEqual(check.menu().action, #selector(ParetoCheck.authorizeHelper))
        XCTAssertTrue(check.infoURL.path.contains("privileged-helper-authorization"))
    }

    func testMenuOpensInfoWhenHelperNotNeeded() {
        let check = IntegrationCheck()
        check.configure()
        check.isActive = true
        XCTAssertFalse(check.needsHelperAuthorization)
        XCTAssertEqual(check.menu().action, #selector(ParetoCheck.moreInfo))
    }

    func testInactiveCheckDoesNotAskForAuthorization() {
        let check = HelperGatedCheck()
        check.configure()
        check.isActive = false
        XCTAssertFalse(check.needsHelperAuthorization)
    }
}
