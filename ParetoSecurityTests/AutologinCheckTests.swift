
//
//  AutologinCheckTests.swift
//  ParetoSecurityTests
//
//  Created by Janez Troha on 26/06/2025.
//

import XCTest
import Foundation
import Defaults
@testable import Pareto_Security

// Testable subclass of AutologinCheck to mock dependencies
class TestableAutologinCheck: AutologinCheck {
    var mockRunOSAOutput: String? = nil

    func runOSA(appleScript: String) -> String? {
        return mockRunOSAOutput
    }
}

class AutologinCheckTests: XCTestCase {

    var userDefaults: UserDefaults!
    var autologinCheck: TestableAutologinCheck!

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: "debug-paretosecurity")
        userDefaults.removePersistentDomain(forName: "debug-paretosecurity")

        autologinCheck = TestableAutologinCheck()
        autologinCheck.configure() // Ensure defaults are registered
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: "debug-paretosecurity")
        super.tearDown()
    }

    func testUUID() {
        XCTAssertEqual(autologinCheck.UUID, "f962c423-fdf5-428a-a57a-816abc9b253e")
    }

    func testTitles() {
        XCTAssertEqual(autologinCheck.TitleON, "Automatic login is off")
        XCTAssertEqual(autologinCheck.TitleOFF, "Automatic login is on")
    }

    func testShowSettingsWarnEvents() {
        XCTAssertTrue(autologinCheck.showSettingsWarnEvents)
    }

    func testCheckPasses_autologinOff() {
        autologinCheck.mockRunOSAOutput = "false"
        XCTAssertTrue(autologinCheck.checkPasses())
    }

    func testCheckPasses_autologinOn() {
        autologinCheck.mockRunOSAOutput = "true"
        XCTAssertFalse(autologinCheck.checkPasses())
    }

    func testCheckPasses_runOSANil() {
        autologinCheck.mockRunOSAOutput = nil
        XCTAssertFalse(autologinCheck.checkPasses())
    }

    func testCheckPasses_runOSAEmpty() {
        autologinCheck.mockRunOSAOutput = ""
        XCTAssertFalse(autologinCheck.checkPasses())
    }
}
