//
//  SettingsTests.swift
//  Settings
//
//  Created by Janez Troha on 17/08/2021.
//

import Defaults
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
        XCTAssertNoThrow(try subject.inspect().find(text: "Made with ❤️ in 🇪🇺"))
    }

    func testTeam() throws {
        Defaults[.teamID] = ""
        let subject = TeamSettingsView(teamSettings: AppInfo.TeamSettings)
        XCTAssertNoThrow(try subject.inspect().find(ViewType.Form.self))
    }
}
