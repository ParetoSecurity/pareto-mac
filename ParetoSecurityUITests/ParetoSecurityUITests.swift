//
//  ParetoSecurityUITests.swift
//  ParetoSecurityUITests
//
//  Created by Janez Troha on 12/08/2021.
//

import Accessibility
import Defaults
@testable import Pareto_Security
import XCTest

class ParetoSecurityUITests: XCTestCase {
    let app = XCUIApplication()
    var menu: XCUIElement?

    override func setUp() {
        super.setUp()
        app.launchArguments = ["isRunningTests"]
        app.launchEnvironment = ["isRunningTests": "true"]
        app.launch()
    }

    override func tearDown() {
        super.tearDown()
        app.terminate()
    }

    private func waitUntilMenu() {
        app.activate()
        app.children(matching: .menuBar).element(boundBy: 1).children(matching: .statusItem).element.click()
        if !app.statusItems.firstMatch.waitForExistence(timeout: 3) {
            XCTFail("Menu did not build")
        }
    }

    func takeScreenshot(screenshot: XCUIScreenshot, name: String) {
        let screenshotAttachment = XCTAttachment(
            uniformTypeIdentifier: "public.png",
            name: "Screenshot-\(name).png",
            payload: screenshot.pngRepresentation,
            userInfo: nil
        )
        screenshotAttachment.lifetime = .keepAlways
        add(screenshotAttachment)
    }

    func testHoverMenus() throws {
        // XCTExpectFailure("Fails with in xcode 13 env, working on a fix")

        let menuBarsQuery = app.menuBars
        waitUntilMenu()

        menuBarsQuery.menuItems["Access Security"].click()
        takeScreenshot(screenshot: app.statusItems.firstMatch.menus.firstMatch.screenshot(), name: "Access Security")
        takeScreenshot(screenshot: app.screenshot(), name: "Access Security App")

        menuBarsQuery.menuItems["Firewall & Sharing"].click()
        takeScreenshot(screenshot: app.statusItems.firstMatch.menus.firstMatch.screenshot(), name: "Firewall & Sharing")
        takeScreenshot(screenshot: app.screenshot(), name: "Firewall & Sharing App")

        menuBarsQuery.menuItems["macOS Updates"].click()
        takeScreenshot(screenshot: app.statusItems.firstMatch.menus.firstMatch.screenshot(), name: "macOS Updates")
        takeScreenshot(screenshot: app.screenshot(), name: "macOS Updates App")

        menuBarsQuery.menuItems["Application Updates"].click()
        takeScreenshot(screenshot: app.statusItems.firstMatch.menus.firstMatch.screenshot(), name: "Application Updates")
        takeScreenshot(screenshot: app.screenshot(), name: "Application Updates App")

        menuBarsQuery.menuItems["System Integrity"].click()
        takeScreenshot(screenshot: app.statusItems.firstMatch.menus.firstMatch.screenshot(), name: "System Integrity")
        takeScreenshot(screenshot: app.screenshot(), name: "System Integrity App")

        menuBarsQuery.menuItems["Snooze"].click()
        takeScreenshot(screenshot: app.statusItems.firstMatch.menus.firstMatch.screenshot(), name: "Snooze")
        takeScreenshot(screenshot: app.screenshot(), name: "Snooze App")
    }

    func testSnooze() throws {
        // XCTExpectFailure("Fails with in xcode 13 env, working on a fix")

        let menuBarsQuery = app.menuBars
        waitUntilMenu()

        menuBarsQuery.menuItems["Snooze"].click()
        takeScreenshot(screenshot: app.statusItems.firstMatch.menus.firstMatch.screenshot(), name: "Snooze")
        takeScreenshot(screenshot: app.screenshot(), name: "Snooze App")
    }

    func testSettingsWindow() throws {
        // XCTExpectFailure("Fails with in xcode 13 env, working on a fix")

        let menuBarsQuery = app.menuBars
        waitUntilMenu()

        menuBarsQuery.menuItems["showPrefs"].click()
    }

    func testAppRuns() throws {
        takeScreenshot(screenshot: app.screenshot(), name: "App")
    }
}
