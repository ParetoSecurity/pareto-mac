//
//  ParetoSecurityUITests.swift
//  ParetoSecurityUITests
//
//  Created by Janez Troha on 12/08/2021.
//

import XCTest

class ParetoSecurityUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        super.setUp()
        app.launch()
    }

    override func tearDown() {
        super.tearDown()
        app.terminate()
    }

    func testSettingsOpens() throws {
        app.children(matching: .menuBar).element(boundBy: 1).children(matching: .statusItem).element.click()
        app.menuBars/*@START_MENU_TOKEN@*/ .menuItems["showPrefs"]/*[[".statusItems",".menus",".menuItems[\"Preferences\"]",".menuItems[\"showPrefs\"]"],[[[-1,3],[-1,2],[-1,1,2],[-1,0,1]],[[-1,3],[-1,2],[-1,1,2]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/ .click()
    }

    func testBrowserOpens() throws {
        app.children(matching: .menuBar).element(boundBy: 1).children(matching: .statusItem).element.click()
        app.menuBars/*@START_MENU_TOKEN@*/ .menuItems["reportBug"]/*[[".statusItems",".menus",".menuItems[\"Report Bug\"]",".menuItems[\"reportBug\"]"],[[[-1,3],[-1,2],[-1,1,2],[-1,0,1]],[[-1,3],[-1,2],[-1,1,2]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/ .click()
    }

    func testAppExits() throws {
        XCUIApplication().children(matching: .menuBar).element(boundBy: 1).children(matching: .statusItem).element.click()
        app.menuBars.menuItems["quitApp"].click()
    }
}
