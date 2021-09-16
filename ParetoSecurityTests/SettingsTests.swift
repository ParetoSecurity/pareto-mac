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
        UserDefaults.standard.removeAll()
        UserDefaults.standard.synchronize()
    }

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

    func testTeam() throws {
        let subject = TeamSettingsView()
        let one = try subject.inspect().vStack()[0].text().string()
        XCTAssertEqual(one, "The Teams subscription will give you a web dashboard for an overview of the company’s devices.")
    }

    func testChecks() throws {
        let subject = ChecksSettingsView()
        let one = try subject.inspect().vStack()[0].text().string()
        XCTAssertEqual(one, "Deselect the checks you don't want the app to run.")
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
