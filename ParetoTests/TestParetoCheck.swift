//
//  TestParetoCheck.swift
//  Pareto Security
//
//  Created by Janez Troha on 21/07/2021.
//

import XCTest
@testable import Pareto_Security

class TestParetoCheck: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testThatUUIDsAreUnique() throws {
        var uuids : [String] = []
        for check in StatusBarController().checks {
            if uuids.contains(check.UUID) {
                XCTFail("Duplicate UUID found \(check.UUID)")
            }
            uuids.append(check.UUID)
        }
    }

}
