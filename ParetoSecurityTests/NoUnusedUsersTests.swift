//
//  NoUnusedUsersTests.swift
//  ParetoSecurityTests
//
//  Created by Janez Troha on 26/06/2025.
//

import XCTest
import Foundation
import Defaults
@testable import Pareto_Security

// Testable subclass of NoUnusedUsers to mock dependencies
class TestableNoUnusedUsers: NoUnusedUsers {
    var mockRunCMDOutput: [String: String] = [:]
    var mockIsAdmin: Bool = false
    var mockLastLoginRecent: [String: Bool] = [:]

    func runCMD(app: String, args: [String]) -> String {
        let command = "\(app) \(args.joined(separator: " "))"
        return mockRunCMDOutput[command] ?? ""
    }

    override var isAdmin: Bool {
        return mockIsAdmin
    }

    override func lastLoginRecent(user: String) -> Bool {
        return mockLastLoginRecent[user] ?? false
    }
}

class NoUnusedUsersTests: XCTestCase {

    var userDefaults: UserDefaults!
    var noUnusedUsersCheck: TestableNoUnusedUsers!

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: "debug-paretosecurity")
        userDefaults.removePersistentDomain(forName: "debug-paretosecurity")

        noUnusedUsersCheck = TestableNoUnusedUsers()
        noUnusedUsersCheck.configure() // Ensure defaults are registered
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: "debug-paretosecurity")
        super.tearDown()
    }

    func testUUID() {
        XCTAssertEqual(noUnusedUsersCheck.UUID, "c6559a48-c7ad-450b-a9eb-765f031ef49e")
    }

    func testTitles() {
        XCTAssertEqual(noUnusedUsersCheck.TitleON, "No unused user accounts are present")
        XCTAssertEqual(noUnusedUsersCheck.TitleOFF, "Unused user accounts are present")
    }

    func testAccounts() {
        noUnusedUsersCheck.mockRunCMDOutput["/usr/bin/dscl . -read /Groups/admin GroupMembership"] = "GroupMembership: root user1 user2"
        noUnusedUsersCheck.mockRunCMDOutput["/usr/bin/dscl . -list /Users"] = "_user1\n_user2\nroot\nnobody\ndaemon\nuser1\nuser2\nuser3\nuser4"

        let expectedAccounts = ["user3", "user4"]
        XCTAssertEqual(noUnusedUsersCheck.accounts, expectedAccounts)
    }

    func testDetails() {
        noUnusedUsersCheck.mockRunCMDOutput["/usr/bin/dscl . -read /Groups/admin GroupMembership"] = "GroupMembership: root user1"
        noUnusedUsersCheck.mockRunCMDOutput["/usr/bin/dscl . -list /Users"] = "_user1\nroot\nuser1\nuser2"

        // Test with unused accounts
        let expectedDetails = "- user2"
        XCTAssertEqual(noUnusedUsersCheck.details, expectedDetails)

        // Test with no unused accounts
        noUnusedUsersCheck.mockRunCMDOutput["/usr/bin/dscl . -list /Users"] = "_user1\nroot\nuser1"
        XCTAssertEqual(noUnusedUsersCheck.details, "None")
    }

    func testIsAdmin() {
        noUnusedUsersCheck.mockRunCMDOutput["/usr/bin/id -Gn"] = "staff admin _lpoperator"
        noUnusedUsersCheck.mockIsAdmin = true
        XCTAssertTrue(noUnusedUsersCheck.isAdmin)

        noUnusedUsersCheck.mockRunCMDOutput["/usr/bin/id -Gn"] = "staff _lpoperator"
        noUnusedUsersCheck.mockIsAdmin = false
        XCTAssertFalse(noUnusedUsersCheck.isAdmin)
    }

    func testIsRunnable() {
        noUnusedUsersCheck.isActive = true
        noUnusedUsersCheck.mockIsAdmin = true
        XCTAssertTrue(noUnusedUsersCheck.isRunnable)

        noUnusedUsersCheck.isActive = false
        noUnusedUsersCheck.mockIsAdmin = true
        XCTAssertFalse(noUnusedUsersCheck.isRunnable)

        noUnusedUsersCheck.isActive = true
        noUnusedUsersCheck.mockIsAdmin = false
        XCTAssertFalse(noUnusedUsersCheck.isRunnable)
    }

    func testCheckPasses_notAdmin_oneAccount() {
        noUnusedUsersCheck.mockIsAdmin = false
        noUnusedUsersCheck.mockRunCMDOutput["/usr/bin/dscl . -read /Groups/admin GroupMembership"] = "GroupMembership: root"
        noUnusedUsersCheck.mockRunCMDOutput["/usr/bin/dscl . -list /Users"] = "_user1\nroot\nuser1"
        XCTAssertTrue(noUnusedUsersCheck.checkPasses())
    }

    func testCheckPasses_notAdmin_multipleAccounts() {
        noUnusedUsersCheck.mockIsAdmin = false
        noUnusedUsersCheck.mockRunCMDOutput["/usr/bin/dscl . -read /Groups/admin GroupMembership"] = "GroupMembership: root"
        noUnusedUsersCheck.mockRunCMDOutput["/usr/bin/dscl . -list /Users"] = "_user1\nroot\nuser1\nuser2"
        XCTAssertFalse(noUnusedUsersCheck.checkPasses())
    }

    func testCheckPasses_isAdmin_allRecent() {
        noUnusedUsersCheck.mockIsAdmin = true
        noUnusedUsersCheck.mockRunCMDOutput["/usr/bin/dscl . -read /Groups/admin GroupMembership"] = "GroupMembership: root adminUser1 adminUser2"
        noUnusedUsersCheck.mockRunCMDOutput["/usr/bin/dscl . -list /Users"] = "_user1\nroot\nadminUser1\nadminUser2"
        noUnusedUsersCheck.mockLastLoginRecent["adminUser1"] = true
        noUnusedUsersCheck.mockLastLoginRecent["adminUser2"] = true
        XCTAssertTrue(noUnusedUsersCheck.checkPasses())
    }

    func testCheckPasses_isAdmin_someNotRecent() {
        noUnusedUsersCheck.mockIsAdmin = true
        noUnusedUsersCheck.mockRunCMDOutput["/usr/bin/dscl . -read /Groups/admin GroupMembership"] = "GroupMembership: root adminUser1 adminUser2"
        noUnusedUsersCheck.mockRunCMDOutput["/usr/bin/dscl . -list /Users"] = "_user1\nroot\nadminUser1\nadminUser2"
        noUnusedUsersCheck.mockLastLoginRecent["adminUser1"] = true
        noUnusedUsersCheck.mockLastLoginRecent["adminUser2"] = false
        XCTAssertFalse(noUnusedUsersCheck.checkPasses())
    }
}
