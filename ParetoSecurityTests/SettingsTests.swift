//
//  SettingsTests.swift
//  Settings
//
//  Created by Janez Troha on 17/08/2021.
//

@testable import Pareto_Security
import ViewInspector
import XCTest

class SettingsViewTests: XCTestCase {
    func testSettingsView() throws {
        let subject = SettingsView(selected: SettingsView.Tabs.general)
        let sub = try subject.inspect().implicitAnyView()
        XCTAssertEqual(try sub.tabView().count, 5)
    }

    func testAbout() throws {
        let subject = AboutSettingsView()
        let text = try subject.inspect().implicitAnyView().hStack()[1].vStack()[5].text().string()

        XCTAssertEqual(text, "Made with ❤️ at [Niteo](https://paretosecurity.com/about)")
    }

    func testTeam() throws {
        let subject = TeamSettingsView(teamSettings: AppInfo.TeamSettings)
        let one = try subject.inspect().implicitAnyView().form()[0].text().string()
        XCTAssertEqual(one, "The Teams subscription will give you a web dashboard for an overview of the company’s devices.")
    }
}
