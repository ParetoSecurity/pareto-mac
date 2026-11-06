//
//  SudoRequiresPasswordTests.swift
//  ParetoSecurityTests
//
//  Created by ArchitektApx on 04/11/2026.
//

@testable import Pareto_Security
import XCTest

/// No live test: listing another user's privileges needs root, which only the privileged helper has.
class SudoRequiresPasswordTests: XCTestCase {
    static let defaults = """
    Matching Defaults entries for alice on mac:
        env_reset, env_keep+=BLOCKSIZE, env_keep+="COLORFGBG COLORTERM", env_keep+=__CF_USER_TEXT_ENCODING,
        env_keep+="CHARSET LANG LANGUAGE LC_ALL LC_COLLATE LC_CTYPE", env_keep+="EDITOR VISUAL",
        lecture_file=/etc/sudo_lecture

    Runas and Command-specific defaults for alice:
        Defaults!/usr/sbin/visudo env_keep+="SUDO_EDITOR EDITOR VISUAL"

    """

    /// Stock macOS sudoers: `%admin ALL = (ALL) ALL`.
    static let stockAdmin = defaults + """
    User alice may run the following commands on mac:
        (ALL) ALL
    """

    static let notInSudoers = "User bob is not allowed to run sudo on mac."

    static func privileges(_ lines: String...) -> String {
        defaults + "User alice may run the following commands on mac:\n"
            + lines.map { "    \($0)" }.joined(separator: "\n")
    }

    func testStockAdminPasses() {
        XCTAssertEqual(SudoRequiresPasswordCheck.evaluate(listing: Self.stockAdmin), true)
    }

    func testUserNotInSudoersPasses() {
        XCTAssertEqual(SudoRequiresPasswordCheck.evaluate(listing: Self.notInSudoers), true)
        XCTAssertEqual(SudoRequiresPasswordCheck.evaluate(listing: Self.defaults + Self.notInSudoers), true)
    }

    func testNoPasswordForAllCommandsFails() {
        let listings = [
            Self.privileges("(ALL) NOPASSWD: ALL"),
            Self.privileges("(ALL : ALL) NOPASSWD: ALL"),
            Self.privileges("(ALL) ALL", "(root) NOPASSWD: ALL"),
            Self.privileges("(ALL) SETENV: NOPASSWD: ALL"),
            Self.privileges("(ALL) NOPASSWD: SETENV: ALL"),
            Self.privileges("(root) CWD=/tmp NOPASSWD: ALL"),
            // Tags carry over to the following commands of the same line
            Self.privileges("(root) NOPASSWD: /usr/bin/pmset, ALL"),
        ]
        for listing in listings {
            XCTAssertEqual(SudoRequiresPasswordCheck.evaluate(listing: listing), false, listing)
        }
    }

    func testNoPasswordForSingleCommandsPasses() {
        let listings = [
            Self.privileges("(ALL) ALL", "(root) NOPASSWD: /usr/bin/pmset"),
            Self.privileges("(root) NOPASSWD: /usr/bin/pmset, PASSWD: ALL"),
            // Tags do not carry over to the next privilege line
            Self.privileges("(root) NOPASSWD: /usr/bin/pmset", "(ALL) ALL"),
        ]
        for listing in listings {
            XCTAssertEqual(SudoRequiresPasswordCheck.evaluate(listing: listing), true, listing)
        }
    }

    func testNotAuthenticateDefaultFails() {
        let globalDefault = Self.stockAdmin.replacingOccurrences(
            of: "lecture_file=/etc/sudo_lecture",
            with: "lecture_file=/etc/sudo_lecture, !authenticate"
        )
        XCTAssertEqual(SudoRequiresPasswordCheck.evaluate(listing: globalDefault), false)

        for specific in ["Defaults>root !authenticate", "Defaults!ALL !authenticate"] {
            let listing = Self.stockAdmin.replacingOccurrences(
                of: "Defaults!/usr/sbin/visudo env_keep+=\"SUDO_EDITOR EDITOR VISUAL\"",
                with: specific
            )
            XCTAssertEqual(SudoRequiresPasswordCheck.evaluate(listing: listing), false, specific)
        }
    }

    func testNotAuthenticateForSingleCommandPasses() {
        let listing = Self.stockAdmin.replacingOccurrences(
            of: "Defaults!/usr/sbin/visudo env_keep+=\"SUDO_EDITOR EDITOR VISUAL\"",
            with: "Defaults!/usr/bin/pmset !authenticate"
        )
        XCTAssertEqual(SudoRequiresPasswordCheck.evaluate(listing: listing), true)
    }

    func testSudoWarningsAreIgnored() {
        let listing = "sudo: unable to resolve host mac\n" + Self.privileges("(ALL) NOPASSWD: ALL")
        XCTAssertEqual(SudoRequiresPasswordCheck.evaluate(listing: listing), false)
    }

    func testUnknownOutputIsAnError() {
        let outputs = [
            "",
            "No output",
            "Failed to run command: The file “sudo” doesn’t exist.",
            "Failed to resolve calling user",
            "XPC: Helper tool is not installed",
            "XPC: Connection error: Couldn’t communicate with a helper application.",
            "sudo: unknown user bob",
        ]
        for output in outputs {
            XCTAssertNil(SudoRequiresPasswordCheck.evaluate(listing: output), output)
        }
    }

    func testEvaluateNowUsesProvider() async {
        let failing = SudoRequiresPasswordCheck(listingProvider: { Self.privileges("(ALL) NOPASSWD: ALL") })
        let passing = SudoRequiresPasswordCheck(listingProvider: { Self.stockAdmin })
        let broken = SudoRequiresPasswordCheck(listingProvider: { "XPC: Helper tool is not installed" })

        let failingResult = await failing.evaluateNow()
        let passingResult = await passing.evaluateNow()
        let brokenResult = await broken.evaluateNow()
        XCTAssertEqual(failingResult, false)
        XCTAssertEqual(passingResult, true)
        XCTAssertNil(brokenResult)
    }

    /// checkPasses() answers from the helper's previous answer, so poll until the background fetch lands.
    private func settledCheckPasses(
        _ check: SudoRequiresPasswordCheck,
        until done: (_ passes: Bool, _ hasError: Bool) -> Bool
    ) async -> Bool {
        var result = check.checkPasses()
        for _ in 0 ..< 100 where !done(result, check.hasError) {
            try? await Task.sleep(nanoseconds: 10_000_000)
            check.hasError = false // as run() does before every checkPasses()
            result = check.checkPasses()
        }
        return result
    }

    func testCheckPassesReportsHelperAnswer() async {
        let passing = SudoRequiresPasswordCheck(listingProvider: { Self.stockAdmin })
        let passingResult = await settledCheckPasses(passing) { passes, _ in passes }
        XCTAssertTrue(passingResult)
        XCTAssertFalse(passing.hasError)

        let failing = SudoRequiresPasswordCheck(listingProvider: { Self.privileges("(ALL) NOPASSWD: ALL") })
        let failingResult = await settledCheckPasses(failing) { passes, _ in !passes }
        XCTAssertFalse(failingResult)
        XCTAssertFalse(failing.hasError)

        // The error must survive run() clearing hasError before each checkPasses()
        let broken = SudoRequiresPasswordCheck(listingProvider: { "XPC: Helper tool is not installed" })
        let brokenResult = await settledCheckPasses(broken) { _, hasError in hasError }
        XCTAssertFalse(brokenResult)
        XCTAssertTrue(broken.hasError)
    }

    func testOnlyRegisteredOnMacOS15AndLater() {
        let registered = Claims.global.all.flatMap(\.checks).contains { $0 === SudoRequiresPasswordCheck.sharedInstance }
        if #available(macOS 15, *) {
            XCTAssertTrue(SudoRequiresPasswordCheck.isSupported)
            XCTAssertTrue(SudoRequiresPasswordCheck.sharedInstance.requiresHelper)
            XCTAssertTrue(registered)
        } else {
            XCTAssertFalse(SudoRequiresPasswordCheck.isSupported)
            XCTAssertFalse(SudoRequiresPasswordCheck.sharedInstance.isRunnable)
            XCTAssertFalse(registered)
        }
    }
}
