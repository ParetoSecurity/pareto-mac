//
//  WelcomeTest.swift
//  WelcomeTest
//
//  Created by Janez Troha on 20/09/2021.
//

@testable import Pareto_Security
import ViewInspector
import XCTest

class WelcomeTest: XCTestCase {
    override class func setUp() {
        super.setUp()
        UserDefaults.standard.removeAll()
        UserDefaults.standard.synchronize()
    }

    func testWelcomeView() throws {
        let subject = WelcomeView()
        let one = try subject.inspect().vStack()[2].text(0).string()
        XCTAssertEqual(one, "Pareto Security is checking your computer's security for the first time.")
    }

    func testWelcomeViewShow() throws {
        _ = WelcomeView(showDetail: true)
    }
}

extension WelcomeView: Inspectable {}
