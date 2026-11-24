//
//  FirewallHelperChecksTests.swift
//  ParetoSecurityTests
//
//  Created by Janez Troha on 24/11/2026.
//

@testable import Pareto_Security
import XCTest

/// On the helper path (macOS 15 to 25) whatever this Mac runs, and with its own stored result.
private final class HelperFirewallCheck: FirewallCheck {
    override var UUID: String {
        "test-firewall"
    }

    override var requiresHelper: Bool {
        true
    }

    override var isRunnable: Bool {
        true
    }
}

private final class HelperFirewallStealthCheck: FirewallStealthCheck {
    override var UUID: String {
        "test-firewall-stealth"
    }

    override var requiresHelper: Bool {
        true
    }

    override var isRunnable: Bool {
        true
    }
}

class FirewallHelperChecksTests: XCTestCase {
    override func tearDown() {
        for check in [HelperFirewallCheck(), HelperFirewallStealthCheck()] as [ParetoCheck] {
            for key in [check.PassesKey, check.TimestampKey, check.CachedDetailsKey] {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        super.tearDown()
    }

    /// Checks run on a background queue, never on the main thread.
    private static func offMain<T: Sendable>(_ body: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                continuation.resume(returning: body())
            }
        }
    }

    func testFirewallStateIsReadFromHelperOutput() {
        XCTAssertEqual(FirewallCheck.evaluate(helperOutput: "Firewall is enabled. (State = 1)"), true)
        XCTAssertEqual(FirewallCheck.evaluate(helperOutput: "Firewall is blocking all non-essential incoming connections. (State = 2)"), true)
        XCTAssertEqual(FirewallCheck.evaluate(helperOutput: "Firewall is disabled. (State = 0)"), false)
        XCTAssertNil(FirewallCheck.evaluate(helperOutput: "XPC: Helper tool is not installed"))
        XCTAssertNil(FirewallCheck.evaluate(helperOutput: "Command timed out"))
    }

    func testStealthModeIsReadFromHelperOutput() {
        XCTAssertEqual(FirewallStealthCheck.evaluate(helperOutput: "Firewall stealth mode is on"), true)
        XCTAssertEqual(FirewallStealthCheck.evaluate(helperOutput: "Stealth mode enabled"), true)
        XCTAssertEqual(FirewallStealthCheck.evaluate(helperOutput: "Firewall stealth mode is off"), false)
        XCTAssertEqual(FirewallStealthCheck.evaluate(helperOutput: "Stealth mode disabled"), false)
        XCTAssertNil(FirewallStealthCheck.evaluate(helperOutput: "XPC: Connection not available"))
        XCTAssertNil(FirewallStealthCheck.evaluate(helperOutput: "Command timed out"))
    }

    func testFirewallFirstRunReportsHelperAnswerNotStoredResult() async {
        let stub = ListingStub("Firewall is enabled. (State = 1)")
        let check = HelperFirewallCheck(helperProvider: stub.listing)
        check.checkPassed = false

        let passes = await Self.offMain { check.run() }

        XCTAssertTrue(passes)
        XCTAssertTrue(check.checkPassed)
    }

    func testFirewallTurnedOffIsReportedOnTheSameRun() async {
        let stub = ListingStub("Firewall is enabled. (State = 1)")
        let check = HelperFirewallCheck(helperProvider: stub.listing)
        let before = await Self.offMain { check.run() }
        XCTAssertTrue(before)

        stub.answer(with: "Firewall is disabled. (State = 0)")
        let after = await Self.offMain { check.run() }

        XCTAssertFalse(after)
        XCTAssertFalse(check.hasError)
    }

    func testFirewallWithoutUsableHelperAnswerIsAnError() async {
        let stub = ListingStub("XPC: Helper tool is not installed")
        let check = HelperFirewallCheck(helperProvider: stub.listing)
        check.checkPassed = true

        let passes = await Self.offMain { check.run() }

        XCTAssertFalse(passes)
        XCTAssertTrue(check.hasError)
    }

    /// `-report` and `-report-json` prefetch and run on the main thread, which the helper call also needs.
    func testFirewallReportOnMainThreadGetsHelperAnswer() {
        let stub = ListingStub("Firewall is enabled. (State = 1)")
        let check = HelperFirewallCheck(helperProvider: stub.listingViaMainActor, helperTimeout: 1)
        check.checkPassed = false

        XCTAssertTrue(Claims.prefetch([check], timeout: 3))
        let passes = check.run()

        XCTAssertTrue(passes)
        XCTAssertEqual(stub.calls, 1)
    }

    func testStealthFirstRunReportsHelperAnswerNotStoredResult() async {
        let stub = ListingStub("Firewall stealth mode is on")
        let check = HelperFirewallStealthCheck(helperProvider: stub.listing)
        check.checkPassed = false

        let passes = await Self.offMain { check.run() }

        XCTAssertTrue(passes)
        XCTAssertTrue(check.checkPassed)
    }

    func testStealthReportOnMainThreadGetsHelperAnswer() {
        let stub = ListingStub("Firewall stealth mode is off")
        let check = HelperFirewallStealthCheck(helperProvider: stub.listingViaMainActor, helperTimeout: 1)
        check.checkPassed = true

        XCTAssertTrue(Claims.prefetch([check], timeout: 3))
        let passes = check.run()

        XCTAssertFalse(passes)
        XCTAssertFalse(check.hasError)
        XCTAssertEqual(stub.calls, 1)
    }

    func testUnansweredFirewallHelperIsAnError() async {
        let stub = ListingStub("Firewall is enabled. (State = 1)", delay: 1)
        let check = HelperFirewallCheck(helperProvider: stub.listing, helperTimeout: 0.1)
        check.checkPassed = true

        let passes = await Self.offMain { check.run() }

        XCTAssertFalse(passes)
        XCTAssertTrue(check.hasError)

        // The late answer replaces the error once it lands
        for _ in 0 ..< 300 where check.hasError {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertFalse(check.hasError)
        XCTAssertTrue(check.checkPassed)
    }
}
