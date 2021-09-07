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
    func testAbout() throws {
        let subject = AboutSettingsView()
        let text = try subject.inspect().hStack()[1].vStack()[3]
            .text().string()
        XCTAssertEqual(text, "Made with ❤️ at Niteo")
    }

    func testGeneral() throws {
        let subject = GeneralSettingsView()
        let one = try subject.inspect().form()[0].section().footer().text().string()
        XCTAssertEqual(one, "Automatically opens the app when you start your Mac.")
    }
}

extension AboutSettingsView: Inspectable {}
extension GeneralSettingsView: Inspectable {}
