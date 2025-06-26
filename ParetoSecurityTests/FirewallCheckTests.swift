
//
//  FirewallCheckTests.swift
//  ParetoSecurityTests
//
//  Created by Janez Troha on 26/06/2025.
//

import XCTest
import Foundation
import Defaults
@testable import Pareto_Security

// Testable subclass of FirewallCheck to mock dependencies
class TestableFirewallCheck: FirewallCheck {
    var mockIsActive: Bool = true
    var mockHelperIsInstalled: Bool = true
    var mockEnsureHelperIsUpToDateResult: Bool = true
    var mockIsFirewallEnabledResult: Bool = false
    var mockReadDefaultsFileResult: NSDictionary? = nil

    override var isRunnable: Bool {
        if !mockIsActive {
            return false
        }
        if #available(macOS 15, *) {
            if requiresHelper {
                return mockHelperIsInstalled
            }
        }
        return true
    }

    override func checkPasses() -> Bool {
        if #available(macOS 15, *) {
            return mockIsFirewallEnabledResult
        }
        // Mock readDefaultsFile for older macOS
        if let globalstate = mockReadDefaultsFileResult?.value(forKey: "globalstate") as? Int {
            return globalstate >= 1
        }
        return false
    }

    // Override readDefaultsFile to return mock data
    func mockReadDefaultsFile(path: String) -> NSDictionary? {
        return mockReadDefaultsFileResult
    }
}

class FirewallCheckTests: XCTestCase {

    var userDefaults: UserDefaults!
    var firewallCheck: TestableFirewallCheck!

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: "debug-paretosecurity")
        userDefaults.removePersistentDomain(forName: "debug-paretosecurity")

        firewallCheck = TestableFirewallCheck()
        firewallCheck.configure() // Ensure defaults are registered
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: "debug-paretosecurity")
        super.tearDown()
    }

    func testUUID() {
        XCTAssertEqual(firewallCheck.UUID, "2e46c89a-5461-4865-a92e-3b799c12034a")
    }

    func testTitles() {
        XCTAssertEqual(firewallCheck.TitleON, "Firewall is on")
        XCTAssertEqual(firewallCheck.TitleOFF, "Firewall is off")
    }

    func testIsCritical() {
        XCTAssertTrue(firewallCheck.isCritical)
    }

    func testRequiresHelper() {
        if #available(macOS 15, *) {
            XCTAssertTrue(firewallCheck.requiresHelper)
        } else {
            XCTAssertFalse(firewallCheck.requiresHelper)
        }
    }

    func testIsRunnable_activeCheck_helperInstalled() {
        firewallCheck.mockIsActive = true
        firewallCheck.mockHelperIsInstalled = true
        XCTAssertTrue(firewallCheck.isRunnable)
    }

    func testIsRunnable_inactiveCheck() {
        firewallCheck.mockIsActive = false
        firewallCheck.mockHelperIsInstalled = true
        XCTAssertFalse(firewallCheck.isRunnable)
    }

    func testIsRunnable_macOS15AndAbove_helperNotInstalled() {
        if #available(macOS 15, *) {
            firewallCheck.mockIsActive = true
            firewallCheck.mockHelperIsInstalled = false
            XCTAssertFalse(firewallCheck.isRunnable)
        }
    }

    func testCheckPasses_macOS15AndAbove_enabled() {
        if #available(macOS 15, *) {
            firewallCheck.mockIsFirewallEnabledResult = true
            XCTAssertTrue(firewallCheck.checkPasses())
        }
    }

    func testCheckPasses_macOS15AndAbove_disabled() {
        if #available(macOS 15, *) {
            firewallCheck.mockIsFirewallEnabledResult = false
            XCTAssertFalse(firewallCheck.checkPasses())
        }
    }

    func testCheckPasses_macOSOlder_enabled() {
        if #unavailable(macOS 15) {
            firewallCheck.mockReadDefaultsFileResult = ["globalstate": 1] as NSDictionary
            XCTAssertTrue(firewallCheck.checkPasses())

            firewallCheck.mockReadDefaultsFileResult = ["globalstate": 2] as NSDictionary
            XCTAssertTrue(firewallCheck.checkPasses())
        }
    }

    func testCheckPasses_macOSOlder_disabled() {
        if #unavailable(macOS 15) {
            firewallCheck.mockReadDefaultsFileResult = ["globalstate": 0] as NSDictionary
            XCTAssertFalse(firewallCheck.checkPasses())

            firewallCheck.mockReadDefaultsFileResult = nil
            XCTAssertFalse(firewallCheck.checkPasses())
        }
    }
}
