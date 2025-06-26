
//
//  PasswordManagerTests.swift
//  ParetoSecurityTests
//
//  Created by Janez Troha on 26/06/2025.
//

import XCTest
import Foundation
import Defaults
@testable import Pareto_Security

// Testable subclass of PasswordManager to mock dependencies
class TestablePasswordManager: PasswordManager {
    var mockCheckInstalledApplicationsResult: Bool = false
    var mockCheckForBrowserExtensionsResult: Bool = false

    func checkInstalledApplications() -> Bool {
        return mockCheckInstalledApplicationsResult
    }

    func checkForBrowserExtensions() -> Bool {
        return mockCheckForBrowserExtensionsResult
    }
}

class PasswordManagerTests: XCTestCase {

    var userDefaults: UserDefaults!
    var passwordManagerCheck: TestablePasswordManager!

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: "debug-paretosecurity")
        userDefaults.removePersistentDomain(forName: "debug-paretosecurity")

        passwordManagerCheck = TestablePasswordManager()
        passwordManagerCheck.configure() // Ensure defaults are registered
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: "debug-paretosecurity")
        super.tearDown()
    }

    func testUUID() {
        XCTAssertEqual(passwordManagerCheck.UUID, "f962c423-fdf5-428a-a57a-827abc9b253e")
    }

    func testTitles() {
        XCTAssertEqual(passwordManagerCheck.TitleON, "Password manager is installed")
        XCTAssertEqual(passwordManagerCheck.TitleOFF, "Password manager is not installed")
    }

    func testCheckPasses_noManager() {
        passwordManagerCheck.mockCheckInstalledApplicationsResult = false
        passwordManagerCheck.mockCheckForBrowserExtensionsResult = false
        XCTAssertFalse(passwordManagerCheck.checkPasses())
    }

    func testCheckPasses_applicationInstalled() {
        passwordManagerCheck.mockCheckInstalledApplicationsResult = true
        passwordManagerCheck.mockCheckForBrowserExtensionsResult = false
        XCTAssertTrue(passwordManagerCheck.checkPasses())
    }

    func testCheckPasses_extensionInstalled() {
        passwordManagerCheck.mockCheckInstalledApplicationsResult = false
        passwordManagerCheck.mockCheckForBrowserExtensionsResult = true
        XCTAssertTrue(passwordManagerCheck.checkPasses())
    }

    func testCheckPasses_bothInstalled() {
        passwordManagerCheck.mockCheckInstalledApplicationsResult = true
        passwordManagerCheck.mockCheckForBrowserExtensionsResult = true
        XCTAssertTrue(passwordManagerCheck.checkPasses())
    }
}
