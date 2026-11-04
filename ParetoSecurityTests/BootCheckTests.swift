//
//  BootCheckTests.swift
//  ParetoSecurityTests
//
//  Created by Roberto Alfieri on 03/11/2026.
//

@testable import Pareto_Security
import XCTest

class BootCheckTests: XCTestCase {
    private let sipEnabled = "System Integrity Protection status: enabled."
    private let sipDisabled = "System Integrity Protection status: disabled."
    private let sipCustom = "System Integrity Protection status: unknown (Custom Configuration)."

    func testPassesWhenSIPEnabledAndNoBootArgs() {
        let check = BootCheck(sipStatusProvider: { self.sipEnabled }, bootArgsProvider: { "" })
        XCTAssertTrue(check.checkPasses())
    }

    func testFailsWhenSIPDisabled() {
        let check = BootCheck(sipStatusProvider: { self.sipDisabled }, bootArgsProvider: { "" })
        XCTAssertFalse(check.checkPasses())
    }

    func testFailsWhenSIPCustomConfiguration() {
        let check = BootCheck(sipStatusProvider: { self.sipCustom }, bootArgsProvider: { "" })
        XCTAssertFalse(check.checkPasses())
    }

    func testFailsWhenBootArgsSet() {
        let check = BootCheck(sipStatusProvider: { self.sipEnabled }, bootArgsProvider: { "amfi_get_out_of_my_way=1" })
        XCTAssertFalse(check.checkPasses())
    }
}
