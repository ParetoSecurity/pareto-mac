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
        let sub = try subject.inspect().tabView()
        XCTAssertEqual(try sub.count, 5)
    }

    func testAbout() throws {
        _ = AboutSettingsView()
    }

    func testTeam() throws {
        _ = TeamSettingsView(teamSettings: AppInfo.TeamSettings)
    }
}
