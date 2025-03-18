//
//  ParetoAppTest.swift
//  ParetoAppTest
//
//  Created by Janez Troha on 20/09/2021.
//

@testable import Pareto_Security
import XCTest

class ParetoAppTest: XCTestCase {

    func testActionEnrollTeam() throws {
        let app = AppHandlers()
        app.processAction(URL(string: "paretosecurity://enrollTeam")!)
    }

    func testActionApp() throws {
        let app = AppHandlers()
        app.runApp()
    }
}
