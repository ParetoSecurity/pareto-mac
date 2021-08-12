//
//  ParetoSecurityTests.swift
//  ParetoSecurityTests
//
//  Created by Janez Troha on 11/08/2021.
//

@testable import Pareto_Security
import XCTest

class ParetoSecurityTests: XCTestCase {
    func testThatUUIDsAreUnique() throws {
        var uuids: [String] = []
        for check in StatusBarController().checks {
            if uuids.contains(check.UUID) {
                XCTFail("Duplicate UUID found \(check.UUID)")
            }
            uuids.append(check.UUID)
        }
    }
}
