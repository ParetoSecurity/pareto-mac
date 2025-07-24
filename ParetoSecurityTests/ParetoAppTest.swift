//
//  ParetoAppTest.swift
//  ParetoAppTest
//
//  Created by Janez Troha on 20/09/2021.
//

@testable import Pareto_Security
import XCTest

class ParetoAppTest: XCTestCase {
    func testActionLinkDevice() throws {
        let app = AppHandlers()
        app.processAction(URL(string: "paretosecurity://linkDevice?invite_id=12345678-1234-5678-9012-123456789012")!)
    }

    func testActionApp() throws {
        let app = AppHandlers()
        app.runApp()
    }
}
