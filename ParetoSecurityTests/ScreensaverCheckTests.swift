//
//  ScreensaverCheckTests.swift
//  ParetoSecurityTests
//
//  Created by ArchitektApx on 04/11/2026.
//

@testable import Pareto_Security
import XCTest

class ScreensaverCheckTests: XCTestCase {
    private func timers(ac: Any? = nil, battery: Any? = nil, ups: Any? = nil) -> [String: Any] {
        var prefs: [String: Any] = [:]
        if let ac {
            prefs["AC Power"] = ["Display Sleep Timer": ac]
        }
        if let battery {
            prefs["Battery Power"] = ["Display Sleep Timer": battery]
        }
        if let ups {
            prefs["UPS Power"] = ["Display Sleep Timer": ups]
        }
        return prefs
    }

    func testDisplaySleepOnDesktop() {
        XCTAssertTrue(ScreensaverCheck.displaySleepPasses(timers(ac: 10)))
        XCTAssertFalse(ScreensaverCheck.displaySleepPasses(timers(ac: 0)))
        XCTAssertFalse(ScreensaverCheck.displaySleepPasses(["AC Power": ["System Sleep Timer": 10]]))
    }

    func testDisplaySleepOnLaptopNeedsBothProfiles() {
        XCTAssertTrue(ScreensaverCheck.displaySleepPasses(timers(ac: 10, battery: 2)))
        XCTAssertFalse(ScreensaverCheck.displaySleepPasses(timers(ac: 30, battery: 2)))
        XCTAssertFalse(ScreensaverCheck.displaySleepPasses(timers(ac: 10, battery: 0)))
    }

    func testDisplaySleepFailsWithoutReadableTimers() {
        XCTAssertFalse(ScreensaverCheck.displaySleepPasses([:]))
        XCTAssertFalse(ScreensaverCheck.displaySleepPasses(nil))
        XCTAssertFalse(ScreensaverCheck.displaySleepPasses(timers(ac: "10")))
    }

    func testDisplaySleepIgnoresUPSPower() {
        XCTAssertFalse(ScreensaverCheck.displaySleepPasses(timers(ups: 10)))
        XCTAssertTrue(ScreensaverCheck.displaySleepPasses(timers(ac: 10, ups: 0)))
    }

    func testDisplaySleepLimitIsInclusive() {
        XCTAssertTrue(ScreensaverCheck.displaySleepPasses(timers(ac: 20)))
        XCTAssertFalse(ScreensaverCheck.displaySleepPasses(timers(ac: 21)))
    }

    func testScreensaverDelay() {
        XCTAssertTrue(ScreensaverCheck(idleTimeProvider: { 1200 }).checkScreensaver())
        XCTAssertTrue(ScreensaverCheck(idleTimeProvider: { "600" }).checkScreensaver())
        XCTAssertFalse(ScreensaverCheck(idleTimeProvider: { 1201 }).checkScreensaver())
        XCTAssertFalse(ScreensaverCheck(idleTimeProvider: { nil }).checkScreensaver())
    }

    func testErrorsWhenPowerSettingsAreUnreadable() {
        let check = ScreensaverCheck(idleTimeProvider: { 0 }, powerPreferencesProvider: { nil })

        XCTAssertFalse(check.checkPasses())
        XCTAssertTrue(check.hasError)
    }

    func testFailsWhenScreensaverAndDisplaySleepAreOff() {
        let check = ScreensaverCheck(idleTimeProvider: { 0 }, powerPreferencesProvider: { self.timers(ac: 0) })

        XCTAssertFalse(check.checkPasses())
        XCTAssertFalse(check.hasError)
    }

    func testPassesWithScreensaverOnly() {
        let check = ScreensaverCheck(idleTimeProvider: { 600 }, powerPreferencesProvider: { self.timers(ac: 0) })

        XCTAssertTrue(check.checkPasses())
    }

    func testPassesWithDisplaySleepOnly() {
        let check = ScreensaverCheck(
            idleTimeProvider: { 0 },
            powerPreferencesProvider: { self.timers(ac: 10, battery: 10) }
        )

        XCTAssertTrue(check.checkPasses())
    }

    func testFailsWhenBothDelaysAreTooLong() {
        let check = ScreensaverCheck(idleTimeProvider: { 1500 }, powerPreferencesProvider: { self.timers(ac: 30) })

        XCTAssertFalse(check.checkPasses())
    }
}
