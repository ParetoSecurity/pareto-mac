
//
//  ParetoCheckTests.swift
//  ParetoSecurityTests
//
//  Created by Janez Troha on 26/06/2025.
//

import XCTest
import Foundation
import Defaults
@testable import Pareto_Security

class ParetoCheckTests: XCTestCase {

    var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: "test_suite")
        userDefaults.removePersistentDomain(forName: "test_suite") // Clear before each test
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: "test_suite") // Clear after each test
        super.tearDown()
    }

    // Mock subclass for ParetoCheck to implement checkPasses()
    class MockParetoCheck: ParetoCheck {
        var mockCheckPassesResult: Bool = true

        init(uuid: String = "MockCheckUUID", titleON: String = "Mock Check ON", titleOFF: String = "Mock Check OFF", requiresHelper: Bool = false, isRunnable: Bool = true) {
            super.init()
            self.UUID = uuid
            self.TitleON = titleON
            self.TitleOFF = titleOFF
            self.requiresHelper = requiresHelper
            self.isRunnable = isRunnable
        }

        override func checkPasses() -> Bool {
            return mockCheckPassesResult
        }
    }

    func testIsActive() {
        let check = MockParetoCheck()
        check.configure() // Register defaults

        // Test default value
        XCTAssertTrue(check.isActive)

        // Test setting to false
        check.isActive = false
        XCTAssertFalse(check.isActive)

        // Test setting to true
        check.isActive = true
        XCTAssertTrue(check.isActive)
    }

    func testCheckPassed() {
        let check = MockParetoCheck()
        check.configure() // Register defaults

        // Test default value
        XCTAssertFalse(check.checkPassed)

        // Test setting to true
        check.checkPassed = true
        XCTAssertTrue(check.checkPassed)

        // Test setting to false
        check.checkPassed = false
        XCTAssertFalse(check.checkPassed)
    }

    func testCheckTimestamp() {
        let check = MockParetoCheck()
        check.configure() // Register defaults

        // Test default value
        XCTAssertEqual(check.checkTimestamp, 0)

        // Test setting timestamp
        let timestamp = 123456789
        check.checkTimestamp = timestamp
        XCTAssertEqual(check.checkTimestamp, timestamp)
    }

    func testRunMethod() {
        let check = MockParetoCheck()
        check.configure() // Register defaults
        check.isActive = true // Ensure it's active to run

        // Test when checkPasses returns true
        check.mockCheckPassesResult = true
        let resultTrue = check.run()
        XCTAssertTrue(resultTrue)
        XCTAssertTrue(check.checkPassed)
        XCTAssertGreaterThan(check.checkTimestamp, 0)

        // Test when checkPasses returns false
        check.mockCheckPassesResult = false
        let resultFalse = check.run()
        XCTAssertFalse(resultFalse)
        XCTAssertFalse(check.checkPassed)
        XCTAssertGreaterThan(check.checkTimestamp, 0) // Timestamp should still be updated
    }

    func testIsRunnableCached() {
        let check = MockParetoCheck()
        check.configure() // Register defaults
        check.isActive = true // Ensure it's active

        // First call, should compute and cache
        let firstRun = check.isRunnableCached()
        XCTAssertTrue(firstRun)

        // Change isActive, but cached value should still be returned
        check.isActive = false
        let secondRun = check.isRunnableCached()
        XCTAssertTrue(secondRun) // Still true due to cache

        // To test cache invalidation, we need to simulate time passing or directly invalidate
        // Since cachedIsRunnableTimestamp is private, we cannot directly manipulate it.
        // We will rely on the fact that a new instance of MockParetoCheck will have an invalidated cache.
    }

    func testInfoURL() {
        let check = MockParetoCheck(uuid: "MockCheckUUID", requiresHelper: false, isRunnable: true) // Default case
        check.configure()
        check.isActive = true

        // Test default infoURL
        let defaultURL = check.infoURL
        XCTAssertTrue(defaultURL.absoluteString.contains("paretosecurity.com/check/MockCheckUUID"))
        XCTAssertTrue(defaultURL.absoluteString.contains("details=None"))
        XCTAssertTrue(defaultURL.absoluteString.contains("utm_source="))

        // Test infoURL when requiresHelper and isActive is true, but isRunnable is false
        let helperCheck = MockParetoCheck(uuid: "MockCheckUUID", requiresHelper: true, isRunnable: false)
        helperCheck.configure()
        helperCheck.isActive = true // Active, but helper not authorized (simulated by isRunnable returning false)

        let helperURL = helperCheck.infoURL
        XCTAssertTrue(helperURL.absoluteString.contains("paretosecurity.com/docs/mac/privileged-helper-authorization"))
        XCTAssertTrue(helperURL.absoluteString.contains("utm_source="))
    }
}
