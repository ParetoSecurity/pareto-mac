//
//  SudoRequiresPasswordTests.swift
//  ParetoSecurityTests
//
//  Created by ArchitektApx on 04/11/2026.
//

import Combine
import os
@testable import Pareto_Security
import XCTest

/// Runnable without the installed helper, and with its own stored result.
private final class RunnableSudoCheck: SudoRequiresPasswordCheck {
    override var UUID: String {
        "test-sudo-requires-password"
    }

    override var isRunnable: Bool {
        true
    }
}

/// Takes a while to hand its result to run(), so a helper answer can land in between.
private final class SlowToReportSudoCheck: SudoRequiresPasswordCheck {
    override var UUID: String {
        "test-sudo-requires-password"
    }

    override var isRunnable: Bool {
        true
    }

    override func checkPasses() -> Bool {
        let passes = super.checkPasses()
        Thread.sleep(forTimeInterval: 0.3)
        return passes
    }
}

/// Stands in for the helper: answers after `delay` and counts how often it was asked.
final class ListingStub: Sendable {
    private let state: OSAllocatedUnfairLock<(output: String, calls: Int)>
    let delay: TimeInterval

    init(_ output: String, delay: TimeInterval = 0.05) {
        state = OSAllocatedUnfairLock(initialState: (output, 0))
        self.delay = delay
    }

    var calls: Int {
        state.withLock { $0.calls }
    }

    func answer(with output: String) {
        state.withLock { $0.output = output }
    }

    /// Like the real helper call, which reaches the helper from the main actor.
    func listingViaMainActor() async -> String {
        await MainActor.run {}
        return await listing()
    }

    func listing() async -> String {
        state.withLock { $0.calls += 1 }
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        return state.withLock { $0.output }
    }
}

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

    /// Polls until checkPasses() reports what the caller expects, with hasError cleared as run() does.
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

    // MARK: - Fresh helper answers

    override func tearDown() {
        let check = RunnableSudoCheck()
        for key in [check.PassesKey, check.TimestampKey, check.CachedDetailsKey] {
            UserDefaults.standard.removeObject(forKey: key)
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

    func testFirstRunReportsHelperAnswerNotStoredResult() async {
        let stub = ListingStub(Self.stockAdmin)
        let check = RunnableSudoCheck(listingProvider: stub.listing)
        check.checkPassed = false

        let passes = await Self.offMain { check.run() }

        XCTAssertTrue(passes)
        XCTAssertTrue(check.checkPassed)
    }

    func testChangedPrivilegesAreReportedOnTheSameRun() async {
        let stub = ListingStub(Self.stockAdmin)
        let check = RunnableSudoCheck(listingProvider: stub.listing)
        let before = await Self.offMain { check.run() }
        XCTAssertTrue(before)

        stub.answer(with: Self.privileges("(ALL) NOPASSWD: ALL"))
        let after = await Self.offMain { check.run() }

        XCTAssertFalse(after)
    }

    func testReportWaitsForHelperAnswerAndAsksOnce() async {
        let stub = ListingStub(Self.stockAdmin)
        let check = RunnableSudoCheck(listingProvider: stub.listing)
        check.checkPassed = false

        let prefetched = await Self.offMain { Claims.prefetch([check], timeout: 2) }
        // The report paths call run() on the main thread right after the prefetch
        let passes = await MainActor.run { check.run() }

        XCTAssertTrue(prefetched)
        XCTAssertTrue(passes)
        XCTAssertEqual(stub.calls, 1)
    }

    @MainActor
    func testAnswerLandingAfterMainThreadRunIsPublished() async {
        let stub = ListingStub(Self.stockAdmin)
        let check = RunnableSudoCheck(listingProvider: stub.listing)
        check.checkPassed = false
        let notified = expectation(description: "observers are told about the helper answer")
        notified.assertForOverFulfill = false
        let observer = check.objectWillChange.sink { notified.fulfill() }
        defer { observer.cancel() }

        // The main thread must not block on the helper, so this answers from the stored result
        XCTAssertFalse(check.checkPasses())

        await fulfillment(of: [notified], timeout: 2)
        XCTAssertTrue(check.checkPassed)
        XCTAssertFalse(check.hasError)
    }

    func testUnansweredHelperIsAnErrorAndIsNotAskedAgain() async {
        let stub = ListingStub(Self.stockAdmin, delay: 1)
        let check = RunnableSudoCheck(listingProvider: stub.listing, helperTimeout: 0.1)
        check.checkPassed = true
        let start = Date()

        let first = await Self.offMain { check.run() }
        let firstHadError = check.hasError
        let second = await Self.offMain { check.run() }
        let prefetched = await Self.offMain { Claims.prefetch([check], timeout: 2) }

        XCTAssertFalse(first)
        XCTAssertTrue(firstHadError)
        XCTAssertFalse(second)
        XCTAssertTrue(check.hasError)
        XCTAssertTrue(prefetched)
        XCTAssertEqual(stub.calls, 1)
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.9)

        // The late answer replaces the error once it lands
        for _ in 0 ..< 300 where check.hasError {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertFalse(check.hasError)
        XCTAssertTrue(check.checkPassed)
    }

    /// `-report` and `-report-json` prefetch and run on the main thread, which the helper call also needs.
    func testReportOnMainThreadGetsAnswerThatNeedsTheMainActor() {
        let stub = ListingStub(Self.stockAdmin)
        let check = RunnableSudoCheck(listingProvider: stub.listingViaMainActor, helperTimeout: 1)
        check.checkPassed = false
        XCTAssertTrue(Thread.isMainThread)

        XCTAssertTrue(Claims.prefetch([check], timeout: 3))
        let passes = check.run()

        XCTAssertTrue(passes)
        XCTAssertFalse(check.hasError)
        XCTAssertEqual(stub.calls, 1)
    }

    @MainActor
    func testAnswerLandingWhileRunStoresItsResultIsKept() async {
        let stub = ListingStub(Self.stockAdmin)
        let check = SlowToReportSudoCheck(listingProvider: stub.listing)
        check.checkPassed = false

        // On the main thread run() answers from the stored result; the helper answers before run() stores it
        XCTAssertFalse(check.run())
        try? await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertTrue(check.checkPassed)
        XCTAssertFalse(check.hasError)
    }
}
