//
//  Settings.swift
//  Settings
//
//  Created by Janez Troha on 17/08/2021.
//

@testable import Pareto_Security
import XCTest

class SettingsViewTests: XCTestCase {
    func testMain() throws {
        let subject = SettingsView()
        XCTAssert(subject.body != nil)
    }
}
