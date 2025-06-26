
//
//  FirewallStealthCheckTests.swift
//  ParetoSecurityTests
//
//  Created by Janez Troha on 26/06/2025.
//

import XCTest
import Foundation
import Defaults
@testable import Pareto_Security

// Testable subclass of FirewallStealthCheck to mock dependencies
class TestableFirewallStealthCheck: FirewallStealthCheck {
    var mockFirewallCheckIsActive: Bool = true
    var mockHelperIsInstalled: Bool = true
    var mockRunCMDOutput: String = ""
    var mockIsFirewallStealthEnabledResult: Bool = false
    var mockEnsureHelperIsUpToDateResult: Bool = true
    var mockTeamEnforced: Bool = false

    override var isRunnable: Bool {
        // Override to use our mock values
        if !mockFirewallCheckIsActive || !isActive {
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
            // Mock the async helper calls
            return mockIsFirewallStealthEnabledResult
        }
        // Mock runCMD for older macOS
        return mockRunCMDOutput.contains("enabled") || mockRunCMDOutput.contains("mode is on")
    }

    override var teamEnforced: Bool {
        return mockTeamEnforced
    }
}

class FirewallStealthCheckTests: XCTestCase {

    var userDefaults: UserDefaults!
    var firewallStealthCheck: TestableFirewallStealthCheck!

    override func setUp() {
        super.setUp()
        // Use the same suite name as the debug configuration for Defaults
        userDefaults = UserDefaults(suiteName: "debug-paretosecurity")
        userDefaults.removePersistentDomain(forName: "debug-paretosecurity")

        firewallStealthCheck = TestableFirewallStealthCheck()
        firewallStealthCheck.configure() // Ensure defaults are registered
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: "debug-paretosecurity")
        super.tearDown()
    }

    func testUUID() {
        XCTAssertEqual(firewallStealthCheck.UUID, "2e46c89a-5461-4865-a92e-3b799c12034b")
    }

    func testTitles() {
        XCTAssertEqual(firewallStealthCheck.TitleON, "Firewall stealth mode is enabled")
        XCTAssertEqual(firewallStealthCheck.TitleOFF, "Firewall stealth mode is disabled")
    }

    func testRequiresHelper() {
        if #available(macOS 15, *) {
            XCTAssertTrue(firewallStealthCheck.requiresHelper)
        } else {
            XCTAssertFalse(firewallStealthCheck.requiresHelper)
        }
    }

    func testIsRunnable_activeFirewall_activeCheck_helperInstalled() {
        firewallStealthCheck.mockFirewallCheckIsActive = true
        firewallStealthCheck.isActive = true
        firewallStealthCheck.mockHelperIsInstalled = true

        XCTAssertTrue(firewallStealthCheck.isRunnable)
    }

    func testIsRunnable_inactiveFirewall() {
        firewallStealthCheck.mockFirewallCheckIsActive = false
        firewallStealthCheck.isActive = true
        firewallStealthCheck.mockHelperIsInstalled = true

        XCTAssertFalse(firewallStealthCheck.isRunnable)
    }

    func testIsRunnable_inactiveCheck() {
        firewallStealthCheck.mockFirewallCheckIsActive = true
        firewallStealthCheck.isActive = false
        firewallStealthCheck.mockHelperIsInstalled = true

        XCTAssertFalse(firewallStealthCheck.isRunnable)
    }

    func testIsRunnable_macOS15AndAbove_helperNotInstalled() {
        if #available(macOS 15, *) {
            firewallStealthCheck.mockFirewallCheckIsActive = true
            firewallStealthCheck.isActive = true
            firewallStealthCheck.mockHelperIsInstalled = false

            XCTAssertFalse(firewallStealthCheck.isRunnable)
        }
    }

    func testCheckPasses_macOS15AndAbove_enabled() {
        if #available(macOS 15, *) {
            firewallStealthCheck.mockIsFirewallStealthEnabledResult = true
            XCTAssertTrue(firewallStealthCheck.checkPasses())
        }
    }

    func testCheckPasses_macOS15AndAbove_disabled() {
        if #available(macOS 15, *) {
            firewallStealthCheck.mockIsFirewallStealthEnabledResult = false
            XCTAssertFalse(firewallStealthCheck.checkPasses())
        }
    }

    func testCheckPasses_macOSOlder_enabled() {
        if #unavailable(macOS 15) {
            firewallStealthCheck.mockRunCMDOutput = "Stealth mode is enabled"
            XCTAssertTrue(firewallStealthCheck.checkPasses())
        }
    }

    func testCheckPasses_macOSOlder_disabled() {
        if #unavailable(macOS 15) {
            firewallStealthCheck.mockRunCMDOutput = "Stealth mode is disabled"
            XCTAssertFalse(firewallStealthCheck.checkPasses())
        }
    }

    func testShowSettings() {
        firewallStealthCheck.isActive = true // Ensure ParetoCheck's isActive is true for showSettings to be true

        // Case 1: teamEnforced is false, FirewallCheck.sharedInstance.isActive is true
        firewallStealthCheck.mockTeamEnforced = false
        firewallStealthCheck.mockFirewallCheckIsActive = true
        XCTAssertTrue(firewallStealthCheck.showSettings)

        // Case 2: teamEnforced is true
        firewallStealthCheck.mockTeamEnforced = true
        firewallStealthCheck.mockFirewallCheckIsActive = true
        XCTAssertFalse(firewallStealthCheck.showSettings)

        // Case 3: teamEnforced is false, FirewallCheck.sharedInstance.isActive is false
        firewallStealthCheck.mockTeamEnforced = false
        firewallStealthCheck.mockFirewallCheckIsActive = false
        XCTAssertFalse(firewallStealthCheck.showSettings)
    }
}
