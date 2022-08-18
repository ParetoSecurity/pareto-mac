//
//  Settings.swift
//  Settings
//
//  Created by Janez Troha on 17/08/2021.
//

@testable import Pareto_Security
import ViewInspector
import XCTest

class SettingsViewTests: XCTestCase {
    override class func setUp() {
        super.setUp()
    }

    override class func tearDown() {
        super.tearDown()
    }

    func testSettingsView() throws {
        let subject = SettingsView(selected: SettingsView.Tabs.general)
        let sub = try subject.inspect().tabView().count
        XCTAssertEqual(sub, 5)
    }

    func testAbout() throws {
        let subject = AboutSettingsView()
        let text = try subject.inspect().hStack()[1].vStack()[5].text().string()

        XCTAssertEqual(text, "Made with ❤️ at [Niteo](https://paretosecurity.com/about)")
    }

    func testGeneral() throws {
        let subject = GeneralSettingsView()
        let one = try subject.inspect().form()[0].section().footer().text().string()
        XCTAssertEqual(one, "To enable continuous monitoring and reporting.")
    }

    func testTeam() throws {
        let subject = TeamSettingsView(teamSettings: AppInfo.TeamSettings)
        let one = try subject.inspect().form()[0].text().string()
        XCTAssertEqual(one, "The Teams subscription will give you a web dashboard for an overview of the company’s devices.")
    }

    func testLicense() throws {
        let subject = LicenseSettingsView()
        let one = try subject.inspect().vStack()[0].text().string()
        XCTAssertEqual(one, "You are running the free version of the app. Please consider purchasing the Personal lifetime license for unlimited devices!")
    }
}

extension AboutSettingsView: Inspectable {}
extension GeneralSettingsView: Inspectable {}
extension TeamSettingsView: Inspectable {}
extension ChecksSettingsView: Inspectable {}
extension LicenseSettingsView: Inspectable {}
extension SettingsView: Inspectable {}
