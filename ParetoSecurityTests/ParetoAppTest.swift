//
//  ParetoAppTest.swift
//  ParetoAppTest
//
//  Created by Janez Troha on 20/09/2021.
//

@testable import Pareto_Security
import XCTest

class ParetoAppTest: XCTestCase {
    override class func setUp() {
        super.setUp()
    }

    func testActionEnrollPersonal() throws {
        let app = AppHandlers()
        app.processAction(URL(string: "paretosecurity://enrollSingle")!)
    }

    func testActionEnrollTeam() throws {
        let app = AppHandlers()
        app.processAction(URL(string: "paretosecurity://enrollTeam")!)
    }

    func testActionApp() throws {
        let app = AppHandlers()
        app.runApp()
    }
}
