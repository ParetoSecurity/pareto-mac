//
//  SudoRequiresPasswordTests.swift
//  ParetoSecurityTests
//
//  Created by ArchitektApx on 04/11/2026.
//

@testable import Pareto_Security
import XCTest

/// No live test: every sudo run leaves an entry in the system log of the machine running the tests.
class SudoRequiresPasswordTests: XCTestCase {
    /// Captured verbatim from `env -i LC_ALL=C /usr/bin/sudo -k -n /usr/bin/id -u 2>&1` on macOS 27.2 (sudo 1.9.17p2)
    /// and on clean macOS 13.7.4 (1.9.13p2) and 26.6.2 (1.9.17p2) VMs, also for a user who is not in sudoers.
    static let passwordRequired = "sudo: a password is required\n"

    /// The same command on those VMs with `admin ALL=(ALL) NOPASSWD: ALL`.
    static let noPasswordRequired = "0\n"

    func testPassesForNonAdminWithoutRunningSudo() {
        var sudoRan = false
        let check = SudoRequiresPasswordCheck(isAdminProvider: { false }, sudoRunner: {
            sudoRan = true
            return Self.noPasswordRequired
        })

        XCTAssertTrue(check.checkPasses())
        XCTAssertFalse(sudoRan)
    }

    func testFailsWhenSudoRunsWithoutPassword() {
        let check = SudoRequiresPasswordCheck(isAdminProvider: { true }, sudoRunner: { Self.noPasswordRequired })

        XCTAssertFalse(check.checkPasses())
        XCTAssertFalse(check.hasError)
    }

    func testPassesWhenSudoAsksForAPassword() {
        for output in [Self.passwordRequired, "sudo: a password is required\r\n", "sudo: a password is required"] {
            let check = SudoRequiresPasswordCheck(isAdminProvider: { true }, sudoRunner: { output })

            XCTAssertTrue(check.checkPasses(), output)
            XCTAssertFalse(check.hasError, output)
        }
    }

    func testUnknownOutputIsAnError() {
        let outputs = [
            // runCMD returns an empty string when sudo cannot be launched
            "",
            "501\n",
            "sudo: sorry, you must have a tty to run sudo\n",
            "warning\n" + Self.passwordRequired,
            Self.passwordRequired + "warning\n",
        ]

        for output in outputs {
            let check = SudoRequiresPasswordCheck(isAdminProvider: { true }, sudoRunner: { output })

            XCTAssertFalse(check.checkPasses(), output)
            XCTAssertTrue(check.hasError, output)
        }
    }
}
