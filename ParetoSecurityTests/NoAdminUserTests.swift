
//
//  NoAdminUserTests.swift
//  ParetoSecurityTests
//
//  Created by Janez Troha on 26/06/2025.
//

import XCTest
import Foundation
import Defaults
@testable import Pareto_Security

// Testable subclass of NoAdminUser to mock dependencies
class TestableNoAdminUser: NoAdminUser {
    var mockIsAdmin: Bool = false

    override var isAdmin: Bool {
        return mockIsAdmin
    }
}

class NoAdminUserTests: XCTestCase {

    var userDefaults: UserDefaults!
    var noAdminUserCheck: TestableNoAdminUser!

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: "debug-paretosecurity")
        userDefaults.removePersistentDomain(forName: "debug-paretosecurity")

        noAdminUserCheck = TestableNoAdminUser()
        noAdminUserCheck.configure() // Ensure defaults are registered
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: "debug-paretosecurity")
        super.tearDown()
    }

    func testUUID() {
        XCTAssertEqual(noAdminUserCheck.UUID, "b092ab27-c513-43cc-8b52-e89c4cb30114")
    }

    func testTitles() {
        XCTAssertEqual(noAdminUserCheck.TitleON, "Current user is not admin")
        XCTAssertEqual(noAdminUserCheck.TitleOFF, "Current user is admin")
    }

    func testCheckPasses_notAdmin() {
        noAdminUserCheck.mockIsAdmin = false
        XCTAssertTrue(noAdminUserCheck.checkPasses())
    }

    func testCheckPasses_isAdmin() {
        noAdminUserCheck.mockIsAdmin = true
        XCTAssertFalse(noAdminUserCheck.checkPasses())
    }
}
