//
//  ParetoSecurityUITests.swift
//  ParetoSecurityUITests
//
//  Created by Janez Troha on 12/08/2021.
//

import Defaults
@testable import Pareto_Security
import XCTest

class ParetoSecurityUITests: XCTestCase {
    let app = XCUIApplication()
    var menu: XCUIElement?

    override func setUp() {
        super.setUp()
        app.launchArguments = ["isRunningTests"]
        app.launch()
    }

    override func tearDown() {
        super.tearDown()
        app.terminate()
    }

    private func waitUntilMenu() {
        app.activate()
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

        menuBarsQuery/*@START_MENU_TOKEN@*/ .menuItems["Access Security"]/*[[".statusItems",".menus.menuItems[\"Access Security\"]",".menuItems[\"Access Security\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/ .click()
        takeScreenshot(screenshot: app.statusItems.firstMatch.menus.firstMatch.screenshot(), name: "Access Security")
        takeScreenshot(screenshot: app.screenshot(), name: "Access Security App")

        menuBarsQuery/*@START_MENU_TOKEN@*/ .menuItems["Firewall & Sharing"]/*[[".statusItems",".menus.menuItems[\"Firewall & Sharing\"]",".menuItems[\"Firewall & Sharing\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/ .click()
        takeScreenshot(screenshot: app.statusItems.firstMatch.menus.firstMatch.screenshot(), name: "Firewall & Sharing")
        takeScreenshot(screenshot: app.screenshot(), name: "Firewall & Sharing App")

        menuBarsQuery/*@START_MENU_TOKEN@*/ .menuItems["System integrity"]/*[[".statusItems",".menus.menuItems[\"System integrity\"]",".menuItems[\"System integrity\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/ .click()
        takeScreenshot(screenshot: app.statusItems.firstMatch.menus.firstMatch.screenshot(), name: "System Integritiy")
        takeScreenshot(screenshot: app.screenshot(), name: "System Integritiy App")

        menuBarsQuery/*@START_MENU_TOKEN@*/ .menuItems["Snooze"]/*[[".statusItems[\"ParetoSecurity\"]",".menus.menuItems[\"Snooze\"]",".menuItems[\"Snooze\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/ .click()
        takeScreenshot(screenshot: app.statusItems.firstMatch.menus.firstMatch.screenshot(), name: "Snooze")
        takeScreenshot(screenshot: app.screenshot(), name: "Snooze App")
    }

    func testSnooze() throws {
        // XCTExpectFailure("Fails with in xcode 13 env, working on a fix")

        let menuBarsQuery = app.menuBars
        waitUntilMenu()

        menuBarsQuery/*@START_MENU_TOKEN@*/ .menuItems["Snooze"]/*[[".statusItems[\"ParetoSecurity\"]",".menus.menuItems[\"Snooze\"]",".menuItems[\"Snooze\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/ .click()
        takeScreenshot(screenshot: app.statusItems.firstMatch.menus.firstMatch.screenshot(), name: "Snooze")
        takeScreenshot(screenshot: app.screenshot(), name: "Snooze App")
        menuBarsQuery/*@START_MENU_TOKEN@*/ .menuItems["snoozeOneDay"]/*[[".statusItems[\"ParetoSecurity\"]",".menuItems[\"Snooze\"]",".menus",".menuItems[\"for 1 day\"]",".menuItems[\"snoozeOneDay\"]"],[[[-1,4],[-1,3],[-1,2,3],[-1,1,2],[-1,0,1]],[[-1,4],[-1,3],[-1,2,3],[-1,1,2]],[[-1,4],[-1,3],[-1,2,3]],[[-1,4],[-1,3]]],[0]]@END_MENU_TOKEN@*/ .click()
    }

    func testSettingsWindow() throws {
        // XCTExpectFailure("Fails with in xcode 13 env, working on a fix")

        let menuBarsQuery = app.menuBars
        waitUntilMenu()

        menuBarsQuery/*@START_MENU_TOKEN@*/ .menuItems["showPrefs"]/*[[".statusItems[\"ParetoSecurity\"]",".menus",".menuItems[\"Preferences\"]",".menuItems[\"showPrefs\"]"],[[[-1,3],[-1,2],[-1,1,2],[-1,0,1]],[[-1,3],[-1,2],[-1,1,2]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/ .click()
        app.windows.firstMatch.toolbars.buttons["General"].click()
        takeScreenshot(screenshot: app.windows.firstMatch.screenshot(), name: "Settings General")
        app.windows.firstMatch.toolbars.buttons["Teams"].click()
        takeScreenshot(screenshot: app.windows.firstMatch.screenshot(), name: "Settings Teams")
        app.windows.firstMatch.toolbars.buttons["Checks"].click()
        takeScreenshot(screenshot: app.windows.firstMatch.screenshot(), name: "Settings Checks")
        app.windows.firstMatch.toolbars.buttons["About"].click()
        takeScreenshot(screenshot: app.windows.firstMatch.screenshot(), name: "Settings About")
        app.windows.firstMatch.buttons[XCUIIdentifierCloseWindow].click()
    }

    func testAppRuns() throws {
        takeScreenshot(screenshot: app.screenshot(), name: "App")
    }
}
