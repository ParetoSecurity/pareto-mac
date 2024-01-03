//
//  ParetoCustomCheckTest.swift
//  ParetoAppTest
//
//  Created by Janez Troha on 20/09/2021.
//

@testable import Pareto_Security
import XCTest
import Yams

class ParetoCustomChecksTest: XCTestCase {
    override class func setUp() {
        super.setUp()
    }

    override class func tearDown() {
        super.tearDown()
    }

    func testGetChecks() throws {
        let checks = CustomCheck.getRules()
        for check in checks {
            assert(check.passes())
        }
    }

    func testWriteCheck() throws {
        let check = CustomCheck(id: "id", title: "title", check: "true", result: CustomCheckResult(integer: 1))
        let encoder = YAMLEncoder()
        let encodedYAML = try encoder.encode(check)
        let myYAML = "id: id\ntitle: title\ncheck: \'true\'\nresult:\n  integer: 1\n"
        assert(encodedYAML == myYAML)
    }
}
