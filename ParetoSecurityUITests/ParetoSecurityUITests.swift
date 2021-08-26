//
//  ParetoSecurityUITests.swift
//  ParetoSecurityUITests
//
//  Created by Janez Troha on 12/08/2021.
//

import XCTest

class ParetoSecurityUITests: XCTestCase {
    let app = XCUIApplication()
    var menu: XCUIElement?

    override func setUp() {
        super.setUp()
        app.launch()
    }

    override func tearDown() {
        super.tearDown()
        app.terminate()
    }

    private func waitUntilMenu() {
        if !app.statusItems.firstMatch.waitForExistence(timeout: 3) {
            XCTFail("Menu did not build")
        }
        app.statusItems.firstMatch.click()
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

    func enableClaim(_ menu: String) {
        let menuBarsQuery = app.menuBars.menus["paretoMenu"]
        if menuBarsQuery.menuItems[menu].menuItems["enableCheck"].exists {
            menuBarsQuery.menuItems[menu].menuItems["enableCheck"].click()
            waitUntilMenu()
        }
    }

    func testHoverMenus() throws {
        XCTExpectFailure("Fails with in xcode 13 env, working on a fix")
        let menuBarsQuery = app.menuBars.menus["paretoMenu"]
        waitUntilMenu()

        enableClaim("Firewall is on")
        enableClaim("Lock after inactivity")
        enableClaim("Login is secure")
        enableClaim("System integrity")

        menuBarsQuery.menuItems["Firewall is on"].hover()
        takeScreenshot(screenshot: app.statusItems.firstMatch.menus.firstMatch.screenshot(), name: "Firewall")
        takeScreenshot(screenshot: app.screenshot(), name: "Firewall App")

        menuBarsQuery.menuItems["Lock after inactivity"].hover()
        takeScreenshot(screenshot: app.statusItems.firstMatch.menus.firstMatch.screenshot(), name: "Lock")
        takeScreenshot(screenshot: app.screenshot(), name: "Lock App")

        menuBarsQuery.menuItems["Login is secure"].hover()
        takeScreenshot(screenshot: app.statusItems.firstMatch.menus.firstMatch.screenshot(), name: "Login")
        takeScreenshot(screenshot: app.screenshot(), name: "Login App")

        menuBarsQuery.menuItems["System integrity"].hover()
        takeScreenshot(screenshot: app.statusItems.firstMatch.menus.firstMatch.screenshot(), name: "System")
        takeScreenshot(screenshot: app.screenshot(), name: "System App")
    }

    func testAppRuns() throws {
        takeScreenshot(screenshot: app.screenshot(), name: "App")
    }
}
