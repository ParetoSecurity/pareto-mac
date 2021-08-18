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
            print("App did not settle after run")
        }
    }

    override func tearDown() {
        app.terminate()
        super.tearDown()
    }

    private func waitUntilMenu() {
        if !app.menuBars.statusItems["paretoButton"].waitForExistence(timeout: 3) {
            XCTFail("Menu did not build")
        }
        app.menuBars.statusItems["paretoButton"].click()
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

    // func testSettingsOpens() throws {
    //    waitUntilMenu()
    //    app.menuBars/*@START_MENU_TOKEN@*/ .menuItems["showPrefs"]/*[[".statusItems",".menus[\"paretoMenu\"]",".menuItems[\"Preferences\"]",".menuItems[\"showPrefs\"]"],[[[-1,3],[-1,2],[-1,1,2],[-1,0,1]],[[-1,3],[-1,2],[-1,1,2]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/ .click()
    //    let settings = app.windows.firstMatch.screenshot()
    //    takeScreenshot(screenshot: settings, name: "Settings")
    // }

    // func testBrowserOpens() throws {
    //    waitUntilMenu()
    //    app.menuBars.menuItems["reportBug"].click()
    // }

    // func testAppExits() throws {
    //    waitUntilMenu()
    //    takeScreenshot(screenshot: app.statusItems.firstMatch.menus.firstMatch.screenshot(), name: "App")
    //    app.menuBars.menuItems["quitApp"].click()
    // }

    func testAppRuns() throws {
        takeScreenshot(screenshot: app.screenshot(), name: "App")
    }
}
