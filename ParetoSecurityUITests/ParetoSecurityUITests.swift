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
        if app.wait(for: .runningBackground, timeout: 3) {
            print("Menu did not settle after run")
        }
    }

    override func tearDown() {
        super.tearDown()
        app.terminate()
    }

    private func waitUntilMenu() {
        app.statusItems.firstMatch.click()
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
        waitUntilMenu()

        let menuBarsQuery = app.menuBars
        menuBarsQuery.menuItems["Lock after inactivity"].hover()
        takeScreenshot(screenshot: app.statusItems.firstMatch.menus.firstMatch.screenshot(), name: "Lock")
        takeScreenshot(screenshot: app.screenshot(), name: "Lock App")
        menuBarsQuery.menuItems["Firewall is on"].hover()
        takeScreenshot(screenshot: app.statusItems.firstMatch.menus.firstMatch.screenshot(), name: "Firewall")
        takeScreenshot(screenshot: app.screenshot(), name: "Firewall App")
        menuBarsQuery.menuItems["Login is secure"].hover()
        takeScreenshot(screenshot: app.statusItems.firstMatch.menus.firstMatch.screenshot(), name: "Login")
        takeScreenshot(screenshot: app.screenshot(), name: "Login App")
        menuBarsQuery.menuItems["System integrity"].hover()
        takeScreenshot(screenshot: app.statusItems.firstMatch.menus.firstMatch.screenshot(), name: "System")
        takeScreenshot(screenshot: app.screenshot(), name: "System App")
    }

    func testAppRuns() throws {
        waitUntilMenu()
        takeScreenshot(screenshot: app.screenshot(), name: "App")
        takeScreenshot(screenshot: app.statusItems.firstMatch.menus.firstMatch.screenshot(), name: "Menu")
    }
}
